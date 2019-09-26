`include "defines.v"

module openmips(
    input wire rst,
    input wire clk,
    input wire [`InstBus] rom_data_i,

    output wire [`InstAddrBus] rom_addr_o,
    output wire rom_ce_o,
    //load-store
    input wire [`RegBus] ram_data_i,
    output wire [`RegBus] ram_addr_o,
    output wire [`RegBus] ram_data_o,
    output wire [3:0] ram_sel_o,
    output wire ram_we_o,
    output wire ram_ce_o
);
    // outputModuleName_inputModuleName_portName
    // pc & if_id
    wire [`InstAddrBus] pc;
    assign rom_addr_o = pc; //output

    // if_id & id 
    wire [`InstAddrBus] ifid_id_pc;
    wire [`InstBus] ifid_id_inst;
    
    // inst decode id->id_ex->ex
    wire [`AluOpBus] id_idex_aluop;
    wire [`AluSelBus] id_idex_alusel;
    wire [`RegBus] id_idex_reg1;
    wire [`RegBus] id_idex_reg2;
    wire [`RegAddrBus]id_idex_wd;
    wire id_idex_wreg;
    wire [`AluOpBus] idex_ex_aluop;
    wire [`AluSelBus] idex_ex_alusel;
    wire [`RegBus] idex_ex_reg1;
    wire [`RegBus] idex_ex_reg2;
    wire [`RegAddrBus]idex_ex_wd;
    wire idex_ex_wreg;

    // rd write
    wire [`RegAddrBus] ex_exmem_wd;
    wire ex_exmem_wreg;
    wire [`RegBus] ex_exmem_wdata;
    wire [`RegAddrBus] exmem_mem_wd;
    wire exmem_mem_wreg;
    wire [`RegBus] exmem_mem_wdata;    
    wire [`RegAddrBus] mem_memwb_wd;
    wire mem_memwb_wreg;
    wire [`RegBus] mem_memwb_wdata;
    
    // regfile & Data Hazard
    wire id_reg_reg1read;
    wire id_reg_reg2read;
    wire [`RegAddrBus] id_reg_reg1addr;
    wire [`RegAddrBus] id_reg_reg2addr;
    wire [`RegAddrBus] memwb_reg_wd;
    wire memwb_reg_wreg;
    wire [`RegBus] memwb_reg_wdata;
    wire [`RegBus] reg_id_rdata1;
    wire [`RegBus] reg_id_rdata2;

    // hilo_reg & ex
    wire [`RegBus] hilo_ex_hi;
    wire [`RegBus] hilo_ex_lo;

    // hilo data harzard
    wire ex_exmem_while;
    wire [`RegBus] ex_exmem_hi;
    wire [`RegBus] ex_exmem_lo;
    wire exmem_mem_while;
    wire [`RegBus] exmem_mem_hi;
    wire [`RegBus] exmem_mem_lo;
    wire mem_memwb_while;
    wire [`RegBus] mem_memwb_hi;
    wire [`RegBus] mem_memwb_lo;
    wire memwb_hilo_while;
    wire [`RegBus] memwb_hilo_hi;
    wire [`RegBus] memwb_hilo_lo;

    //chap7 : stall wire
    wire [5:0] stallcmd;
    wire stallreq_ex;
    wire stallreq_id;
    wire ex_exmem_cnt;
    wire [`DoubleRegBus] ex_exmem_hilo_temp;
    wire exmem_ex_cnt;
    wire [`DoubleRegBus] exmem_ex_hilo_temp;

    //chap7 : div module
    wire ex_div_sign_div;
    wire [`RegBus] ex_div_opdata1;
    wire [`RegBus] ex_div_opdata2;
    wire ex_div_start;
    wire [`DoubleRegBus] div_ex_result;
    wire div_ex_ready; 

    //chap8 : branch
    wire id_pc_branch_flag;
    wire [`RegBus] id_pc_branch_target_addr;
    wire [`RegBus] id_idex_link_addr;
    wire id_idex_is_in_delayslot;
    wire id_idex_next_is_in_delayslot;
    wire [`RegBus] idex_ex_link_addr;
    wire idex_ex_is_in_delayslot;
    wire idex_id_next_is_in_delayslot;

    //chap9 : load store
    wire [`InstBus] id_idex_inst;
    wire [`InstBus] idex_ex_inst;
    wire [`AluOpBus] ex_exmem_aluop;
    wire [`RegBus] ex_exmem_mem_addr;
    wire [`RegBus] ex_exmem_reg2;
    wire [`AluOpBus] exmem_mem_aluop;
    wire [`RegBus] exmem_mem_mem_addr;
    wire [`RegBus] exmem_mem_reg2;
    //chap9 : ll sc
    wire mem_memwb_we;
    wire mem_memwb_value;
    wire memwb_LLbitreg_we;
    wire memwb_LLbitreg_value;
    wire LLbitreg_mem_LLbit;


    pc_reg pc_reg0(
        .rst(rst),
        .clk(clk),
        .stall(stallcmd),   //stall command
        //branch
        .branch_target_address_i(id_pc_branch_target_addr),
        .branch_flag_i(id_pc_branch_flag),

        .pc(pc),        //output
        .ce(rom_ce_o)   //output
    );

    if_id if_id0(
        .rst(rst),
        .clk(clk),
        .if_pc(pc),
        .if_inst(rom_data_i), //input
        .stall(stallcmd),   //stall command

        .id_pc(ifid_id_pc),
        .id_inst(ifid_id_inst)
    );

    id id0(
        .rst(rst),
        .pc_i(ifid_id_pc),
        .inst_i(ifid_id_inst),
        .reg1_data_i(reg_id_rdata1),
        .reg2_data_i(reg_id_rdata2),
        //Data Harzard Bypass
        .ex_wreg_i(ex_exmem_wreg),
        .ex_wd_i(ex_exmem_wd),
        .ex_wdata_i(ex_exmem_wdata),
        .mem_wreg_i(mem_memwb_wreg),
        .mem_wd_i(mem_memwb_wd),
        .mem_wdata_i(mem_memwb_wdata),
        //branch
        .is_in_delayslot_i(idex_id_next_is_in_delayslot),

        .aluop_o(id_idex_aluop),
        .alusel_o(id_idex_alusel),
        .reg1_o(id_idex_reg1),
        .reg2_o(id_idex_reg2),
        .wd_o(id_idex_wd),
        .wreg_o(id_idex_wreg),
        .reg1_read_o(id_reg_reg1read),
        .reg2_read_o(id_reg_reg2read),
        .reg1_addr_o(id_reg_reg1addr),
        .reg2_addr_o(id_reg_reg2addr),
        .stallreq(stallreq_id),  //stall req
        //branch
        .is_in_delayslot_o(id_idex_is_in_delayslot),
        .link_addr_o(id_idex_link_addr),
        .next_inst_in_delayslot_o(id_idex_next_is_in_delayslot),
        .branch_target_address_o(id_pc_branch_target_addr),
        .branch_flag_o(id_pc_branch_flag),
        //load-store
        .inst_o(id_idex_inst)
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
        .stall(stallcmd),   //stall command
        //branch
        .id_link_address(id_idex_link_addr),
        .id_is_in_delayslot(id_idex_is_in_delayslot),
        .next_inst_in_delayslot_i(id_idex_next_is_in_delayslot),
        //chap 9 : load store
        .id_inst(id_idex_inst),

        .ex_aluop(idex_ex_aluop),
        .ex_alusel(idex_ex_alusel),
        .ex_reg1(idex_ex_reg1),
        .ex_reg2(idex_ex_reg2),
        .ex_wd(idex_ex_wd),
        .ex_wreg(idex_ex_wreg),
        //branch
        .ex_link_address(idex_ex_link_addr),
        .ex_is_in_delayslot(idex_ex_is_in_delayslot),
        .is_in_delayslot_o(idex_id_next_is_in_delayslot),
        //chap 9 : load store
        .ex_inst(idex_ex_inst)
    );

    ex ex0(
        .rst(rst),
        .aluop_i(idex_ex_aluop),
        .alusel_i(idex_ex_alusel),
        .reg1_i(idex_ex_reg1),
        .reg2_i(idex_ex_reg2),
        .wd_i(idex_ex_wd),
        .wreg_i(idex_ex_wreg),
        //hilo data hazard
        .hi_i(hilo_ex_hi),
        .lo_i(hilo_ex_lo),
        .mem_whilo_i(mem_memwb_while),
        .mem_hi_i(mem_memwb_hi),
        .mem_lo_i(mem_memwb_lo),
        .wb_whilo_i(memwb_hilo_while),
        .wb_hi_i(memwb_hilo_hi),
        .wb_lo_i(memwb_hilo_lo),
        //madd, msub stall
        .cnt_i(exmem_ex_cnt),
        .hilo_temp_i(exmem_ex_hilo_temp),
        //div
        .div_result_i(div_ex_result),
        .div_ready_i(div_ex_ready), 
        //branch
        .is_in_delayslot_o(idex_ex_is_in_delayslot),
        .link_addr_o(idex_ex_link_addr),
        //chap 9 : load store
        .inst_i(idex_ex_inst),

        .wd_o(ex_exmem_wd),
        .wreg_o(ex_exmem_wreg),
        .wdata_o(ex_exmem_wdata),
        //hilo data hazard
        .whilo_o(ex_exmem_while),
        .hi_o(ex_exmem_hi),
        .lo_o(ex_exmem_lo),
        .stallreq(stallreq_ex),  //stall req
        //madd, msub stall
        .cnt_o(ex_exmem_cnt),
        .hilo_temp_o(ex_exmem_hilo_temp),
        //div
        .sign_div_o(ex_div_sign_div),
        .div_opdata1_o(ex_div_opdata1),
        .div_opdata2_o(ex_div_opdata2),
        .div_start_o(ex_div_start),
        //chap 9 : load store
        .aluop_o(ex_exmem_aluop),
        .mem_addr_o(ex_exmem_mem_addr),
        .reg2_o(ex_exmem_reg2)
    );

    div div0(
        .rst(rst),    
        .clk(clk),
        .sign_div_i(ex_div_sign_div),
        .opdata1_i(ex_div_opdata1),
        .opdata2_i(ex_div_opdata2),
        .start_i(ex_div_start),
        .annul_i(1'b0),

        .result_o(div_ex_result),
        .ready_o(div_ex_ready) 
    );

    ex_mem ex_mem0(
        .rst(rst),
        .clk(clk),
        .ex_wd(ex_exmem_wd),
        .ex_wreg(ex_exmem_wreg),
        .ex_wdata(ex_exmem_wdata),
        .ex_whilo(ex_exmem_while),
        .ex_hi(ex_exmem_hi),
        .ex_lo(ex_exmem_lo),
        .stall(stallcmd),   //stall command
        //madd, msub stall
        .cnt_i(ex_exmem_cnt),
        .hilo_temp_i(ex_exmem_hilo_temp),
        //chap 9 : load store
        .ex_aluop(ex_exmem_aluop),
        .ex_mem_addr(ex_exmem_mem_addr),
        .ex_reg2(ex_exmem_reg2),

        .mem_wd(exmem_mem_wd),
        .mem_wreg(exmem_mem_wreg),
        .mem_wdata(exmem_mem_wdata),
        .mem_whilo(exmem_mem_while),
        .mem_hi(exmem_mem_hi),
        .mem_lo(exmem_mem_lo),
        //madd, msub stall
        .cnt_o(exmem_ex_cnt),
        .hilo_temp_o(exmem_ex_hilo_temp),
        //chap 9 : load store
        .mem_aluop(exmem_mem_aluop),
        .mem_mem_addr(exmem_mem_mem_addr),
        .mem_reg2(exmem_mem_reg2)
    );

    mem mem0(
        .rst(rst),
        .wd_i(exmem_mem_wd),
        .wreg_i(exmem_mem_wreg),
        .wdata_i(exmem_mem_wdata),
        .whilo_i(exmem_mem_while),
        .hi_i(exmem_mem_hi),
        .lo_i(exmem_mem_lo),
        //chap 9 : load store
        .aluop_i(exmem_mem_aluop),
        .mem_addr_i(exmem_mem_mem_addr),
        .reg2_i(exmem_mem_reg2),
        .mem_data_i(ram_data_i),    //input
        //chap 9 : load store LLbit
        .LLbit_i(LLbitreg_mem_LLbit),
        .wb_LLbit_we_i(memwb_LLbitreg_we),
        .wb_LLbit_value_i(memwb_LLbitreg_value),

        .wd_o(mem_memwb_wd),
        .wreg_o(mem_memwb_wreg),
        .wdata_o(mem_memwb_wdata),
        .whilo_o(mem_memwb_while),
        .hi_o(mem_memwb_hi),
        .lo_o(mem_memwb_lo),
        //chap 9 : openmips
        .mem_addr_o(ram_addr_o),
        .mem_data_o(ram_data_o),
        .mem_sel_o(ram_sel_o),
        .mem_we_o(ram_we_o),
        .mem_ce_o(ram_ce_o),
        //chap 9 : load store LLbit
        .LLbit_we_o(mem_memwb_we),
        .LLbit_value_o(mem_memwb_value)
    );

    mem_wb mem_wb0(
        .rst(rst),
        .clk(clk),
        .mem_wd(mem_memwb_wd),
        .mem_wreg(mem_memwb_wreg),
        .mem_wdata(mem_memwb_wdata),
        .mem_whilo(mem_memwb_while),
        .mem_hi(mem_memwb_hi),
        .mem_lo(mem_memwb_lo),
        .stall(stallcmd),   //stall command
        //ll sc
        .mem_LLbit_we(mem_memwb_we),
        .mem_LLbit_value(mem_memwb_value),

        .wb_wd(memwb_reg_wd),
        .wb_wreg(memwb_reg_wreg),
        .wb_wdata(memwb_reg_wdata),
        .wb_whilo(memwb_hilo_while),
        .wb_hi(memwb_hilo_hi),
        .wb_lo(memwb_hilo_lo),
        //ll sc
        .wb_LLbit_we(memwb_LLbitreg_we),
        .wb_LLbit_value(memwb_LLbitreg_value)
    );

    hilo_reg hilo_reg0(
        .rst(rst),
        .clk(clk),
        .we(memwb_hilo_while),
        .hi_i(memwb_hilo_hi),
        .lo_i(memwb_hilo_lo),

        .hi_o(hilo_ex_hi),
        .lo_o(hilo_ex_lo)
    );

    ctrl ctrl0(
        .rst(rst),
        .stallreq_ex(stallreq_ex),
        .stallreq_id(stallreq_id),

        .stall(stallcmd)
    );

    LLbit_reg LLbit_reg0(
        .rst(rst),
        .clk(clk),
        .we(memwb_LLbitreg_we),
        .LLbit_i(memwb_LLbitreg_value),
        //.flush(),

        .LLbit_o(LLbitreg_mem_LLbit)
);

endmodule
