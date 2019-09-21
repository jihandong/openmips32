/* id译码模块
 * 指令使用EXE_name表示，操作使用EXE_name_OP表示
 * 两者有区别，前者对应指令，后者对应ex阶段的操作
 * 比如andi和and的操作是相同的，只是操作数格式不同
 * id阶段可以解读指令操作数的值，所以经过id后andi和and再无区别 
 */
`include "defines.v"

module id(
    input wire rst,
    input wire [`InstAddrBus] pc_i,
    input wire [`InstBus] inst_i,
    //data of rs & rt, read from regfile
    input wire [`RegBus] reg1_data_i,
    input wire [`RegBus] reg2_data_i,
    //data hazard
    input wire ex_wreg_i,
    input wire [`RegAddrBus] ex_wd_i,
    input wire [`RegBus] ex_wdata_i,
    input wire mem_wreg_i,
    input wire [`RegAddrBus] mem_wd_i,
    input wire [`RegBus] mem_wdata_i,
    
    //addr of rs & rt, send to regfile
    output reg reg1_read_o,
    output reg reg2_read_o,
    output reg [`RegAddrBus] reg1_addr_o,
    output reg [`RegAddrBus] reg2_addr_o,
    //message sent to EX phase
    output reg [`AluOpBus] aluop_o, //op subtype
    output reg [`AluSelBus] alusel_o, //op type
    output reg [`RegBus] reg1_o,
    output reg [`RegBus] reg2_o,
    output reg [`RegAddrBus] wd_o, //addr of rd
    output reg wreg_o, //whether rd exist
    //stall request
    output reg stallreq
);

    // phase0 : prepare
    wire [5:0] op = inst_i[31:26];
    wire [4:0] rs = inst_i[25:21];
    wire [4:0] rt = inst_i[20:16];
    wire [4:0] rd = inst_i[15:11];
    wire [4:0] sa = inst_i[10:6];
    wire [5:0] func = inst_i[5:0];
    reg [`RegBus] imm;
    reg instvalid;

    // phase1 : decode the inst
    always @ (*) begin
        if (rst == `RstEnable) begin
            aluop_o <= `EXE_NOP_OP; alusel_o <= `EXE_RES_NOP;
            reg1_read_o <= `ReadDisable; reg1_addr_o <= `NOPRegAddr;
            reg2_read_o <= `ReadDisable; reg2_addr_o <= `NOPRegAddr;
            imm <= `ZeroWord;
            wreg_o <= `WriteDisable; wd_o <= `NOPRegAddr;
            instvalid <= `InstValid;
        end else begin
            aluop_o <= `EXE_NOP_OP; alusel_o <= `EXE_RES_NOP;
            reg1_read_o <= `ReadDisable; reg1_addr_o <= `NOPRegAddr;
            reg2_read_o <= `ReadDisable; reg2_addr_o <= `NOPRegAddr;
            imm <= `ZeroWord;
            wreg_o <= `WriteDisable; wd_o <= `NOPRegAddr;
            instvalid <= `InstValid;
            case (op)
                `EXE_SPECIAL : begin
                    case(func)
                        //logic inst
                        `EXE_AND : begin
                            aluop_o <= `EXE_AND_OP; alusel_o <= `EXE_RES_LOGIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_OR  : begin
                            aluop_o <= `EXE_OR_OP; alusel_o <= `EXE_RES_LOGIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_XOR : begin
                            aluop_o <= `EXE_XOR_OP; alusel_o <= `EXE_RES_LOGIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_NOR : begin
                            aluop_o <= `EXE_NOR_OP; alusel_o <= `EXE_RES_LOGIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_SYNC : begin
                            aluop_o <= `EXE_NOP_OP; alusel_o <= `EXE_RES_NOP;
                        end

                        //shift inst
                        `EXE_SLL : begin
                            aluop_o <= `EXE_SLL_OP; alusel_o <= `EXE_RES_SHIFT;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            imm[4:0] <= sa;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_SRL  : begin
                            aluop_o <= `EXE_SRL_OP; alusel_o <= `EXE_RES_SHIFT;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            imm[4:0] <= sa; //logic
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_SRA  : begin
                            aluop_o <= `EXE_SRA_OP; alusel_o <= `EXE_RES_SHIFT;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            imm[4:0] <= sa; //arithmetic
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_SLLV : begin
                            aluop_o <= `EXE_SLL_OP; alusel_o <= `EXE_RES_SHIFT;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_SRLV : begin
                            aluop_o <= `EXE_SRL_OP; alusel_o <= `EXE_RES_SHIFT;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_SRAV : begin
                            aluop_o <= `EXE_SRA_OP; alusel_o <= `EXE_RES_SHIFT;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end

                        //move inst
                        `EXE_MOVZ : begin
                            aluop_o <= `EXE_MOVZ_OP; alusel_o <= `EXE_RES_MOVE;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            if (reg2_o == `ZeroWord) begin
                                wreg_o <= `WriteEnable; wd_o <= rd;
                            end
                        end
                        `EXE_MOVN : begin
                            aluop_o <= `EXE_MOVN_OP; alusel_o <= `EXE_RES_MOVE;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            if (reg2_o != `ZeroWord) begin
                                wreg_o <= `WriteEnable; wd_o <= rd;
                            end
                        end
                        `EXE_MFHI : begin
                            aluop_o <= `EXE_MFHI_OP; alusel_o <= `EXE_RES_MOVE;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_MFLO : begin
                            aluop_o <= `EXE_MFLO_OP; alusel_o <= `EXE_RES_MOVE;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_MTHI : begin
                            aluop_o <= `EXE_MTHI_OP; alusel_o <= `EXE_RES_MOVE;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                        end
                        `EXE_MTLO : begin
                            aluop_o <= `EXE_MTLO_OP; alusel_o <= `EXE_RES_MOVE;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                        end
                        //arithmetic inst
                        `EXE_ADD  : begin
                            aluop_o <= `EXE_ADD_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_ADDU : begin
                            aluop_o <= `EXE_ADDU_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_SUB  : begin
                            aluop_o <= `EXE_SUB_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_SUBU : begin
                            aluop_o <= `EXE_SUBU_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_SLT  : begin
                            aluop_o <= `EXE_SLT_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_SLTU : begin
                            aluop_o <= `EXE_SLTU_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_MULT : begin
                           aluop_o <= `EXE_MULT_OP; alusel_o <= `EXE_RES_MUL;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                        end
                        `EXE_MULTU: begin
                            aluop_o <= `EXE_MULTU_OP; alusel_o <= `EXE_RES_MUL;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                        end
                        default : begin
                            instvalid <= `InstInvalid;
                        end
                    endcase
                end
                `EXE_SPECIAL2 : begin
                    case(func)
                        `EXE_CLZ   : begin
                            aluop_o <= `EXE_CLZ_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_CLO   : begin
                            aluop_o <= `EXE_CLO_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_MUL : begin
                            aluop_o <= `EXE_MUL_OP; alusel_o <= `EXE_RES_MUL;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        default : begin
                            instvalid <= `InstInvalid;
                        end
                    endcase
                end
                //logic inst
                `EXE_ANDI : begin
                    aluop_o <= `EXE_AND_OP; alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    imm <= {16'b0, inst_i[15:0]};
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                `EXE_ORI : begin
                    aluop_o <= `EXE_OR_OP; alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    imm <= {16'b0, inst_i[15:0]}; //should be `RegWidth - 16
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                `EXE_XORI : begin
                    aluop_o <= `EXE_XOR_OP; alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    imm <= {16'b0, inst_i[15:0]};
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                `EXE_LUI : begin
                    aluop_o <= `EXE_OR_OP; alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    imm <= {inst_i[15:0], 16'b0};
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                `EXE_PREF : begin
                    aluop_o <= `EXE_NOP_OP; alusel_o <= `EXE_RES_NOP;
                end
                //arithmetic inst
                `EXE_ADDI  : begin
                    aluop_o <= `EXE_ADDI_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    imm <= {16'b0, inst_i[15:0]};
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                `EXE_ADDIU : begin
                    aluop_o <= `EXE_ADDIU_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    imm <= {{16{inst_i[15]}}, inst_i[15:0]};
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                `EXE_SLTI  : begin
                    aluop_o <= `EXE_SLT_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    imm <= {16'b0, inst_i[15:0]};
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                `EXE_SLTIU : begin
                    aluop_o <= `EXE_SLTU_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    imm <= {{16{inst_i[15]}}, inst_i[15:0]};
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                default : begin
                    instvalid <= `InstInvalid;
                end
            endcase
        end
    end

    // phase2 : get data of rs
    always @ (*) begin
        if (rst == `RstEnable) begin
            reg1_o <= `ZeroWord;
        end else if ((reg1_read_o == `ReadEnable) && (reg1_addr_o == ex_wd_i) && (ex_wreg_i == `WriteEnable)) begin
            reg1_o <= ex_wdata_i; //bypass for Data Harzard
        end else if ((reg1_read_o == `ReadEnable) && (reg1_addr_o == mem_wd_i) && (mem_wreg_i == `WriteEnable)) begin
            reg1_o <= mem_wdata_i; //bypass for Data Harzard
        end else if (reg1_read_o == `ReadEnable) begin
            reg1_o <= reg1_data_i;
        end else if (reg1_read_o == `ReadDisable) begin
            reg1_o <= imm;
        end else begin
            reg1_o <= `ZeroWord;
        end
    end 

    // phase3 : get data of rt
    always @ (*) begin
        if (rst == `RstEnable) begin
            reg2_o <= `ZeroWord;
        end else if ((reg2_read_o == `ReadEnable) && (reg2_addr_o == ex_wd_i) && (ex_wreg_i == `WriteEnable)) begin
            reg2_o <= ex_wdata_i;
        end else if ((reg2_read_o == `ReadEnable) && (reg2_addr_o == mem_wd_i) && (mem_wreg_i == `WriteEnable)) begin
            reg2_o <= mem_wdata_i;
        end else if (reg2_read_o == `ReadEnable) begin
            reg2_o <= reg2_data_i;
        end else if (reg2_read_o == `ReadDisable) begin
            reg2_o <= imm;
        end else begin
            reg2_o <= `ZeroWord;
        end
    end 

endmodule

