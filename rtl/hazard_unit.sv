// =============================================================================
// hazard_unit.sv - Unidad de deteccion de riesgos (vive en ID)
//
// Combinacional pura. Dos trabajos:
//
//   1. load-use: la de EX es un load (ResultSrcE == 01, LOS DOS BITS) y la de
//      ID lee su rd por rs1 o por rs2. Se para el frente un ciclo:
//          StallF = StallD = FlushE = lwStall
//
//      ResultSrc = 11 (lui) tiene el bit 0 a uno: comparar solo ResultSrcE[0]
//      pararia de mas. Por eso se compara el campo entero contra RES_MEM.
//
//   2. salto tomado (PCSrcE = 1): se matan las dos instrucciones que entraron
//      detras:
//          FlushD = PCSrcE,  FlushE |= PCSrcE
//
// Las dos causas no coinciden nunca: una exige un load en EX y la otra un
// salto en EX.
// =============================================================================
module hazard_unit (
    input  logic [4:0] rs1D,
    input  logic [4:0] rs2D,
    input  logic [4:0] rdE,
    input  logic [1:0] ResultSrcE,
    input  logic       PCSrcE,
    output logic       StallF,
    output logic       StallD,
    output logic       FlushD,
    output logic       FlushE
);

    import riscv_pkg::*;

    logic lwStall;

    assign lwStall = (ResultSrcE == RES_MEM) && ((rs1D == rdE) || (rs2D == rdE));

    assign StallF = lwStall;
    assign StallD = lwStall;
    assign FlushD = PCSrcE;
    assign FlushE = lwStall | PCSrcE;

endmodule
