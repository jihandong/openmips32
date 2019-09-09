module if_id(
    input wire clk,
    input wire rst,
    input wire [`InstAddrBus] if_pc;
    input wire [`InstBus] if_inst;
    
    input reg [`InstAddrBus] id_pc;
    input reg [`InstBus] id_inst;
);

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            id_pc <= `ZeroWord;
            id_inst <= `ZeroWord;
        end else begin
            id_pc <= ex_wd;
            id_inst <= ex_wreg;
        end
    end

endmodule
