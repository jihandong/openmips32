`include "defines.v"

module sopc(
    input wire rst,
    input wire clk
);

    wire ce;
    wire [`InstAddrBus] addr;
    wire [`InstBus] inst;
    
    openmips openmips0(
        .rst(rst),
        .clk(clk),
        .rom_data_i(inst),

        .rom_addr_o(addr),
        .rom_ce_o(ce)
    );

    inst_rom inst_rom0(
        .addr(addr),
        .ce(ce),

        .inst(inst)
    );

endmodule