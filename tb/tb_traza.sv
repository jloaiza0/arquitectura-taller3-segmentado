// =============================================================================
// tb_traza.sv - Imprime en que etapa esta cada instruccion, ciclo a ciclo
//
// Lleva una "ficha" por instruccion que sigue al pipeline: avanza cuando la
// etapa avanza, se queda cuando hay parada y desaparece (-1) cuando hay
// borrado. Solo observa: no toca el procesador.
//   uso:  vvp build/tb_traza.out +PROG=prog/lw_use.hex +N=14
// =============================================================================
`timescale 1ns/1ps
module tb_traza;
    logic clk = 1'b0, rst = 1'b1;
    always #5 clk = ~clk;
    string prog;
    int n;
    initial begin
        if (!$value$plusargs("PROG=%s", prog)) prog = "prog/humo.hex";
        if (!$value$plusargs("N=%d", n)) n = 12;
    end
    riscv_segmentado #(.INIT_FILE("prog/traza.hex")) seg (.clk(clk), .rst(rst), .en(1'b1));

    int tokF, tokD, tokE, tokM, tokW, sig, c;
    int pcTok [0:1023];
    initial begin tokD = -1; tokE = -1; tokM = -1; tokW = -1; sig = 0; c = 0; tokF = 0; end

    always @(negedge clk) if (!rst) begin
        c = c + 1;
        pcTok[tokF] = seg.PCF;
        $display("T %0d %0d %0d %0d %0d %0d %0h", c, tokF, tokD, tokE, tokM, tokW, seg.PCF);
        for (int t = 0; t <= tokF; t++) $display("P %0d %0h", t, pcTok[t]);
    end
    always @(posedge clk) if (!rst) begin
        tokW <= tokM;
        tokM <= tokE;
        tokE <= seg.FlushE ? -1 : tokD;
        tokD <= seg.FlushD ? -1 : (seg.StallD ? tokD : tokF);
        if (!seg.StallF) tokF <= tokF + 1;
    end
    initial begin
        repeat (2) @(posedge clk); rst = 1'b0;
        repeat (n) @(posedge clk);
        $finish;
    end
endmodule
