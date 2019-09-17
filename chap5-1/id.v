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

    // phase1 : decode the inst
    always @ (*) begin
        if (rst == `RstEnable) begin
            aluop_o <= `EXE_NOP_OP;
            alusel_o <= `EXE_RES_NOP;
            reg1_read_o <= `ReadDisable;
            reg1_addr_o <= `NOPRegAddr;
            reg2_read_o <= `ReadDisable;
            reg2_addr_o <= `NOPRegAddr;
            imm <= `ZeroWord;
            wreg_o <= `WriteDisable;
            wd_o <= `NOPRegAddr;
        end else begin
            case (op)
                `EXE_ORI : begin
                    aluop_o <= `EXE_OR_OP;
                    alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= `ReadEnable;
                    reg1_addr_o <= rs;
                    reg2_read_o <= `ReadDisable;
                    reg2_addr_o <= `ZeroWord;
                    imm <= {16'b0, inst_i[15:0]}; //should be `RegWidth - 16
                    wreg_o <= `WriteEnable;
                    wd_o <= rt;
                end
                default : begin
                    aluop_o <= `EXE_NOP_OP;
                    alusel_o <= `EXE_RES_NOP;
                    reg1_read_o <= `ReadDisable;
                    reg1_addr_o <= `NOPRegAddr;
                    reg2_read_o <= `ReadDisable;
                    reg2_addr_o <= `NOPRegAddr;
                    imm <= `ZeroWord;
                    wreg_o <= `WriteDisable;
                    wd_o <= `NOPRegAddr;
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
