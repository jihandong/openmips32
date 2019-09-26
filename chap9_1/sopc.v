`include "defines.v"

module sopc(
    input wire rst,
    input wire clk
);

    wire rom_ce;
    wire [`InstAddrBus] rom_addr;
    wire [`InstBus] inst;

    wire [`DataAddrBus] ram_addr;
    wire [`DataBus] ram_data;
    wire [3:0] ram_sel;
    wire ram_we;
    wire ram_ce;
    wire [`DataBus] mem_data;
    
    openmips openmips0(
        .rst(rst),
        .clk(clk),
        .rom_data_i(inst),
        .ram_data_i(mem_data),

        .rom_addr_o(rom_addr),
        .rom_ce_o(rom_ce),
        .ram_addr_o(ram_addr),
        .ram_data_o(ram_data),
        .ram_sel_o(ram_sel),
        .ram_we_o(ram_we),
        .ram_ce_o(ram_ce)
    );

    inst_rom inst_rom0(
        .addr(rom_addr),
        .ce(rom_ce),

        .inst(inst)
    );

    data_ram data_ram0(
        .clk(clk),
        .sel(ram_sel),
        .we(ram_we),
        .ce(ram_ce),
        .addr(ram_addr),
        .data_i(ram_data),

        .data_o(mem_data)
    );

endmodule