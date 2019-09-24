`include "defines.v"

module ctrl(
    input wire rst,
    input wire stallreq_ex,
    input wire stallreq_id,    
    
    output reg [5:0] stall
);

    always @ (*) begin
        if (rst == `RstEnable) begin
            stall <= 6'b000000;
        end else if (stallreq_ex == `Stop) begin
            stall <= 6'b001111;
        end else if (stallreq_id == `Stop) begin
            stall <= 6'b000111;
        end else begin
            stall <= 6'b000000;
        end
    end

endmodule