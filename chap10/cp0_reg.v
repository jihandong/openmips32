`include "defines.v"

module cp0_reg(
    input wire clk,
    input wire rst,
    input wire we_i,
    input wire [4:0] waddr_i,
    input wire [4:0] raddr_i,
    input wire [`RegBus] data_i,
    input wire [5:0] int_i,

    output reg [`RegBus] data_o,
    output reg [`RegBus] count_o,
    output reg [`RegBus] compare_o,
    output reg [`RegBus] status_o,
    output reg [`RegBus] cause_o,
    output reg [`RegBus] epc_o,
    output reg [`RegBus] config_o,
    output reg [`RegBus] pride_o,
    output reg time_int_o
);

    // write phase
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            count_o <= `ZeroWord;
			compare_o <= `ZeroWord;
			status_o <= 32'x00010000000000000000000000000000; //CU==0001 means CP0 exists
			cause_o <= `ZeroWord;
			epc_o <= `ZeroWord;
			config_o <= 32'b00000000000000001000000000000000; //BE==1 means big-endian, MT==00 means MMU not exists
			prid_o <= 32'b00000000010011000000000100000010; //read-only message
        end else begin
            count_o <= count_o + 1;
            cause_o[15:10] <= int_i; //keep interrupt declare
            if ((compare_o != `ZeroWord) && (count_o == compare_o)) begin
                time_int_o <= `InterruptAssert;
            end
            if (we_i == `WriteEnable) begin
                case(waddr_i)
                    `CP0_REG_COUNT :	begin
			    		count_o <= data_i;
			    	end
			    	`CP0_REG_COMPARE : begin
			    		compare_o <= data_i;
                        timer_int_o <= `InterruptNotAssert;
			    	end
			    	`CP0_REG_STATUS : begin
			    		status_o <= data_i;
			    	end
			    	`CP0_REG_CAUSE : begin
			    		cause_o[9:8] <= data_i[9:8]; //only IP[1:0]
						cause_o[23] <= data_i[23]; //and IV
						cause_o[22] <= data_i[22]; //and WP are writable
			    	end
			    	`CP0_REG_EPC : begin
			    		epc_o <= data_i;
			    	end
			    	default : begin
			    	end
                endcase
            end
        end
    end

    // read phase
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            data_o <= `ZeroWord;
        end else begin
            case(raddr_i)
                `CP0_REG_COUNT :	begin
					data_o <= count_o;
				end
				`CP0_REG_COMPARE : begin
					data_o <= compare_o;
				end
				`CP0_REG_STATUS : begin
					data_o <= status_o;
				end
				`CP0_REG_CAUSE : begin
					data_o <= cause_o;
				end
				`CP0_REG_EPC : begin
					data_o <= epc_o;
				end
				`CP0_REG_PrId : begin //read-only
					data_o <= prid_o;
				end
				`CP0_REG_CONFIG : begin //read-only
					data_o <= config_o;
				end	
				default : begin
				end
            endcase
        end
    end

endmodule