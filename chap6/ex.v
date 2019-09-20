`include "defines.v"

module ex(
    input wire rst,
    input wire [`AluSelBus] alusel_i,
    input wire [`AluOpBus] aluop_i,
    input wire [`RegBus] reg1_i,
    input wire [`RegBus] reg2_i,
    input wire [`RegAddrBus] wd_i,
    input wire wreg_i,
    //hilo reg
    input wire [`RegBus] hi_i,
    input wire [`RegBus] lo_i,
    input wire wb_whilo_i,
    input wire [`RegBus] wb_hi_i,
    input wire [`RegBus] wb_lo_i,
    input wire mem_whilo_i,
    input wire [`RegBus] mem_hi_i,
    input wire [`RegBus] mem_lo_i,

    output reg [`RegAddrBus] wd_o,  //written reg addr
    output reg wreg_o,
    output reg [`RegBus] wdata_o,   //written reg data
    //hilo reg
    output reg whilo_o,
    output reg [`RegBus] hi_o,
    output reg [`RegBus] lo_o 
);

    //phase0 : keep result
    reg [`RegBus] logicRes;
    reg [`RegBus] shiftRes;
    reg [`RegBus] moveRes;
    reg [`RegBus] HI;
    reg [`RegBus] LO;

    // phase 1 : fresh HI and LO
    always @ (*) begin
        if (rst == `RstEnable) begin
            {HI, LO} <= {`ZeroWord, `ZeroWord};
        end else if (mem_whilo_i == `WriteEnable) begin
            {HI, LO} <= {mem_hi_i, mem_lo_i};
        end else if (wb_whilo_i == `WriteEnable) begin
            {HI, LO} <= {wb_hi_i, wb_lo_i};
        end else begin
            {HI, LO} <= {hi_i, lo_i};
        end
    end

    // phase2.1 : do logic alu (according to aluop_i)
    always @ (*) begin
        if (rst == `RstEnable) begin
            logicRes <= `ZeroWord;
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
                default : begin
                    logicRes <= `ZeroWord;
                end
            endcase
        end
    end

    // phase2.2 : do shift alu
    always @ (*) begin
        if (rst == `RstEnable) begin
            shiftRes <= `ZeroWord;
        end else begin
            case (aluop_i)
                `EXE_SLL_OP : begin
                    shiftRes <= reg2_i << reg1_i[4:0];
                end
                `EXE_SRL_OP : begin
                    shiftRes <= reg2_i >> reg1_i[4:0];
                end
                `EXE_SRA_OP : begin
                    shiftRes <= ($signed(reg2_i)) >>> reg1_i[4:0];
                end
                default : begin
                    shiftRes <= `ZeroWord;
                end
            endcase
        end
    end

    // phase2.3 : do move alu
    always @ (*) begin
        if (rst == `RstEnable) begin
            moveRes <= `ZeroWord;
        end else begin
            case (aluop_i)
                `EXE_MOVZ_OP: begin
                    moveRes <= reg1_i;
                end
                `EXE_MOVN_OP: begin
                    moveRes <= reg1_i;
                end
                `EXE_MFHI_OP : begin
                    moveRes <= HI;
                end
                `EXE_MFLO_OP : begin
                    moveRes <= LO;
                end
                default : begin
                    moveRes <= `ZeroWord;
                end               
            endcase
        end
    end

    // phase3 : choose a result (according to alusel_i)
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
            `EXE_RES_MOVE : begin
                wdata_o <= moveRes; 
            end
            default : begin
                wdata_o <= `ZeroWord;
            end
        endcase
    end

    // phase4 : MTHI and MTLO
    always @ (*) begin
        if (rst == `RstEnable) begin
            whilo_o <= `WriteDisable;
            hi_o <= `ZeroWord;
            lo_o <= `ZeroWord;
        end else if (aluop_i == `EXE_MTHI_OP) begin
            whilo_o <= `WriteEnable;
            hi_o <= reg1_i;
            lo_o <= LO;             
        end else if (aluop_i == `EXE_MTLO_OP) begin
            whilo_o <= `WriteEnable;
            hi_o <= HI;
            lo_o <= reg1_i;
        end else begin
            whilo_o <= `WriteDisable;
            hi_o <= `ZeroWord;
            lo_o <= `ZeroWord;
        end
    end 
endmodule
