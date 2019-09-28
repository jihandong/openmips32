`include "defines.v"

module id_ex(
    input wire clk,
    input wire rst,
    input wire [`AluSelBus] id_alusel,
    input wire [`AluOpBus] id_aluop,
    input wire [`RegBus] id_reg1,
    input wire [`RegBus] id_reg2,
    input wire [`RegAddrBus] id_wd,
    input wire id_wreg,
    input wire [5:0] stall, //stall command
    output reg [`AluSelBus] ex_alusel,
    output reg [`AluOpBus] ex_aluop,
    output reg [`RegBus] ex_reg1,
    output reg [`RegBus] ex_reg2,
    output reg [`RegAddrBus] ex_wd,
    output reg ex_wreg,

    //jump-branch
    input wire [`RegBus] id_link_address,
    input wire id_is_in_delayslot,
    input wire next_inst_in_delayslot_i,
    output reg [`RegBus] ex_link_address,
    output reg ex_is_in_delayslot,
    output reg is_in_delayslot_o,

    //load-save
    input wire [`RegBus] id_inst,
    output reg [`RegBus] ex_inst,

    //chap11 : exception
    input wire                  flush,
    input wire [31:0]           id_excepttype,
    input wire [`InstAddrBus]   id_current_inst_addr,
    output reg [31:0]           ex_excepttype,
    output reg [`InstAddrBus]   ex_current_inst_addr
);

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            ex_alusel <= `EXE_RES_NOP;
            ex_aluop <= `EXE_NOP_OP;
            ex_reg1 <= `ZeroWord;
            ex_reg2 <= `ZeroWord;
            ex_wd <= `WriteDisable;
            ex_wreg <= `NOPRegAddr;
            ex_link_address <= `ZeroWord;
			ex_is_in_delayslot <= `NotInDelaySlot;
	        is_in_delayslot_o <= `NotInDelaySlot;
            ex_inst <= `ZeroWord;
            ex_excepttype <= `ZeroWord,
            ex_current_inst_addr <= `ZeroWord;
        end else if (flush == 1'b1) begin //clear pipline
            ex_alusel <= `EXE_RES_NOP;
            ex_aluop <= `EXE_NOP_OP;
            ex_reg1 <= `ZeroWord;
            ex_reg2 <= `ZeroWord;
            ex_wd <= `WriteDisable;
            ex_wreg <= `NOPRegAddr;
            ex_link_address <= `ZeroWord;
			ex_is_in_delayslot <= `NotInDelaySlot;
	        is_in_delayslot_o <= `NotInDelaySlot;
            ex_inst <= `ZeroWord;
            ex_excepttype <= `ZeroWord,
            ex_current_inst_addr <= `ZeroWord;
        end else if ((stall[2] == `Stop) && (stall[3] == `NoStop)) begin
            ex_alusel <= `EXE_RES_NOP;
            ex_aluop <= `EXE_NOP_OP;
            ex_reg1 <= `ZeroWord;
            ex_reg2 <= `ZeroWord;
            ex_wd <= `WriteDisable;
            ex_wreg <= `NOPRegAddr;
            ex_link_address <= `ZeroWord;
			ex_is_in_delayslot <= `NotInDelaySlot;
	        is_in_delayslot_o <= `NotInDelaySlot;
            ex_inst <= `ZeroWord;
            ex_excepttype <= `ZeroWord,
            ex_current_inst_addr <= `ZeroWord;
        end else if (stall[2] == `NoStop) begin
            ex_alusel <= id_alusel;
            ex_aluop <= id_aluop;
            ex_reg1 <= id_reg1;
            ex_reg2 <= id_reg2;
            ex_wd <= id_wd;
            ex_wreg <= id_wreg;
            ex_link_address <= id_link_address;
			ex_is_in_delayslot <= id_is_in_delayslot;
	        is_in_delayslot_o <= next_inst_in_delayslot_i;
            ex_inst <= id_inst;
            ex_excepttype <=id_excepttype,
            ex_current_inst_addr <= id_current_inst_addr;
        end
    end

endmodule