`include "defines.v"

module inst_rom(
    input wire ce,
    input wire [`InstAddrBus] addr,
    output reg [`InstBus] inst
);

    // phase0 : define inst rom
    reg[`InstBus] inst_mem[0:`InstMemNum - 1];

    // phase1 : initial read the inst
    initial $readmemh ("inst_rom.data", inst_mem);

    // phase2 : 
    always @ (*) begin
        if (ce == `ChipDisable) begin
            inst <= `ZeroWord;
        end else begin 
            inst <= inst_mem[addr[`InstMemNumLog2 + 1:2]]; //divide by 4
        end
    end

endmodule