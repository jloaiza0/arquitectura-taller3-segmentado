// =============================================================================
// pipe_reg.sv - Registro de segmentacion de ancho parametrizable
//
// Tres puertos de control, y los tres hacen falta:
//   - en  : habilitacion. Con en = 0 el registro conserva su valor (parada).
//   - clr : borrado SINCRONO. Pone el registro a cero en el flanco (burbuja).
//   - rst : reset sincrono, igual que el del PC.
//
// Prioridad: rst y clr ganan sobre en. Una burbuja se mete aunque la etapa
// este parada; en este procesador las dos cosas nunca piden lo contrario a la
// vez sobre el mismo registro (StallD y FlushD son excluyentes).
//
// Todo a cero es una instruccion muerta: RegWrite = MemWrite = Branch =
// Jump = 0, rd = x0. Por eso el borrado ES el nop que nadie escribio.
// =============================================================================
module pipe_reg #(
    parameter int W = 32
)(
    input  logic         clk,
    input  logic         rst,
    input  logic         en,
    input  logic         clr,
    input  logic [W-1:0] d,
    output logic [W-1:0] q
);

    always_ff @(posedge clk) begin
        if (rst || clr) q <= '0;
        else if (en)    q <= d;
    end

endmodule
