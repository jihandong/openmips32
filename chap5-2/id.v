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
    output reg wreg_o //whether rd exist
);

    // phase0 : prepare
    wire [5:0] op = inst_i[31:26];
    wire [4:0] rs = inst_i[25:21];
    wire [4:0] rt = inst_i[20:16];
    wire [4:0] rd = inst_i[15:11];
    wire [4:0] sa = inst_i[10:6];
    wire [4:0] func = inst_i[5:0];
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
            inst <= `InstValid;
        end else begin
            aluop_o <= `EXE_NOP_OP; alusel_o <= `EXE_RES_NOP;
            reg1_read_o <= `ReadDisable; reg1_addr_o <= `NOPRegAddr;
            reg2_read_o <= `ReadDisable; reg2_addr_o <= `NOPRegAddr;
            imm <= `ZeroWord;
            wreg_o <= `WriteDisable; wd_o <= `NOPRegAddr;
            inst <= `InstInvalid;
            case (op)
                `EXE_SPECIAL : begin
                    if (rs == `NOPRegAddr) begin
                        case(func)
                            `EXE_SLL : begin
                                aluop_o <= `EXE_SLL_OP; alusel_o <= `EXE_RES_SHIFT;
                                reg1_read_o <= `ReadEnable; reg1_addr_o <= rt;
                                reg2_read_o <= `ReadDisable;
                                imm[4:0] <= sa;
                                wreg_o <= `WriteEnable; wd_o <= rd;
                            end
                            `EXE_SRL  : begin
                                aluop_o <= `EXE_SRL_OP; alusel_o <= `EXE_RES_SHIFT;
                                reg1_read_o <= `ReadEnable; reg1_addr_o <= rt;
                                reg2_read_o <= `ReadDisable;
                                imm[4:0] <= sa; //logic
                                wreg_o <= `WriteEnable; wd_o <= rd;
                            end
                            `EXE_SRA  : begin
                                aluop_o <= `EXE_SRA_OP; alusel_o <= `EXE_RES_SHIFT;
                                reg1_read_o <= `ReadEnable; reg1_addr_o <= rt;
                                reg2_read_o <= `ReadDisable;
                                imm[4:0] <= sa; //arithmetic
                                wreg_o <= `WriteEnable; wd_o <= rd;
                            end
                            default : begin
                            end
                    end else begin
                        case(func)
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
                            `EXE_SLLV : begin
                                aluop_o <= `EXE_SLLV_OP; alusel_o <= `EXE_RES_SHIFT;
                                reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                                reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                                wreg_o <= `WriteEnable; wd_o <= rd;
                            end
                            `EXE_SRLV : begin
                                aluop_o <= `EXE_SRLV_OP; alusel_o <= `EXE_RES_SHIFT;
                                reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                                reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                                wreg_o <= `WriteEnable; wd_o <= rd;
                            end
                            `EXE_SRAV : begin
                                aluop_o <= `EXE_SRAV_OP; alusel_o <= `EXE_RES_SHIFT;
                                reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                                reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                                wreg_o <= `WriteEnable; wd_o <= rd;
                            end
                            `EXE_SYNC : begin
                                aluop_o <= `EXE_SYNC_OP; alusel_o <= `EXE_RES_NOP;
                                reg1_read_o <= `ReadDisable;
                                reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                                wreg_o <= `WriteDisable;
                            end
                            default : beigin
                            end
                        endcase
                    end
                end
                `EXE_ANDI : begin
                    aluop_o <= `EXE_AND_OP; alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    reg2_read_o <= `ReadDisable;
                    imm <= {16'b0, inst_i[15:0]};
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                `EXE_ORI : begin
                    aluop_o <= `EXE_OR_OP; alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    reg2_read_o <= `ReadDisable;
                    imm <= {16'b0, inst_i[15:0]}; //should be `RegWidth - 16
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                `EXE_XORI : begin
                    aluop_o <= `EXE_XOR_OP; alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    reg2_read_o <= `ReadDisable;
                    imm <= {16'b0, inst_i[15:0]};
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                `EXE_LUI : begin
                    aluop_o <= `EXE_OR_OP; alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    reg2_read_o <= `ReadDisable;
                    imm <= {16'b0, inst_i[15:0]};
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                `EXE_PREF : begin
                    aluop_o <= `EXE_PREF_OP; alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= `ReadDisable;
                    reg2_read_o <= `ReadDisable;
                    wreg_o <= `WriteEnable;
                end
                default : begin
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
            reg1_o <= ex_wdata_i;
        end else if ((reg2_read_o == `ReadEnable) && (reg2_addr_o == mem_wd_i) && (mem_wreg_i == `WriteEnable)) begin
            reg1_o <= mem_wdata_i;
        end else if (reg2_read_o == `ReadEnable) begin
            reg2_o <= reg2_data_i;
        end else if (reg2_read_o == `ReadDisable) begin
            reg2_o <= imm;
        end else begin
            reg2_o <= `ZeroWord;
        end
    end 

endmodule
