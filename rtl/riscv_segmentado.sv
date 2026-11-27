// =============================================================================
// riscv_segmentado.sv - El procesador RV32I de cinco etapas
//
// Son las mismas cajas del monociclo del Taller 2, sin un cambio, mas:
//   - cuatro registros de segmentacion (pipe_reg): IF/ID, ID/EX, EX/MEM, MEM/WB
//   - la unidad de forwarding (EX) y la unidad de deteccion de riesgos (ID)
//   - dos multiplexores de tres entradas delante de la ALU
//   - el mux de ResultSrc copiado a EX, para que EX/MEM lleve el valor
//     definitivo de rd (seccion 8 de la guia)
//
// Convencion de sufijos: F, D, E, M, W = etapa en la que esta la senal.
//
// Igual que en el monociclo, el banco de registros se llama "rf" y la memoria
// de datos "dmem": los testbenches llegan a ellos por referencia jerarquica.
// =============================================================================
module riscv_segmentado #(
    parameter int IMEM_DEPTH = 256,
    parameter int DMEM_DEPTH = 256,
    parameter     INIT_FILE  = ""
)(
    input logic clk,
    input logic rst,
    input logic en
);

    import riscv_pkg::*;

    // =========================================================================
    // Senales de las dos unidades nuevas
    // =========================================================================
    logic       StallF, StallD, FlushD, FlushE;
    logic [1:0] ForwardAE, ForwardBE;

    // =========================================================================
    // IF - busqueda
    // =========================================================================
    logic [31:0] PCF, PCPlus4F, PCNextF, InstrF;
    logic [31:0] PCTargetE;          // vuelve desde EX
    logic        PCSrcE;             // vuelve desde EX

    pc registro_pc (
        .clk     (clk),
        .rst     (rst),
        .en      (en & ~StallF),
        .pc_next (PCNextF),
        .pc      (PCF)
    );

    adder add_pc4 (
        .a (PCF),
        .b (32'd4),
        .y (PCPlus4F)
    );

    instruction_memory #(
        .DEPTH     (IMEM_DEPTH),
        .INIT_FILE (INIT_FILE)
    ) imem (
        .addr  (PCF),
        .instr (InstrF)
    );

    mux2 #(.W(32)) mux_pc (
        .d0  (PCPlus4F),
        .d1  (PCTargetE),
        .sel (PCSrcE),
        .y   (PCNextF)
    );

    // =========================================================================
    // IF/ID: la instruccion, el PC y PC+4                         (96 bits)
    // =========================================================================
    logic [31:0] InstrD, PCD, PCPlus4D;

    pipe_reg #(.W(96)) reg_if_id (
        .clk (clk),
        .rst (rst),
        .en  (en & ~StallD),
        .clr (FlushD),
        .d   ({InstrF, PCF, PCPlus4F}),
        .q   ({InstrD, PCD, PCPlus4D})
    );

    // =========================================================================
    // ID - decodificacion y lectura del banco
    // =========================================================================
    logic [6:0]  opcodeD;
    logic [2:0]  funct3D;
    logic        funct7b5D;
    logic [4:0]  rs1D, rs2D, rdD;

    assign opcodeD   = InstrD[6:0];
    assign rdD       = InstrD[11:7];
    assign funct3D   = InstrD[14:12];
    assign rs1D      = InstrD[19:15];
    assign rs2D      = InstrD[24:20];
    assign funct7b5D = InstrD[30];

    logic        RegWriteD, ALUSrcAD, ALUSrcBD, MemWriteD;
    logic        BranchD, JumpD, JalrD;
    logic [2:0]  ImmSrcD;
    logic [1:0]  ResultSrcD;
    logic [3:0]  ALUControlD;
    logic [31:0] RD1D, RD2D, ImmExtD;

    // Lo que se escribe en el banco, desde WB
    logic [31:0] ResultW;
    logic [4:0]  rdW;
    logic        RegWriteW;

    // La unidad de control es la del Taller 2, sin cambios. En ID solo se usan
    // sus senales "estaticas"; las banderas todavia no existen (se calculan en
    // EX), asi que entran a cero y su pc_src no se usa: el salto se decide en EX.
    control_unit control (
        .opcode      (opcodeD),
        .funct3      (funct3D),
        .funct7b5    (funct7b5D),
        .zero        (1'b0),
        .less        (1'b0),
        .less_u      (1'b0),
        .reg_write   (RegWriteD),
        .imm_src     (ImmSrcD),
        .alu_src_a   (ALUSrcAD),
        .alu_src_b   (ALUSrcBD),
        .mem_write   (MemWriteD),
        .result_src  (ResultSrcD),
        .branch      (BranchD),
        .jump        (JumpD),
        .jalr        (JalrD),
        .alu_control (ALUControlD),
        .pc_src      ()
    );

    // El banco escribe en el flanco de BAJADA (primer medio ciclo) y se lee
    // combinacionalmente despues: una escritura en WB y una lectura en ID del
    // mismo ciclo ya entregan el valor nuevo. Asi se resuelve la distancia 3
    // sin tocar register_file.sv: solo se le conecta el reloj invertido.
    register_file rf (
        .clk (~clk),
        .we  (RegWriteW),
        .rs1 (rs1D),
        .rs2 (rs2D),
        .rd  (rdW),
        .wd3 (ResultW),
        .rd1 (RD1D),
        .rd2 (RD2D)
    );

    imm_gen ig (
        .instr   (InstrD),
        .imm_src (ImmSrcD),
        .imm_ext (ImmExtD)
    );

    // Unidad de deteccion de riesgos: mira IF/ID (rs1D, rs2D) e ID/EX (rdE,
    // ResultSrcE). Vive en ID porque hay que detener la instruccion ANTES de
    // que llegue a EX.
    logic [4:0] rdE;
    logic [1:0] ResultSrcE;

    hazard_unit hu (
        .rs1D       (rs1D),
        .rs2D       (rs2D),
        .rdE        (rdE),
        .ResultSrcE (ResultSrcE),
        .PCSrcE     (PCSrcE),
        .StallF     (StallF),
        .StallD     (StallD),
        .FlushD     (FlushD),
        .FlushE     (FlushE)
    );

    // =========================================================================
    // ID/EX                                                       (191 bits)
    //   datos:   RD1, RD2, PC, PC+4, ImmExt                        5 x 32
    //   numeros: rs1, rs2, rd                                      3 x 5
    //   funct3                                                     3
    //   control: RegWrite, ResultSrc(2), MemWrite, Jump, Branch,
    //            Jalr, ALUControl(4), ALUSrcA, ALUSrcB             13
    // rs1 y rs2 viajan hasta EX: la unidad de forwarding compara NUMEROS.
    // funct3 viaja porque el salto se decide en EX y la memoria lo usa en MEM.
    // =========================================================================
    logic [31:0] RD1E, RD2E, PCE, PCPlus4E, ImmExtE;
    logic [4:0]  rs1E, rs2E;
    logic [2:0]  funct3E;
    logic        RegWriteE, MemWriteE, JumpE, BranchE, JalrE;
    logic        ALUSrcAE, ALUSrcBE;
    logic [3:0]  ALUControlE;

    pipe_reg #(.W(191)) reg_id_ex (
        .clk (clk),
        .rst (rst),
        .en  (en),
        .clr (FlushE),
        .d   ({RD1D, RD2D, PCD, PCPlus4D, ImmExtD,
               rs1D, rs2D, rdD, funct3D,
               RegWriteD, ResultSrcD, MemWriteD, JumpD, BranchD, JalrD,
               ALUControlD, ALUSrcAD, ALUSrcBD}),
        .q   ({RD1E, RD2E, PCE, PCPlus4E, ImmExtE,
               rs1E, rs2E, rdE, funct3E,
               RegWriteE, ResultSrcE, MemWriteE, JumpE, BranchE, JalrE,
               ALUControlE, ALUSrcAE, ALUSrcBE})
    );

    // =========================================================================
    // EX - ejecucion
    // =========================================================================
    logic [31:0] ALUResultM;         // vuelve desde EX/MEM (distancia 1)
    logic [4:0]  rdM;
    logic        RegWriteM;

    forwarding_unit fu (
        .rs1E      (rs1E),
        .rs2E      (rs2E),
        .rdM       (rdM),
        .rdW       (rdW),
        .RegWriteM (RegWriteM),
        .RegWriteW (RegWriteW),
        .ForwardAE (ForwardAE),
        .ForwardBE (ForwardBE)
    );

    // Los dos multiplexores de tres entradas (mux4 con la rama 11 sin uso)
    logic [31:0] FwdAE, WriteDataE;

    mux4 #(.W(32)) mux_fwd_a (
        .d00 (RD1E),
        .d01 (ResultW),
        .d10 (ALUResultM),
        .d11 (32'd0),
        .sel (ForwardAE),
        .y   (FwdAE)
    );

    // La salida del mux B es tambien el dato que un store escribe en memoria:
    // un sw que guarda un registro recien calculado necesita el valor bueno.
    mux4 #(.W(32)) mux_fwd_b (
        .d00 (RD2E),
        .d01 (ResultW),
        .d10 (ALUResultM),
        .d11 (32'd0),
        .sel (ForwardBE),
        .y   (WriteDataE)
    );

    // Despues del forwarding, los mismos dos mux2 del monociclo
    logic [31:0] SrcAE, SrcBE, ALUResultE;
    logic        zeroE, lessE, less_uE;

    mux2 #(.W(32)) mux_a (
        .d0  (FwdAE),
        .d1  (PCE),
        .sel (ALUSrcAE),
        .y   (SrcAE)
    );

    mux2 #(.W(32)) mux_b (
        .d0  (WriteDataE),
        .d1  (ImmExtE),
        .sel (ALUSrcBE),
        .y   (SrcBE)
    );

    alu alu_i (
        .src_a       (SrcAE),
        .src_b       (SrcBE),
        .alu_control (ALUControlE),
        .alu_result  (ALUResultE),
        .zero        (zeroE),
        .less        (lessE),
        .less_u      (less_uE)
    );

    // Destino del salto: PC de ESTA instruccion + inmediato, o rs1+imm (jalr)
    logic [31:0] PCPlusImmE;

    adder add_tgt (
        .a (PCE),
        .b (ImmExtE),
        .y (PCPlusImmE)
    );

    mux2 #(.W(32)) mux_jalr (
        .d0  (PCPlusImmE),
        .d1  ({ALUResultE[31:1], 1'b0}),
        .sel (JalrE),
        .y   (PCTargetE)
    );

    // Decision del salto en EX. Es exactamente el bloque 3 de control_unit,
    // aplicado a la instruccion que esta en EX con las banderas de la ALU,
    // que se calculan de los operandos YA adelantados.
    logic BranchTakenE;

    always_comb begin
        BranchTakenE = 1'b0;
        if (BranchE) begin
            case (funct3E)
                F3_BEQ : BranchTakenE =  zeroE;
                F3_BNE : BranchTakenE = ~zeroE;
                F3_BLT : BranchTakenE =  lessE;
                F3_BGE : BranchTakenE = ~lessE;
                F3_BLTU: BranchTakenE =  less_uE;
                F3_BGEU: BranchTakenE = ~less_uE;
                default: BranchTakenE = 1'b0;
            endcase
        end
    end

    assign PCSrcE = BranchTakenE | JumpE;

    // El mux de ResultSrc, adelantado a EX para los tres casos que ya tienen
    // su valor aqui (ALU, PC+4, ImmExt). Para un load (01) deja pasar la
    // direccion, que es lo que necesita la memoria en MEM. Asi EX/MEM lleva
    // siempre el valor definitivo de rd y el forwarding de un lui, un jal o
    // un auipc no adelanta basura.
    logic [31:0] ExResultE;

    mux4 #(.W(32)) mux_res_ex (
        .d00 (ALUResultE),
        .d01 (ALUResultE),
        .d10 (PCPlus4E),
        .d11 (ImmExtE),
        .sel (ResultSrcE),
        .y   (ExResultE)
    );

    // =========================================================================
    // EX/MEM                                                      (140 bits)
    //   resultado (definitivo), dato a escribir, PC+4, destino del salto,
    //   rd, funct3 y las senales de MEM y WB
    // =========================================================================
    logic [31:0] WriteDataM, PCPlus4M, PCTargetM;
    logic [2:0]  funct3M;
    logic [1:0]  ResultSrcM;
    logic        MemWriteM;

    pipe_reg #(.W(140)) reg_ex_mem (
        .clk (clk),
        .rst (rst),
        .en  (en),
        .clr (1'b0),
        .d   ({ExResultE,  WriteDataE, PCPlus4E, PCTargetE,
               rdE, funct3E, RegWriteE, ResultSrcE, MemWriteE}),
        .q   ({ALUResultM, WriteDataM, PCPlus4M, PCTargetM,
               rdM, funct3M, RegWriteM, ResultSrcM, MemWriteM})
    );

    // =========================================================================
    // MEM - memoria de datos
    // =========================================================================
    logic [31:0] ReadDataM;

    data_memory #(
        .DEPTH (DMEM_DEPTH)
    ) dmem (
        .clk    (clk),
        .we     (MemWriteM),
        .funct3 (funct3M),
        .addr   (ALUResultM),
        .wd     (WriteDataM),
        .rd     (ReadDataM)
    );

    // =========================================================================
    // MEM/WB                                                      (104 bits)
    //   dato leido, resultado, PC+4, rd y las senales de WB
    // =========================================================================
    logic [31:0] ReadDataW, ALUResultW, PCPlus4W;
    logic [1:0]  ResultSrcW;

    pipe_reg #(.W(104)) reg_mem_wb (
        .clk (clk),
        .rst (rst),
        .en  (en),
        .clr (1'b0),
        .d   ({ReadDataM, ALUResultM, PCPlus4M, rdM, RegWriteM, ResultSrcM}),
        .q   ({ReadDataW, ALUResultW, PCPlus4W, rdW, RegWriteW, ResultSrcW})
    );

    // =========================================================================
    // WB - escritura en el banco
    // =========================================================================
    // Las ramas 10 y 11 ya vienen resueltas desde EX dentro de ALUResultW; se
    // deja PC+4 en la 10 porque es el mismo valor y asi la tabla de ResultSrc
    // se lee igual que en el monociclo.
    mux4 #(.W(32)) mux_res (
        .d00 (ALUResultW),
        .d01 (ReadDataW),
        .d10 (PCPlus4W),
        .d11 (ALUResultW),
        .sel (ResultSrcW),
        .y   (ResultW)
    );

endmodule
