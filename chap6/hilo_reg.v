`include "defines.v"

module hilo_reg(
    input wire rst,
    input wire clk,
    input wire we,
    input wire [`RegBus] hi_i,
    input wire [`RegBus] lo_i,

    output reg [`RegBus] hi_o,
    output reg [`RegBus] lo_o
);

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            {hi_o, lo_o} <= {`ZeroWord, `ZeroWord};
        end else if (we == `WriteEnable) begin
            {hi_o, lo_o} <= {hi_i, lo_i};
        end
    end

endmodule