`include "defines.v"

module regfile(
    input wire clk,
    input wire rst,
    //ID phase
    input wire re1,
    input wire re2,
    input wire [`RegAddrBus] raddr1,
    input wire [`RegAddrBus] raddr2,
    //WB phase
    input wire we,
    input wire [`RegAddrBus] waddr,
    input wire [`RegBus] wdata,
    //values of rs & rt
    output reg [`RegBus] rdata1,
    output reg [`RegBus] rdata2
);

    // phase0 : dfine 32 registers
    reg [`RegBus] regs[0:`RegNum - 1];

    // phase1 : WB phase
    always @ (posedge clk) begin
        if ((rst == `RstDisable) && (we == `WriteEnable) && (waddr != `NOPRegAddr)) begin
            regs[waddr] <= wdata;
        end
    end

    // phase2 : get data of rs 
    always @ (*) begin
        if ((rst == `RstEnable) || (raddr1 == `NOPRegAddr)) begin   //rst or no inst
            rdata1 <= `ZeroWord;
        end else if ((raddr1 == waddr) && (we == `WriteEnable) && (re1 == `ReadEnable)) begin   //WB before read
            rdata1 <= wdata;
        end else if (re1 == `ReadEnable) begin  //just read
            rdata1 <= regs[raddr1];
        end else begin
            rdata1 <= `ZeroWord;
        end
    end

    // phase3 : get data of rt   
    always @ (*) begin
        if ((rst == `RstEnable) || (raddr2 == `NOPRegAddr)) begin
            rdata2 <= `ZeroWord;
        end else if ((raddr2 == waddr) && (we == `WriteEnable) && (re2 == `ReadEnable)) begin
            rdata2 <= wdata;
        end else if (re2 == `ReadEnable) begin
            rdata2 <= regs[raddr2];
        end else begin
            rdata2 <= `ZeroWord;
        end
    end

endmodule
