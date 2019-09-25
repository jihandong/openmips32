`include "defines.v"

module ex(
    input wire rst,
    input wire [`AluSelBus] alusel_i,
    input wire [`AluOpBus] aluop_i,
    input wire [`RegBus] reg1_i,
    input wire [`RegBus] reg2_i,
    input wire [`RegAddrBus] wd_i,
    input wire wreg_i,
    //hilo reg
    input wire [`RegBus] hi_i,
    input wire [`RegBus] lo_i,
    input wire wb_whilo_i,
    input wire [`RegBus] wb_hi_i,
    input wire [`RegBus] wb_lo_i,
    input wire mem_whilo_i,
    input wire [`RegBus] mem_hi_i,
    input wire [`RegBus] mem_lo_i,
    //for madd & msub
    input wire cnt_i,
    input wire [`DoubleRegBus] hilo_temp_i,
    //div
    input wire [`DoubleRegBus] div_result_i,
    input wire div_ready_i, 
    //branch
    input wire is_in_delayslot_o,
    input wire [`RegBus] link_addr_o,

    output reg [`RegAddrBus] wd_o,  //written reg addr
    output reg wreg_o,
    output reg [`RegBus] wdata_o,   //written reg data
    //hilo reg
    output reg whilo_o,
    output reg [`RegBus] hi_o,
    output reg [`RegBus] lo_o, 
    //stall request
    output reg stallreq,
    //for madd & msub
    output reg cnt_o,
    output reg [`DoubleRegBus] hilo_temp_o,
    //div
    output reg sign_div_o,
    output reg [`RegBus] div_opdata1_o,
    output reg [`RegBus] div_opdata2_o,
    output reg div_start_o
);

    reg [`RegBus] logic_res;
    reg [`RegBus] shift_res;
    reg [`RegBus] move_res;
    reg [`RegBus] arithmetic_res;
    reg [`DoubleRegBus] mul_res;
    reg [`RegBus] HI;
    reg [`RegBus] LO;

    // phase 1 : fresh HI and LO
    always @ (*) begin
        if (rst == `RstEnable) begin
            {HI, LO} <= {`ZeroWord, `ZeroWord};
        end else if (mem_whilo_i == `WriteEnable) begin
            {HI, LO} <= {mem_hi_i, mem_lo_i};
        end else if (wb_whilo_i == `WriteEnable) begin
            {HI, LO} <= {wb_hi_i, wb_lo_i};
        end else begin
            {HI, LO} <= {hi_i, lo_i};
        end
    end

    // phase 2.1 : logic (according to aluop_i)
    always @ (*) begin
        if (rst == `RstEnable) begin
            logic_res <= `ZeroWord;
        end else begin
            case (aluop_i)
                `EXE_AND_OP : begin
                    logic_res <= reg1_i & reg2_i;
                end
                `EXE_OR_OP  : begin
                    logic_res <= reg1_i | reg2_i;
                end
                `EXE_XOR_OP : begin
                    logic_res <= reg1_i ^ reg2_i;
                end
                `EXE_NOR_OP : begin
                    logic_res <= ~(reg1_i | reg2_i);
                end
                default : begin
                    logic_res <= `ZeroWord;
                end
            endcase
        end
    end

    // phase 2.2 : shift
    always @ (*) begin
        if (rst == `RstEnable) begin
            shift_res <= `ZeroWord;
        end else begin
            case (aluop_i)
                `EXE_SLL_OP : begin
                    shift_res <= reg2_i << reg1_i[4:0];
                end
                `EXE_SRL_OP : begin
                    shift_res <= reg2_i >> reg1_i[4:0];
                end
                `EXE_SRA_OP : begin
                    shift_res <= ($signed(reg2_i)) >>> reg1_i[4:0];
                end
                default : begin
                    shift_res <= `ZeroWord;
                end
            endcase
        end
    end

    // phase 2.3 : move
    always @ (*) begin
        if (rst == `RstEnable) begin
            move_res <= `ZeroWord;
        end else begin
            case (aluop_i)
                `EXE_MOVZ_OP, `EXE_MOVN_OP: begin
                    move_res <= reg1_i;
                end
                `EXE_MFHI_OP : begin
                    move_res <= HI;
                end
                `EXE_MFLO_OP : begin
                    move_res <= LO;
                end
                default : begin
                    move_res <= `ZeroWord;
                end               
            endcase
        end
    end

    /* phase 2.4 : arithmetic alu
    * 算术指令可以先利用wire线路计算结果，再输入寄存器储存
    * assign部分相当于alu
    */
    wire [`RegBus] reg2_com;
    wire [`RegBus] result;
    wire reg1_lt_reg2;
    wire overflow_flag;

    assign reg2_com = ( (aluop_i == `EXE_SUB_OP) || (aluop_i == `EXE_SUBU_OP) || (aluop_i == `EXE_SLT_OP) )?
                        (~reg2_i)+1 : reg2_i;
    assign result = reg1_i + reg2_com;
    assign overflow_flag = ( (reg1_i[31] && reg2_com[31] && !result[31]) ||
                            (!reg1_i[31] && !reg2_com[31] && result[31]) );
    assign reg1_lt_reg2 = (aluop_i == `EXE_SLT_OP) ? (overflow_flag ? !result[31] : result[31]) : (reg1_i < reg2_i);

    always @ (*) begin
        if (rst == `RstEnable) begin
            arithmetic_res <= `ZeroWord;
        end else begin
            case(aluop_i)
                `EXE_ADD_OP, `EXE_ADDU_OP, `EXE_ADDI_OP, `EXE_ADDIU_OP : begin
                    arithmetic_res <= result;
                end
                `EXE_SUB_OP, `EXE_SUBU_OP : begin
                    arithmetic_res <= result;
                end
                `EXE_SLT_OP, `EXE_SLTU_OP : begin
                    arithmetic_res <= reg1_lt_reg2;
                end
                `EXE_CLZ_OP : begin
                    arithmetic_res <= (reg1_i[31] ? 0 : reg1_i[30] ? 1 : reg1_i[29] ? 2 : reg1_i[28] ? 3 :
                                    reg1_i[27] ? 4  : reg1_i[26] ? 5  : reg1_i[25] ? 6  : reg1_i[24] ? 7 :
                                    reg1_i[23] ? 8  : reg1_i[22] ? 9  : reg1_i[21] ? 10 : reg1_i[20] ? 11 :
                                    reg1_i[19] ? 12 : reg1_i[18] ? 13 : reg1_i[17] ? 14 : reg1_i[16] ? 15 :
                                    reg1_i[15] ? 16 : reg1_i[14] ? 17 : reg1_i[13] ? 18 : reg1_i[12] ? 19 :
                                    reg1_i[11] ? 20 : reg1_i[10] ? 21 : reg1_i[9] ? 22  : reg1_i[8] ? 23  :
                                    reg1_i[7] ? 24  : reg1_i[6] ? 25  : reg1_i[5] ? 26  : reg1_i[4] ? 27  :
                                    reg1_i[3] ? 28  : reg1_i[2] ? 29  : reg1_i[1] ? 30  : reg1_i[0] ? 31  : 32);
                end
                `EXE_CLO_OP : begin
                    arithmetic_res <= (!reg1_i[31] ? 0 : !reg1_i[30] ? 1 : !reg1_i[29] ? 2 : !reg1_i[28] ? 3 :
                                    !reg1_i[27] ? 4  : !reg1_i[26] ? 5  : !reg1_i[25] ? 6  : !reg1_i[24] ? 7 :
                                    !reg1_i[23] ? 8  : !reg1_i[22] ? 9  : !reg1_i[21] ? 10 : !reg1_i[20] ? 11 :
                                    !reg1_i[19] ? 12 : !reg1_i[18] ? 13 : !reg1_i[17] ? 14 : !reg1_i[16] ? 15 :
                                    !reg1_i[15] ? 16 : !reg1_i[14] ? 17 : !reg1_i[13] ? 18 : !reg1_i[12] ? 19 :
                                    !reg1_i[11] ? 20 : !reg1_i[10] ? 21 : !reg1_i[9] ? 22  : !reg1_i[8] ? 23  :
                                    !reg1_i[7] ? 24  : !reg1_i[6] ? 25  : !reg1_i[5] ? 26  : !reg1_i[4] ? 27  :
                                    !reg1_i[3] ? 28  : !reg1_i[2] ? 29  : !reg1_i[1] ? 30  : !reg1_i[0] ? 31  : 32);
                end
                default : begin
                    arithmetic_res <= `ZeroWord;
                end
            endcase
        end
    end

    // phase 2.5 : mul
    // 乘法单独处理，进行补码乘法，对于符号乘法且一正一负的情况，需要对结果取补
    wire [`RegBus] reg1_mul;
    wire [`RegBus] reg2_mul;
    wire [`DoubleRegBus] hilo_temp;

    assign reg1_mul = (((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP) ||
                        (aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MSUB_OP)) && reg1_i[31]) ?
                        (~reg1_i)+1 : reg1_i;
    assign reg2_mul = (((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP) ||
                        (aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MSUB_OP)) && reg2_i[31]) ?
                        (~reg2_i)+1 : reg2_i;
    assign hilo_temp = reg1_mul * reg2_mul;

    always @ (*) begin
        if (rst == `RstEnable) begin
            mul_res <= {`ZeroWord, `ZeroWord};
        end else if ((aluop_i == `EXE_MUL_OP) || (aluop_i == `EXE_MULT_OP) ||
                    (aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MSUB_OP)) begin
            if (reg1_i[31] ^ reg2_i[31] == 1'b1) begin
                mul_res <= (~hilo_temp)+1;
            end else  begin
                mul_res <= hilo_temp;
            end
        end else if ((aluop_i == `EXE_MULTU_OP) || (aluop_i == `EXE_MADDU_OP) || (aluop_i == `EXE_MSUBU_OP)) begin
            mul_res <= hilo_temp;
        end else begin
            mul_res <= {`ZeroWord, `ZeroWord};
        end
    end

    // phase 2.6 : madd and msub
    reg [`DoubleRegBus] hilo_temp_m;
    reg stall_for_madd_msub;

    always @ (*) begin
        if (rst == `RstEnable) begin
            cnt_o <= 2'b00;
            hilo_temp_o <= {`ZeroWord, `ZeroWord};
            stall_for_madd_msub <= `NoStop;
        end else if ((aluop_i == `EXE_MADD_OP) || (aluop_i == `EXE_MADDU_OP)) begin
            if (cnt_i == 2'b00) begin
                cnt_o <= 2'b01;
                hilo_temp_o <= mul_res;
                hilo_temp_m <= {`ZeroWord, `ZeroWord};
                stall_for_madd_msub <= `Stop;
            end else if (cnt_i == 2'b01) begin
                cnt_o <= 2'b10;
                hilo_temp_o <= {`ZeroWord, `ZeroWord};
                hilo_temp_m <= {HI, LO} + hilo_temp_i;
                stall_for_madd_msub <= `NoStop;
            end
        end else if ((aluop_i == `EXE_MSUB_OP) || (aluop_i == `EXE_MSUBU_OP)) begin
            if (cnt_i == 2'b00) begin
                cnt_o <= 2'b01;
                hilo_temp_o <= ~mul_res + 1;
                hilo_temp_m <= {`ZeroWord, `ZeroWord};
                stall_for_madd_msub <= `Stop;
            end else if (cnt_i == 2'b01) begin
                cnt_o <= 2'b10;
                hilo_temp_o <= {`ZeroWord, `ZeroWord};
                hilo_temp_m <= {HI, LO} + hilo_temp_i;
                stall_for_madd_msub <= `NoStop;
            end
        end else begin
            cnt_o <= 2'b00; //back to 00 state
            hilo_temp_o <= {`ZeroWord, `ZeroWord};
            stall_for_madd_msub <= `NoStop;
        end
    end

    // phase 2.7 : div
    reg stall_for_div;

    always @ (*) begin
        if (rst == `RstEnable) begin
            sign_div_o <= 1'b0;
            div_opdata1_o <= `ZeroWord;
            div_opdata2_o <= `ZeroWord;
            div_start_o <= `DivStop;
            stall_for_div <= `NoStop;
        end else if (aluop_i == `EXE_DIV_OP) begin
            if (div_ready_i == `DivResultNotReady) begin
                sign_div_o <= 1'b1;
                div_opdata1_o <= reg1_i;
                div_opdata2_o <= reg2_i;
                div_start_o <= `DivStart;
                stall_for_div <= `Stop;
            end else if (div_ready_i == `DivResultReady) begin
                sign_div_o <= 1'b1;
                div_opdata1_o <= reg1_i;
                div_opdata2_o <= reg2_i;
                div_start_o <= `DivStop;
                stall_for_div <= `NoStop;
            end else begin
                sign_div_o <= 1'b1;
                div_opdata1_o <= `ZeroWord;
                div_opdata2_o <= `ZeroWord;
                div_start_o <= `DivStop;
                stall_for_div <= `NoStop;
            end
        end else if (aluop_i == `EXE_DIVU_OP) begin
            if (div_ready_i == `DivResultNotReady) begin
                sign_div_o <= 1'b0;
                div_opdata1_o <= reg1_i;
                div_opdata2_o <= reg2_i;
                div_start_o <= `DivStart;
                stall_for_div <= `Stop;
            end else if (div_ready_i == `DivResultReady) begin
                sign_div_o <= 1'b0;
                div_opdata1_o <= reg1_i;
                div_opdata2_o <= reg2_i;
                div_start_o <= `DivStop;
                stall_for_div <= `NoStop;
            end else begin
                sign_div_o <= 1'b0;
                div_opdata1_o <= `ZeroWord;
                div_opdata2_o <= `ZeroWord;
                div_start_o <= `DivStop;
                stall_for_div <= `NoStop;
            end
        end else begin
            sign_div_o <= 1'b0;
            div_opdata1_o <= `ZeroWord;
            div_opdata2_o <= `ZeroWord;
            div_start_o <= `DivStop;
            stall_for_div <= `NoStop;
        end
    end

    // phase 3 : choose a result (according to alusel_i)
    always @ (*) begin
        wd_o <= wd_i;
        if (((aluop_i == `EXE_ADD_OP) || (aluop_i == `EXE_SUB_OP) || (aluop_i == `EXE_ADDI_OP)) && overflow_flag) begin
            wreg_o <= `WriteDisable;
        end else begin
            wreg_o <= wreg_i;
        end
        case (alusel_i)
            `EXE_RES_LOGIC : begin
                wdata_o <= logic_res;
            end
            `EXE_RES_SHIFT : begin
                wdata_o <= shift_res;
            end
            `EXE_RES_MOVE : begin
                wdata_o <= move_res; 
            end
            `EXE_RES_ARITHMETIC : begin
                wdata_o <= arithmetic_res;
            end
            `EXE_RES_MUL : begin
                wdata_o <= hilo_temp[31:0];
            end
            `EXE_RES_JUMP_BRANCH : begin
                wdata_o <= link_addr_o;
            end
            default : begin
                wdata_o <= `ZeroWord;
            end
        endcase
    end

    // phase 4 : stall pipline
    always @ (*) begin
        stallreq <= stall_for_madd_msub || stall_for_div;
    end

    // phase 5 : write into hilo
    always @ (*) begin
        if (rst == `RstEnable) begin
            whilo_o <= `WriteDisable;
            {hi_o, lo_o} <= {`ZeroWord, `ZeroWord};
        end else begin
            case(aluop_i)
                `EXE_MTHI_OP : begin
                    whilo_o <= `WriteEnable;
                    {hi_o, lo_o} <= {reg1_i, LO};
                end           
                `EXE_MTLO_OP : begin
                    whilo_o <= `WriteEnable;
                    {hi_o, lo_o} <= {HI, reg1_i};
                end
                `EXE_MULT_OP, `EXE_MULTU_OP : begin
                    whilo_o <= `WriteEnable;
                    {hi_o, lo_o} <= mul_res;
                end
                `EXE_MADD_OP, `EXE_MADDU_OP : begin
                    whilo_o <= `WriteEnable;
                    {hi_o, lo_o} <= hilo_temp_m;
                end
                `EXE_MSUB_OP, `EXE_MSUBU_OP : begin
                    whilo_o <= `WriteEnable;
                    {hi_o, lo_o} <= hilo_temp_m;
                end
                `EXE_DIV_OP, `EXE_DIVU_OP : begin
                    whilo_o <= `WriteEnable;
                    {hi_o, lo_o} <= div_result_i;
                end
                default : begin
                    whilo_o <= `WriteDisable;
                    {hi_o, lo_o} <= {`ZeroWord, `ZeroWord};
                end
            endcase
        end
    end 
endmodule
