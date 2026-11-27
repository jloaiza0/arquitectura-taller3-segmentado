// =============================================================================
// forwarding_unit.sv - Unidad de adelantamiento (vive en EX)
//
// Combinacional pura: no recibe reloj y no guarda nada. No ve datos, solo
// numeros de registro y dos bits de RegWrite.
//
//   Forward = 2'b00  ->  el valor del banco (RD1E / RD2E)
//   Forward = 2'b10  ->  ALUResultM, de EX/MEM   (distancia 1)
//   Forward = 2'b01  ->  ResultW,    de MEM/WB   (distancia 2)
//
// Las tres condiciones de la seccion 7, en cada rama:
//   1. rs != x0           (un nop o una escritura a x0 no se adelanta)
//   2. RegWrite == 1      (un sw o un branch no escriben: sus bits 11:7 son
//                          del inmediato, no un rd)
//   3. el ORDEN es la prioridad: EX/MEM se mira primero porque es el valor
//      mas reciente (doble hazard).
//
// La misma logica, dos veces: una con rs1E (operando A) y otra con rs2E
// (operando B). Se escribe con always_comb y las seis entradas a la vista:
// una primera version usaba una funcion que leia rdM y RegWriteM sin
// recibirlos como argumentos, y el assign solo se reevaluaba al cambiar rs
// (ver el informe: es el error que encontro acumulador.s).
// =============================================================================
module forwarding_unit (
    input  logic [4:0] rs1E,
    input  logic [4:0] rs2E,
    input  logic [4:0] rdM,
    input  logic [4:0] rdW,
    input  logic       RegWriteM,
    input  logic       RegWriteW,
    output logic [1:0] ForwardAE,
    output logic [1:0] ForwardBE
);

    always_comb begin
        // ---- Operando A ----
        if      ((rs1E != 5'd0) && RegWriteM && (rs1E == rdM)) ForwardAE = 2'b10;
        else if ((rs1E != 5'd0) && RegWriteW && (rs1E == rdW)) ForwardAE = 2'b01;
        else                                                   ForwardAE = 2'b00;

        // ---- Operando B: la misma tabla con rs2E ----
        if      ((rs2E != 5'd0) && RegWriteM && (rs2E == rdM)) ForwardBE = 2'b10;
        else if ((rs2E != 5'd0) && RegWriteW && (rs2E == rdW)) ForwardBE = 2'b01;
        else                                                   ForwardBE = 2'b00;
    end

endmodule
