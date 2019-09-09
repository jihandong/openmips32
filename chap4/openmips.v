module openmips(
    input wire rst;
    input wire clk;
    input wire [`InstBus] rom_data_i;
    output wire [`InstAddrBus] rom_addr_o;
    output wire rom_ce_o;
);
    // outputModuleName_inputModuleName_portName
    // pc & if_id
    wire [`InstAddrBus] pc;
    assign rom_addr_o = pc; //output

    // if_id & id 
    wire [`InstAddrBus] ifid_id_pc;
    wire [`InstBus] ifid_id_inst;
    
    // id & id_ex
    wire [`AluOpBus] id_idex_aluop;
    wire [`AluSelBus] id_idex_alusel;
    wire [`RegBus] id_idex_reg1;
    wire [`RegBus] id_idex_reg2;
    wire [`RegAddrBus]id_idex_wd;
    wire id_idex_wreg;

    // id_ex & ex
    wire [`AluOpBus] idex_ex_aluop;
    wire [`AluSelBus] idex_ex_alusel;
    wire [`RegBus] idex_ex_reg1;
    wire [`RegBus] idex_ex_reg2;
    wire [`RegAddrBus]idex_ex_wd;
    wire idex_ex_wreg;

    // ex & ex_mem
    wire [`RegAddrBus] ex_exmem_wd;
    wire ex_exmem_wreg;
    wire [`RegBus] ex_exmem_wdata;

    // ex_mem & mem
    wire [`RegAddrBus] exmem_mem_wd;
    wire exmem_mem_wreg;
    wire [`RegBus] exmem_mem_wdata;    
    
    // mem & mem_wb
    wire [`RegAddrBus] mem_memwb_wd;
    wire mem_memwb_wreg;
    wire [`RegBus] mem_memwb_wdata;
    
    // id & regfile
    wire id_reg_reg1read;
    wire id_reg_reg2read;
    wire [`RegAddrBus] id_reg_reg1addr;
    wire [`RegAddrBus] id_reg_reg2addr;
    
    // wb & regfile
    wire [`RegAddrBus] memwb_reg_wd;
    wire memwb_reg_wreg;
    wire [`RegBus] memwb_reg_wdata;
    
    // regfile & id
    wire reg_id_rdata1;
    wire reg_id_rdata2;

    pc_reg pc_reg0(
        .rst(rst),
        .clk(clk),

        .pc(pc),        //output
        .ce(rom_ce_o)   //output
    );

    if_id if_id0(
        .rst(rst),
        .clk(clk),
        .if_pc(pc),
        .if_inst(rom_data_i), //input

        .id_pc(ifid_id_pc),
        .id_inst(ifid_id_inst)
    );

    id id0(
        .rst(rst),
        .pc_i(ifid_id_pc),
        .inst_i(ifid_id_inst),
        .reg1_data_i(reg_id_rdata1),
        .reg2_data_i(reg_id_rdata2),

        .aluop(id_idex_aluop),
        .slusel(id_idex_alusel),
        .reg1_o(id_idex_reg1),
        .reg2_o(id_idex_reg2),
        .wd_o(id_idex_wd),
        .wreg_o(id_idex_wreg),
        .reg1_read_o(id_reg_reg1read),
        .reg2_read_o(id_reg_reg2read),
        .reg1_addr_o(id_reg_reg1addr),
        .reg2_addr_o(id_reg_reg2addr)
    );

    regfile regfile0(
        .rst(rst),
        .clk(clk),
        .re1(id_reg_reg1read),
        .re2(id_reg_reg2read),
        .raddr1(id_reg_reg1addr),
        .raddr2(id_reg_reg2addr),
        .we(memwb_reg_wreg),
        .waddr(memwb_reg_wd),
        .wdata(memwb_reg_wdata),

        .rdata1(reg_id_rdata1),
        .rdata2(reg_id_rdata2)
    );

    id_ex id_ex0(
        .rst(rst),
        .clk(clk),
        .id_aluop(id_idex_aluop),
        .id_alusel(id_idex_alusel),
        .id_reg1(id_idex_reg1),
        .id_reg2(id_idex_reg2),
        .id_wd(id_idex_wd),
        .id_wreg(id_idex_wreg),

        .ex_aluop(idex_ex_aluop),
        .ex_alusel(idex_ex_alusel),
        .ex_reg1(idex_ex_reg1),
        .ex_reg2(idex_ex_reg2),
        .ex_wd(idex_ex_wd),
        .ex_wreg(idex_ex_wreg)
    );

    ex ex0(
        .rst(rst),
        .aluop_i(idex_ex_aluop),
        .alusel_i(idex_ex_alusel),
        .reg1_i(idex_ex_reg1),
        .reg2_i(idex_ex_reg2),
        .wd_i(idex_ex_wd),
        .wreg_i(idex_ex_wreg),

        .wd_o(ex_exmem_wd),
        .wreg_o(ex_exmem_wreg),
        .wdata_o(ex_exmem_wdata)
    );

    ex_mem ex_mem0(
        .rst(rst),
        .clk(clk),
        .ex_wd(ex_exmem_wd),
        .ex_wreg(ex_exmem_wreg),
        .ex_wdata(ex_exmem_wdata),

        .mem_wd(exmem_mem_wd),
        .mem_wreg(exmem_mem_wreg),
        .mem_wdata(exmem_mem_wdata),
    );

    mem mem0(
        .rst(rst),
        .wd_i(exmem_mem_wd),
        .wreg_i(exmem_mem_wreg),
        .wdata_i(exmem_mem_wdata),

        .wd_o(mem_memwb_wd),
        .wreg_o(mem_memwb_wreg),
        .wdata_o(mem_memwb_wdata),        
    );

    mem_wb mem_wb(
        .rst(rst),
        .clk(clk),
        .mem_wd(mem_memwb_wd),
        .mem_wreg(mem_memwb_wreg),
        .mem_wdata(mem_memwb_wdata),

        .wb_wd(memwb_reg_wb),
        .wb_wreg(memwb_reg_wreg),
        .wb_wdata(memwb_reg_wdata),
    );

endmodule
