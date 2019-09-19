`include "defines.v"

module ex(
    input wire rst,
    input wire [`AluSelBus] alusel_i,
    input wire [`AluOpBus] aluop_i,
    input wire [`RegBus] reg1_i,
    input wire [`RegBus] reg2_i,
    input wire [`RegAddrBus] wd_i,
    input wire wreg_i,

    output reg [`RegAddrBus] wd_o,  //written reg addr
    output reg wreg_o,
    output reg [`RegBus] wdata_o    //written reg data
);

    //phase0 : keep result
    reg [`RegBus] logicRes;
    reg [`RegBus] shiftRes;

    // phase1 : do alu (according to aluop_i)
    always @ (*) begin
        if (rst == `RstEnable) begin
            logicRes <= `ZeroWord;
            shiftRes <= `ZeroWord;
        end else begin
            case (aluop_i)
                `EXE_AND_OP : begin
                    logicRes <= reg1_i & reg2_i;
                end
                `EXE_OR_OP  : begin
                    logicRes <= reg1_i | reg2_i;
                end
                `EXE_XOR_OP : begin
                    logicRes <= reg1_i ^ reg2_i;
                end
                `EXE_NOR_OP : begin
                    logicRes <= ~(reg1_i | reg2_i);
                end
                `EXE_SLL_OP : begin
                    shiftRes <= reg1_i << reg2_i[4:0];
                end
                `EXE_SRL_OP : begin
                    shiftRes <= reg1_i >> reg2_i[4:0];
                end
                `EXE_SRA_OP : begin
                    shiftRes <= reg1_i >>> reg2_i[4:0];
                end
                default : begin
                    logicRes <= `ZeroWord;
                    shiftRes <= `ZeroWord;
                end
            endcase
        end
    end

    // phase2 : choose a result (according to alusel_i)
    always @ (*) begin
        wd_o <= wd_i;
        wreg_o <= wreg_i;
        case (alusel_i)
            `EXE_RES_LOGIC : begin
                wdata_o <= logicRes;
            end
            `EXE_RES_SHIFT : begin
                wdata_o <= shiftRes;
            end
            default : begin
                wdata_o <= `ZeroWord;
            end
        endcase
    end

endmodule
