`include "defines.v"

module pc_reg(
    input wire clk,
    input wire rst,
    input wire [5:0] stall, //stall command
    output reg ce,
    output reg [`InstAddrBus] pc
);
    
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            ce <= `ChipDisable;
        end else begin
            ce <= `ChipEnable;
        end
    end

    // no inst shall be executed when ChipDisable
    always @ (posedge clk) begin
        if (ce == `ChipDisable) begin
            pc <= `ZeroWord;
        end else if (stall[0] == `NoStop) begin
            pc <= pc + 4'h4; //next inst
        end
    end

endmodule
