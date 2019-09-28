`include "defines.v"

module ctrl(
    input wire rst,
    input wire stallreq_ex,
    input wire stallreq_id,    
    output reg [5:0] stall,

    //chap11 : exception
    input wire [31:0]       excepttype_i,
	input wire [`RegBus]    cp0_epc_i,
    output reg [`RegBus]    new_pc,
	output reg              flush
);

    always @ (*) begin
        if (rst == `RstEnable) begin
            stall <= 6'b000000;
            flush <= 1'b0;
            new_pc <= `ZeroWord;
        end else if (excepttype_i != `ZeroWord) begin
            stall <= 6'b000000;
            flush <= 1'b0;
            case (excepttype_i)
				32'h00000001:		begin   //interrupt
					new_pc <= 32'h00000020;
				end
				32'h00000008:		begin   //syscall
					new_pc <= 32'h00000040;
				end
				32'h0000000a:		begin   //inst_invalid
					new_pc <= 32'h00000040;
				end
				32'h0000000d:		begin   //trap
					new_pc <= 32'h00000040;
				end
				32'h0000000c:		begin   //overflow
					new_pc <= 32'h00000040;
				end
				32'h0000000e:		begin   //eret
					new_pc <= cp0_epc_i;
				end
				default	: begin
				end
			endcase
        end else if (stallreq_ex == `Stop) begin
            stall <= 6'b001111;
        end else if (stallreq_id == `Stop) begin
            stall <= 6'b000111;
        end else begin
            stall <= 6'b000000;
        end
    end

endmodule