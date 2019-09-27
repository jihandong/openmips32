`include "defines.v"

module ex_mem(
    input wire clk,
    input wire rst,
    input wire [`RegAddrBus] ex_wd,
    input wire ex_wreg,
    input wire [`RegBus] ex_wdata,
    input wire ex_whilo,
    input wire [`RegBus] ex_hi,
    input wire [`RegBus] ex_lo,
    input wire [5:0] stall, //stall command
    //for madd & msub
    input wire cnt_i,
    input wire [`DoubleRegBus] hilo_temp_i,
    //load-save
    input wire [`AluOpBus] ex_aluop,
    input wire [`RegBus] ex_mem_addr,
    input wire [`RegBus] ex_reg2,

    output reg [`RegAddrBus] mem_wd,
    output reg mem_wreg,
    output reg [`RegBus] mem_wdata,
    output reg mem_whilo,
    output reg [`RegBus] mem_hi,
    output reg [`RegBus] mem_lo,
    //for madd & msub
    output reg cnt_o,
    output reg [`DoubleRegBus] hilo_temp_o,
    //load-save
    output reg [`AluOpBus] mem_aluop,
    output reg [`RegBus] mem_mem_addr,
    output reg [`RegBus] mem_reg2
);

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            mem_wd <= `NOPRegAddr;
            mem_wreg <= `WriteDisable;
            mem_wdata <= `ZeroWord;
            mem_whilo <= `WriteDisable;
            mem_hi <= `ZeroWord;
            mem_lo <= `ZeroWord;
            cnt_o <= 2'b00;
            hilo_temp_o <= {`ZeroWord, `ZeroWord};
            mem_aluop <= `EXE_NOP_OP;
            mem_mem_addr <= `ZeroWord;
            mem_reg2 <= `ZeroWord;
        end else if ((stall[3] == `Stop) && (stall[4] == `NoStop)) begin
            mem_wd <= `NOPRegAddr;
            mem_wreg <= `WriteDisable;
            mem_wdata <= `ZeroWord;
            mem_whilo <= `WriteDisable;
            mem_hi <= `ZeroWord;
            mem_lo <= `ZeroWord;
            cnt_o <= cnt_i;
            hilo_temp_o <= hilo_temp_i;
            mem_aluop <= `EXE_NOP_OP;
            mem_mem_addr <= `ZeroWord;
            mem_reg2 <= `ZeroWord;
        end else if (stall[3] == `NoStop) begin
            mem_wd <= ex_wd;
            mem_wreg <= ex_wreg;
            mem_wdata <= ex_wdata;
            mem_whilo <= ex_whilo;
            mem_hi <= ex_hi;
            mem_lo <= ex_lo;
            cnt_o <= 2'b00;
            hilo_temp_o <= {`ZeroWord, `ZeroWord};
            mem_aluop <= ex_aluop;
            mem_mem_addr <= ex_mem_addr;
            mem_reg2 <= ex_reg2;
        end else begin
            cnt_o <= cnt_i;
            hilo_temp_o <= hilo_temp_i;
        end
    end

endmodule