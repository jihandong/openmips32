module pc_reg(
    input wire clk,
    input wire rst,
    output reg ce,
    output reg [`RegAddrBus] pc;
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
            pc <= `zeroword;
        end else begin
            pc <= pc + 4'h4; //next inst
        end
    end

endmodule
