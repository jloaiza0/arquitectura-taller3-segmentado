// =============================================================================
// tb_unidades.sv - Pruebas dirigidas de las tres piezas nuevas, por separado
//
//   pipe_reg          carga, habilitacion, borrado y prioridad del borrado
//   forwarding_unit   las 8 filas de la tabla de la seccion 6, por A y por B
//   hazard_unit       las 8 filas de la tabla de la seccion 12
//
// La fila ResultSrcE = 11 de la unidad de riesgos es la que ningun programa
// puede delatar (una parada de mas no cambia el resultado): solo se ve aqui.
// =============================================================================
`timescale 1ns/1ps

module tb_unidades;

    int pruebas;
    int errores;

    task automatic chequear(input string nombre, input logic [31:0] obtenido,
                            input logic [31:0] esperado);
        pruebas = pruebas + 1;
        if (obtenido !== esperado) begin
            errores = errores + 1;
            $display("  FALLO %-46s obtenido=%0h esperado=%0h", nombre, obtenido, esperado);
        end
    endtask

    // -------------------------------------------------------------------------
    // pipe_reg
    // -------------------------------------------------------------------------
    logic        clk, rst, en, clr;
    logic [7:0]  d, q;

    pipe_reg #(.W(8)) dut_reg (.clk(clk), .rst(rst), .en(en), .clr(clr), .d(d), .q(q));

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // forwarding_unit
    // -------------------------------------------------------------------------
    logic [4:0] rs1E, rs2E, rdM, rdW;
    logic       RegWriteM, RegWriteW;
    logic [1:0] ForwardAE, ForwardBE;

    forwarding_unit dut_fu (
        .rs1E(rs1E), .rs2E(rs2E), .rdM(rdM), .rdW(rdW),
        .RegWriteM(RegWriteM), .RegWriteW(RegWriteW),
        .ForwardAE(ForwardAE), .ForwardBE(ForwardBE)
    );

    // Una fila de la tabla, aplicada primero al operando A y luego al B. En
    // cada caso el OTRO operando se pone en un registro que nadie escribe (x20)
    // para comprobar tambien que las dos salidas son independientes.
    task automatic fila_fw(input string nombre, input logic [4:0] rs,
                           input logic [4:0] rd_m, input logic rw_m,
                           input logic [4:0] rd_w, input logic rw_w,
                           input logic [1:0] esperado);
        // rs se fija ANTES que el resto: asi la prueba tambien delata una
        // unidad que solo reacciona a cambios de rs (el error de la funcion).
        rs1E = rs;     rs2E = 5'd20;  #1;
        rdM = rd_m; RegWriteM = rw_m; rdW = rd_w; RegWriteW = rw_w; #1;
        chequear({"fwd A: ", nombre}, ForwardAE, esperado);
        chequear({"fwd A (B quieto): ", nombre}, ForwardBE, 2'b00);
        rdM = 5'd20 ^ rd_m; rdW = 5'd20 ^ rd_w; #1;   // perturbar
        rs1E = 5'd20;  rs2E = rs;     #1;
        rdM = rd_m; RegWriteM = rw_m; rdW = rd_w; RegWriteW = rw_w; #1;
        chequear({"fwd B: ", nombre}, ForwardBE, esperado);
        chequear({"fwd B (A quieto): ", nombre}, ForwardAE, 2'b00);
    endtask

    // -------------------------------------------------------------------------
    // hazard_unit
    // -------------------------------------------------------------------------
    logic [4:0] rs1D, rs2D, rdE;
    logic [1:0] ResultSrcE;
    logic       PCSrcE;
    logic       StallF, StallD, FlushD, FlushE;

    hazard_unit dut_hu (
        .rs1D(rs1D), .rs2D(rs2D), .rdE(rdE), .ResultSrcE(ResultSrcE), .PCSrcE(PCSrcE),
        .StallF(StallF), .StallD(StallD), .FlushD(FlushD), .FlushE(FlushE)
    );

    task automatic fila_hu(input string nombre,
                           input logic [4:0] r1, input logic [4:0] r2,
                           input logic [4:0] rde, input logic [1:0] rsrc,
                           input logic pcs,
                           input logic stall, input logic fd, input logic fe);
        rs1D = r1; rs2D = r2; rdE = rde; ResultSrcE = rsrc; PCSrcE = pcs; #1;
        chequear({"riesgos StallF: ", nombre}, StallF, stall);
        chequear({"riesgos StallD: ", nombre}, StallD, stall);
        chequear({"riesgos FlushD: ", nombre}, FlushD, fd);
        chequear({"riesgos FlushE: ", nombre}, FlushE, fe);
    endtask

    initial begin
        $dumpfile("build/tb_unidades.vcd");
        $dumpvars(0, tb_unidades);
        pruebas = 0;
        errores = 0;

        // ---------------- pipe_reg ----------------
        rst = 1'b1; en = 1'b1; clr = 1'b0; d = 8'hAA;
        @(posedge clk); #1;
        chequear("pipe_reg: rst pone a cero", q, 8'h00);
        rst = 1'b0;
        @(posedge clk); #1;
        chequear("pipe_reg: carga con en = 1", q, 8'hAA);
        en = 1'b0; d = 8'h55;
        @(posedge clk); #1;
        chequear("pipe_reg: en = 0 conserva (parada)", q, 8'hAA);
        en = 1'b1; clr = 1'b1;
        @(posedge clk); #1;
        chequear("pipe_reg: clr pone a cero (burbuja)", q, 8'h00);
        clr = 1'b0;
        @(posedge clk); #1;
        chequear("pipe_reg: vuelve a cargar", q, 8'h55);
        en = 1'b0; clr = 1'b1;
        @(posedge clk); #1;
        chequear("pipe_reg: clr gana a en = 0", q, 8'h00);
        clr = 1'b0; en = 1'b1;

        // ---------------- forwarding: tabla de la seccion 6 ----------------
        //        nombre                          rsE  rdM RWM  rdW RWW  salida
        fila_fw("nadie escribe ese registro",     5,   7,  1,   8,  1,   2'b00);
        fila_fw("la de delante escribe x5",       5,   5,  1,   8,  1,   2'b10);
        fila_fw("la de dos por delante",          5,   7,  1,   5,  1,   2'b01);
        fila_fw("las dos: gana la mas cercana",   5,   5,  1,   5,  1,   2'b10);
        fila_fw("coincide pero no escribe (sw)",  5,   5,  0,   8,  1,   2'b00);
        fila_fw("coincide pero no escribe (br)",  5,   7,  1,   5,  0,   2'b00);
        fila_fw("operando x0: nunca",             0,   0,  1,   0,  1,   2'b00);
        fila_fw("x31: los cinco bits",           31,  31,  1,   8,  1,   2'b10);
        // Dos extra: la cercana no escribe y la lejana si (debe caer a 01),
        // y x0 solo en MEM/WB.
        fila_fw("cercana no escribe, lejana si",  5,   5,  0,   5,  1,   2'b01);
        fila_fw("x0 en MEM/WB: nunca",            0,   7,  1,   0,  1,   2'b00);

        // ---------------- riesgos: tabla de la seccion 12 ----------------
        //        nombre                    rs1 rs2 rdE rsrc  pcs  stall fD fE
        fila_hu("nada que detectar",        5,  6,  7,  2'b00, 0,  0,    0, 0);
        fila_hu("depende de un add",        5,  6,  5,  2'b00, 0,  0,    0, 0);
        fila_hu("load-use por rs1",         5,  6,  5,  2'b01, 0,  1,    0, 1);
        fila_hu("load-use por rs2",         5,  6,  6,  2'b01, 0,  1,    0, 1);
        fila_hu("lw a otro registro",       5,  6,  7,  2'b01, 0,  0,    0, 0);
        fila_hu("jal: su PC+4 ya existe",   5,  6,  5,  2'b10, 0,  0,    0, 0);
        fila_hu("lui: no parar (bit 0)",    5,  6,  5,  2'b11, 0,  0,    0, 0);
        fila_hu("salto tomado",             5,  6,  7,  2'b00, 1,  0,    1, 1);

        $display("--------------------------------------------------");
        $display("pruebas: %0d    errores: %0d", pruebas, errores);
        if (errores == 0) $display("tb_unidades: PASS");
        else              $display("tb_unidades: FAIL");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule
