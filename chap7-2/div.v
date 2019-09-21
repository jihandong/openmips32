`include "defines.v"

module div(
    input wire rst,    
    input wire clk,
    input wire sign_div_i,
    input wire [`RegBus] opdata1_i,
    input wire [`RegBus] opdata2_i,
    input wire start_i,
    input wire annul_i,

    output reg [`DoubleRegBus] result_o,
    output reg ready_o 
);

    reg [5:0] cnt;
    reg [1:0] state;
    reg [64:0] div_end;
    reg [`RegBus] divisor;
    reg [`RegBus] op1_temp;
    reg [`RegBus] op2_temp;
    wire [32:0] div_temp;

    assign div_temp = {1'b0, div_end[63:32]} - {1'b0, divisor};

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            state <= `DivFree;
            ready_o <= `DivResultNotReady;
            result_o <= {`ZeroWord, `ZeroWord};
        end else begin
            case(state)
                `DivFree : begin
                    if ((start_i == `DivStart) && (annul_i == 1'b0)) begin
                        if (opdata2_i == `ZeroWord) begin
                            state <= `DivByZero;
                        end else begin
                            state <= `DivOn;
                            cnt <= 6'b000000;
                            if ((sign_div_i == 1'b1) && (opdata1_i[31])) begin
                                op1_temp = ~opdata1_i + 1;
                            end else begin
                                op1_temp = opdata1_i;
                            end
                            if ((sign_div_i == 1'b1) && (opdata2_i[31])) begin
                                op2_temp = ~opdata1_i + 1;
                            end else begin
                                op2_temp = opdata1_i;
                            end
                            div_end <= {`ZeroWord, `ZeroWord};
                            div_end[32:1] <= op1_temp;
                            divisor <= op2_temp;
                        end
                    end else begin
                        ready_o <= `DivResultNotReady;
                        result_o <= {`ZeroWord, `ZeroWord};
                    end
                end

                `DivByZero : begin
                    state <= `DivEnd;
                    result_o <= {`ZeroWord, `ZeroWord};
                end

                `DivOn : begin
                    if (annul_i == 1'b0) begin
                        if (cnt < `RegWidth) begin
                            if (div_temp[32] == 1'b1) begin
                                div_end <= {div_end, 1'b0};
                            end else begin
                                div_end <= {div_temp, div_end, 1'b0};
                            end
                            cnt <= cnt + 1;
                        end else begin
                            if ((sign_div_i == 1'b1) && (opdata1_i[31] ^ opdata2_i[31] == 1'b1)) begin
                                div_end[31:0] <= ~div_end[31:0] + 1;
                            end
                            if ((sign_div_i == 1'b1) && (opdata1_i[31] ^ div_end[64] == 1'b1)) begin
                                div_end[64:33] <= ~div_end[64:33] + 1;
                            end
                            state <= `DivEnd;
                            cnt <= 6'b000000;
                        end  
                    end else begin 
                        state <= `DivFree;
                    end 
                end

                `DivEnd : begin
                    ready_o <= `DivResultReady;
                    result_o <= div_end;
                    if (start_i == `DivStop) begin //back
                        state <= `DivFree;
                        ready_o <= `DivResultNotReady;
                        result_o <= {`ZeroWord, `ZeroWord};
                    end
                end

                default : begin
                    state <= `DivFree;
                    ready_o <= `DivResultNotReady;
                    result_o <= {`ZeroWord, `ZeroWord};
                end
            endcase
        end
    end
endmodule