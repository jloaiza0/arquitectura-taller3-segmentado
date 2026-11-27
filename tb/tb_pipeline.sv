// =============================================================================
// tb_pipeline.sv - Regresion del procesador segmentado
//
// Cada programa corre a la vez en DOS procesadores con el mismo reloj:
//   - riscv_monociclo  (Taller 2, ya validado): es el modelo de referencia,
//                       la "ejecucion instruccion a instruccion"
//   - riscv_segmentado (Taller 3)
//
// Al final se comprueba, para cada programa:
//   1. los valores esperados que dice la cabecera del .s
//   2. que los 32 registros y las 64 primeras palabras de la memoria de datos
//      del segmentado son IDENTICOS a los del monociclo
//
// Ademas se cuentan los ciclos de cada uno, las paradas (lwStall) y los
// saltos tomados (PCSrcE) del segmentado.
//
// Como se cuentan los ciclos: todos los programas terminan en
//     fin: beq x0, x0, fin      (codificado 0x00000063)
// - Monociclo: ciclos = ciclos transcurridos hasta que el PC llega a "fin"
//   (= instrucciones ejecutadas, CPI = 1).
// - Segmentado: si "fin" entra en IF en el ciclo c (contando desde 1), la
//   instruccion anterior termina WB al final del ciclo c + 3.
// Se comprueba tambien la formula  Tseg = N + 4 + paradas + 2 x saltos.
// =============================================================================
`timescale 1ns/1ps

module pareja #(
    parameter PROG = ""
)(
    input logic clk,
    input logic rst
);
    localparam logic [31:0] FIN = 32'h0000_0063;

    riscv_monociclo  #(.INIT_FILE(PROG)) mono (.clk(clk), .rst(rst), .en(1'b1));
    riscv_segmentado #(.INIT_FILE(PROG)) seg  (.clk(clk), .rst(rst), .en(1'b1));

    int ciclo;
    int t_mono, t_seg_if;
    int paradas, saltos;

    initial begin
        ciclo = 0; t_mono = -1; t_seg_if = -1; paradas = 0; saltos = 0;
    end

    // Se muestrea justo antes del flanco: lo que el procesador tiene en este ciclo
    always @(negedge clk) begin
        if (!rst) begin
            ciclo = ciclo + 1;
            if (t_mono   < 0 && mono.instr  === FIN) t_mono   = ciclo - 1;
            if (t_seg_if < 0 && seg.InstrF  === FIN) t_seg_if = ciclo;
            if (t_seg_if < 0) begin
                if (seg.hu.lwStall) paradas = paradas + 1;
                if (seg.PCSrcE)     saltos  = saltos  + 1;
            end
        end
    end
endmodule


module tb_pipeline;

    localparam int CICLOS = 300;
    localparam int NPROG  = 11;

    logic clk, rst;
    int pruebas, errores;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    pareja #(.PROG("prog/humo.hex"))       p_humo       (.clk(clk), .rst(rst));
    pareja #(.PROG("prog/completo.hex"))   p_completo   (.clk(clk), .rst(rst));
    pareja #(.PROG("prog/bytes.hex"))      p_bytes      (.clk(clk), .rst(rst));
    pareja #(.PROG("prog/fwd_dist.hex"))   p_fwd        (.clk(clk), .rst(rst));
    pareja #(.PROG("prog/doble.hex"))      p_doble      (.clk(clk), .rst(rst));
    pareja #(.PROG("prog/x0.hex"))         p_x0         (.clk(clk), .rst(rst));
    pareja #(.PROG("prog/sw_rd.hex"))      p_swrd       (.clk(clk), .rst(rst));
    pareja #(.PROG("prog/lui_jal.hex"))    p_lui        (.clk(clk), .rst(rst));
    pareja #(.PROG("prog/lw_use.hex"))     p_lw         (.clk(clk), .rst(rst));
    pareja #(.PROG("prog/salto.hex"))      p_salto      (.clk(clk), .rst(rst));
    pareja #(.PROG("prog/acumulador.hex")) p_acum       (.clk(clk), .rst(rst));

    task automatic comprobar(input string prog, input string nota,
                             input logic [31:0] obtenido, input logic [31:0] esperado);
        pruebas = pruebas + 1;
        if (obtenido !== esperado) begin
            errores = errores + 1;
            $display("  FALLO [%-10s] %-40s obtenido=0x%08h  esperado=0x%08h",
                     prog, nota, obtenido, esperado);
        end
    endtask

    // Compara el estado arquitectonico completo de las dos maquinas.
    // Se hace con una macro porque cada pareja es una instancia distinta.
    `define IGUALES(P, NOMBRE) \
        begin \
            int dif; dif = 0; \
            for (int i = 0; i < 32; i++) \
                if (P.seg.rf.regs[i] !== P.mono.rf.regs[i]) begin \
                    dif++; \
                    $display("  DIFIERE [%-10s] x%0d seg=0x%08h mono=0x%08h", NOMBRE, i, \
                             P.seg.rf.regs[i], P.mono.rf.regs[i]); \
                end \
            for (int i = 0; i < 64; i++) \
                if (P.seg.dmem.mem[i] !== P.mono.dmem.mem[i]) begin \
                    dif++; \
                    $display("  DIFIERE [%-10s] Mem[%0d] seg=0x%08h mono=0x%08h", NOMBRE, i, \
                             P.seg.dmem.mem[i], P.mono.dmem.mem[i]); \
                end \
            comprobar(NOMBRE, "estado identico al monociclo", dif, 0); \
        end

    `define CICLOS(P, NOMBRE) \
        begin \
            int tseg, n; \
            n    = P.t_mono; \
            tseg = P.t_seg_if + 3; \
            $display("  %-11s %4d %7d %8d %7d %9.2f %11s", NOMBRE, n, tseg, P.paradas, P.saltos, \
                     real'(tseg) / real'(n), \
                     (tseg == n + 4 + P.paradas + 2*P.saltos) ? "cuadra" : "NO CUADRA"); \
            comprobar(NOMBRE, "Tseg = N + 4 + paradas + 2 x saltos", tseg, n + 4 + P.paradas + 2*P.saltos); \
        end

    initial begin
        $dumpfile("build/tb_pipeline.vcd");
        $dumpvars(0, tb_pipeline);
        pruebas = 0; errores = 0;

        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst = 1'b0;
        repeat (CICLOS) @(posedge clk);
        #1;

        // ------------------------ programas del Taller 2 ------------------------
        comprobar("humo", "x3",                      p_humo.seg.rf.regs[3],  32'd15);
        comprobar("humo", "Mem[0]",                  p_humo.seg.dmem.mem[0], 32'd15);
        comprobar("completo", "ra tras jal",         p_completo.seg.rf.regs[1],  32'h4C);
        comprobar("completo", "x4 sub",              p_completo.seg.rf.regs[4],  32'd5);
        comprobar("completo", "x9 lw",               p_completo.seg.rf.regs[9],  32'd15);
        comprobar("completo", "x10 branch no tomado",p_completo.seg.rf.regs[10], 32'd1);
        comprobar("completo", "x11 branch tomado",   p_completo.seg.rf.regs[11], 32'd2);
        comprobar("completo", "x13 lui",             p_completo.seg.rf.regs[13], 32'h12345000);
        comprobar("completo", "x14 jal + jalr",      p_completo.seg.rf.regs[14], 32'd40);
        comprobar("completo", "x15 sltu",            p_completo.seg.rf.regs[15], 32'd1);
        comprobar("bytes", "x2 0xDEADBEEF",          p_bytes.seg.rf.regs[2],  32'hDEADBEEF);
        comprobar("bytes", "x8 sb sin pisar",        p_bytes.seg.rf.regs[8],  32'hDEAD55EF);
        comprobar("bytes", "x10 sh sin pisar",       p_bytes.seg.rf.regs[10], 32'h012355EF);
        comprobar("bytes", "x11 lhu alta",           p_bytes.seg.rf.regs[11], 32'h123);

        // ------------------------ fwd_dist: distancia 1 y 2, A y B ------------------------
        comprobar("fwd_dist", "x3 = x1 - x2 (A d2, B d1)", p_fwd.seg.rf.regs[3], 32'd4);
        comprobar("fwd_dist", "x4 = x2 - x3 (A d2, B d1)", p_fwd.seg.rf.regs[4], 32'hFFFFFFFF);
        comprobar("fwd_dist", "x5 = x3 - 0  (A d2)",       p_fwd.seg.rf.regs[5], 32'd4);
        comprobar("fwd_dist", "x6 = 0 - x4  (B d2)",       p_fwd.seg.rf.regs[6], 32'd1);
        comprobar("fwd_dist", "x7 = 0 - x6  (B d1)",       p_fwd.seg.rf.regs[7], 32'hFFFFFFFF);
        comprobar("fwd_dist", "x8 = x7 + 0  (A d1)",       p_fwd.seg.rf.regs[8], 32'hFFFFFFFF);

        // ------------------------ doble hazard ------------------------
        comprobar("doble", "x6: gana EX/MEM por A",  p_doble.seg.rf.regs[6], 32'd71);
        comprobar("doble", "x8: gana EX/MEM por B",  p_doble.seg.rf.regs[8], 32'd71);

        // ------------------------ x0 ------------------------
        comprobar("x0", "x0 sigue en cero",          p_x0.seg.rf.regs[0], 32'd0);
        comprobar("x0", "x2 = x0 + x1 (d1)",         p_x0.seg.rf.regs[2], 32'd5);
        comprobar("x0", "x3 = x0 + 1  (d1)",         p_x0.seg.rf.regs[3], 32'd1);
        comprobar("x0", "x4 = x1 + x0 (B d2)",       p_x0.seg.rf.regs[4], 32'd5);

        // ------------------------ sw / branch con "rd" falso ------------------------
        comprobar("sw_rd", "x11 = x8 tras sw 8(x0)",   p_swrd.seg.rf.regs[11], 32'd100);
        comprobar("sw_rd", "x13 = x12 tras sw 12(x0)", p_swrd.seg.rf.regs[13], 32'd55);
        comprobar("sw_rd", "x14 = x8 tras bne",        p_swrd.seg.rf.regs[14], 32'd100);
        comprobar("sw_rd", "Mem[2]",                   p_swrd.seg.dmem.mem[2], 32'd4);

        // ------------------------ lui / jal / auipc / jalr ------------------------
        comprobar("lui_jal", "x2 = lui + 0x678 (d1)",  p_lui.seg.rf.regs[2],  32'h12345678);
        comprobar("lui_jal", "x4 = lui por B (d1)",    p_lui.seg.rf.regs[4],  32'hABCDE000);
        comprobar("lui_jal", "x6 = PC+4 del jal (d1)", p_lui.seg.rf.regs[6],  32'h14);
        comprobar("lui_jal", "x8 = auipc + 4 (d1)",    p_lui.seg.rf.regs[8],  32'h1C);
        comprobar("lui_jal", "x10 = PC+4 del jalr",    p_lui.seg.rf.regs[10], 32'h28);
        comprobar("lui_jal", "x20: ranura del jalr",   p_lui.seg.rf.regs[20], 32'd0);

        // ------------------------ load-use ------------------------
        comprobar("lw_use", "x4 load-use por rs1",   p_lw.seg.rf.regs[4], 32'd21);
        comprobar("lw_use", "x6 load-use por rs2",   p_lw.seg.rf.regs[6], 32'd4);
        comprobar("lw_use", "x8 lw, indep., uso",    p_lw.seg.rf.regs[8], 32'd42);
        comprobar("lw_use", "Mem[6] lw -> sw",       p_lw.seg.dmem.mem[6], 32'd21);
        comprobar("lw_use", "exactamente 3 paradas", p_lw.paradas, 3);

        // ------------------------ saltos ------------------------
        comprobar("salto", "x30 ranura beq",         p_salto.seg.rf.regs[30], 32'd0);
        comprobar("salto", "Mem[0] ranura beq",      p_salto.seg.dmem.mem[0], 32'd0);
        comprobar("salto", "x31 ranura jal / mal",   p_salto.seg.rf.regs[31], 32'd0);
        comprobar("salto", "Mem[1] ranura jal",      p_salto.seg.dmem.mem[1], 32'd0);
        comprobar("salto", "x28 ranuras de 5 saltos",p_salto.seg.rf.regs[28], 32'd0);
        comprobar("salto", "x29 ranuras de 5 saltos",p_salto.seg.rf.regs[29], 32'd0);
        comprobar("salto", "x21 seis no tomados",    p_salto.seg.rf.regs[21], 32'd6);
        comprobar("salto", "x4 destino",             p_salto.seg.rf.regs[4],  32'd7);

        // ------------------------ acumulador ------------------------
        comprobar("acumulador", "x2 = 3 x 5",        p_acum.seg.rf.regs[2], 32'd15);
        comprobar("acumulador", "x5 = 3 vueltas",    p_acum.seg.rf.regs[5], 32'd3);
        comprobar("acumulador", "Mem[5] = 15",       p_acum.seg.dmem.mem[5], 32'd15);
        comprobar("acumulador", "3 paradas",         p_acum.paradas, 3);

        // ------------------------ equivalencia completa ------------------------
        `IGUALES(p_humo, "humo")
        `IGUALES(p_completo, "completo")
        `IGUALES(p_bytes, "bytes")
        `IGUALES(p_fwd, "fwd_dist")
        `IGUALES(p_doble, "doble")
        `IGUALES(p_x0, "x0")
        `IGUALES(p_swrd, "sw_rd")
        `IGUALES(p_lui, "lui_jal")
        `IGUALES(p_lw, "lw_use")
        `IGUALES(p_salto, "salto")
        `IGUALES(p_acum, "acumulador")

        // ------------------------ ciclos ------------------------
        $display("");
        $display("  PROGRAMA    MONO     SEG  PARADAS  SALTOS  SEG/MONO   FORMULA");
        `CICLOS(p_humo, "humo")
        `CICLOS(p_completo, "completo")
        `CICLOS(p_bytes, "bytes")
        `CICLOS(p_fwd, "fwd_dist")
        `CICLOS(p_doble, "doble")
        `CICLOS(p_x0, "x0")
        `CICLOS(p_swrd, "sw_rd")
        `CICLOS(p_lui, "lui_jal")
        `CICLOS(p_lw, "lw_use")
        `CICLOS(p_salto, "salto")
        `CICLOS(p_acum, "acumulador")

        $display("--------------------------------------------------");
        $display("pruebas: %0d    errores: %0d", pruebas, errores);
        if (errores == 0) $display("tb_pipeline: PASS");
        else              $display("tb_pipeline: FAIL");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule
