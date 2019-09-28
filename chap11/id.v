/* id译码模块
 * 指令使用EXE_name表示，操作使用EXE_name_OP表示
 * 两者有区别，前者对应指令，后者对应ex阶段的操作
 * 比如andi和and的操作是相同的，只是操作数格式不同
 * id阶段可以解读指令操作数的值，所以经过id后andi和and再无区别 
 */
`include "defines.v"

module id(
    input wire rst,
    input wire [`InstAddrBus] pc_i,
    input wire [`InstBus] inst_i,

    //data of rs & rt, read from regfile
    input wire [`RegBus] reg1_data_i,
    input wire [`RegBus] reg2_data_i,

    //message sent to EX phase
    output reg [`AluOpBus] aluop_o, //op subtype
    output reg [`AluSelBus] alusel_o, //op type
    output reg [`RegBus] reg1_o,
    output reg [`RegBus] reg2_o,
    output reg [`RegAddrBus] wd_o, //addr of rd
    output reg wreg_o, //whether rd exist
    output reg reg1_read_o,
    output reg reg2_read_o,
    output reg [`RegAddrBus] reg1_addr_o,
    output reg [`RegAddrBus] reg2_addr_o,

    //data hazard
    input wire ex_wreg_i,
    input wire [`RegAddrBus] ex_wd_i,
    input wire [`RegBus] ex_wdata_i,
    input wire mem_wreg_i,
    input wire [`RegAddrBus] mem_wd_i,
    input wire [`RegBus] mem_wdata_i,
    input wire is_in_delayslot_i, //branch

    //chap 9 : load relate
    input wire [`AluOpBus] ex_aluop_i,

    //stall request
    output wire stallreq,

    //branch
    output reg is_in_delayslot_o,
    output reg [`RegBus] link_addr_o,
    output reg next_inst_in_delayslot_o,
    output reg [`RegBus] branch_target_address_o,
    output reg branch_flag_o,

    //load-store
    output wire [`InstBus] inst_o,

    //chap11 : exception
    output reg [31:0] excepttype_o,
    output reg [`InstAddrBus] current_inst_addr_o
);

    // phase0 : prepare
    wire [5:0] op = inst_i[31:26];
    wire [4:0] rs = inst_i[25:21];
    wire [4:0] rt = inst_i[20:16];
    wire [4:0] rd = inst_i[15:11];
    wire [4:0] sa = inst_i[10:6];
    wire [5:0] func = inst_i[5:0];
    reg [`RegBus] imm;
    reg instvalid;

    //chap9 : branch
    wire [`RegBus] pc_plus_4;
    wire [`RegBus] pc_plus_8;
    wire [`RegBus] imm_sll2_signedext;
    assign pc_plus_8 = pc_i + 8;
    assign pc_plus_4 = pc_i + 4;
    assign imm_sll2_signedext = {{14{inst_i[15]}}, inst_i[15:0], 2'b00};

    //chap9 : load-save
    assign inst_o = inst_i;

    // chap9 : load relate
    reg stallreq_for_reg1_loadrelate;
    reg stallreq_for_reg2_loadrelate;
    assign stallreq = stallreq_for_reg1_loadrelate | stallreq_for_reg2_loadrelate;
    wire pre_inst_is_load;
    assign pre_inst_is_load = ((ex_aluop_i == `EXE_LB_OP) || 
  								(ex_aluop_i == `EXE_LBU_OP) ||
  								(ex_aluop_i == `EXE_LH_OP) ||
  								(ex_aluop_i == `EXE_LHU_OP) ||
  								(ex_aluop_i == `EXE_LW_OP) ||
  								(ex_aluop_i == `EXE_LWR_OP) ||
  								(ex_aluop_i == `EXE_LWL_OP) ||
  								(ex_aluop_i == `EXE_LL_OP) ||
  								(ex_aluop_i == `EXE_SC_OP)) ? 1'b1 : 1'b0;
    always @ (*) begin
        if (rst == `RstEnable) begin
            stallreq_for_reg1_loadrelate <= `NoStop; 
        end else if (pre_inst_is_load && (ex_wd_i == reg1_addr_o) && (reg1_read_o == `ReadEnable)) begin
            stallreq_for_reg1_loadrelate <= `Stop;
        end else begin
            stallreq_for_reg1_loadrelate <= `NoStop; 
        end
    end
    always @ (*) begin
        if (rst == `RstEnable) begin
            stallreq_for_reg2_loadrelate <= `NoStop; 
        end else if (pre_inst_is_load && (ex_wd_i == reg2_addr_o) && (reg2_read_o == `ReadEnable)) begin
            stallreq_for_reg2_loadrelate <= `Stop;
        end else begin
            stallreq_for_reg2_loadrelate <= `NoStop; 
        end
    end

    //chap11 : exception
    reg excepttype_is_syscall;
    reg excepttype_is_eret;
    assign excepttype_o = {19'b0, excepttype_is_eret, 2'b0, excepttype_is_syscall, 8'b0};
    assign current_inst_addr_o = pc_i;

    // phase1 : decode the inst
    always @ (*) begin
        if (rst == `RstEnable) begin
            aluop_o <= `EXE_NOP_OP; alusel_o <= `EXE_RES_NOP;
            reg1_read_o <= `ReadDisable; reg1_addr_o <= `NOPRegAddr;
            reg2_read_o <= `ReadDisable; reg2_addr_o <= `NOPRegAddr;
            imm <= `ZeroWord;
            wreg_o <= `WriteDisable; wd_o <= `NOPRegAddr;
            link_addr_o <= `ZeroWord;
            branch_flag_o <= `NotBranch;
            branch_target_address_o <= `ZeroWord;
            next_inst_in_delayslot_o <= `NotInDelaySlot;
            instvalid <= `InstInvalid;
            excepttype_is_syscall <= `False_v;
			excepttype_is_eret <= `False_v;
        end else begin
            aluop_o <= `EXE_NOP_OP; alusel_o <= `EXE_RES_NOP;
            reg1_read_o <= `ReadDisable; reg1_addr_o <= `NOPRegAddr;
            reg2_read_o <= `ReadDisable; reg2_addr_o <= `NOPRegAddr;
            imm <= `ZeroWord;
            wreg_o <= `WriteDisable; wd_o <= `NOPRegAddr;
            link_addr_o <= `ZeroWord;
            branch_flag_o <= `NotBranch;
            branch_target_address_o <= `ZeroWord;
            next_inst_in_delayslot_o <= `NotInDelaySlot;
            instvalid <= `InstInvalid;
            excepttype_is_syscall <= `False_v;
			excepttype_is_eret <= `False_v;
            case (op)
                `EXE_SPECIAL : begin
                    case(func)
                        //logic inst
                        `EXE_AND : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_AND_OP; alusel_o <= `EXE_RES_LOGIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_OR  : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_OR_OP; alusel_o <= `EXE_RES_LOGIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_XOR : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_XOR_OP; alusel_o <= `EXE_RES_LOGIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_NOR : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_NOR_OP; alusel_o <= `EXE_RES_LOGIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        //div inst
                        `EXE_DIV : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_DIV_OP;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                        end
                        `EXE_DIVU : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_DIVU_OP;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                        end                        
                        `EXE_SYNC : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_NOP_OP; alusel_o <= `EXE_RES_NOP;
                        end
                        //shift inst
                        `EXE_SLL : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_SLL_OP; alusel_o <= `EXE_RES_SHIFT;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            imm[4:0] <= sa;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_SRL  : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_SRL_OP; alusel_o <= `EXE_RES_SHIFT;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            imm[4:0] <= sa; //logic
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_SRA  : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_SRA_OP; alusel_o <= `EXE_RES_SHIFT;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            imm[4:0] <= sa; //arithmetic
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_SLLV : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_SLL_OP; alusel_o <= `EXE_RES_SHIFT;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_SRLV : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_SRL_OP; alusel_o <= `EXE_RES_SHIFT;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_SRAV : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_SRA_OP; alusel_o <= `EXE_RES_SHIFT;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        //move inst
                        `EXE_MOVZ : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_MOVZ_OP; alusel_o <= `EXE_RES_MOVE;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            if (reg2_o == `ZeroWord) begin
                                wreg_o <= `WriteEnable; wd_o <= rd;
                            end
                        end
                        `EXE_MOVN : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_MOVN_OP; alusel_o <= `EXE_RES_MOVE;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            if (reg2_o != `ZeroWord) begin
                                wreg_o <= `WriteEnable; wd_o <= rd;
                            end
                        end
                        `EXE_MFHI : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_MFHI_OP; alusel_o <= `EXE_RES_MOVE;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_MFLO : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_MFLO_OP; alusel_o <= `EXE_RES_MOVE;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_MTHI : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_MTHI_OP; alusel_o <= `EXE_RES_MOVE;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                        end
                        `EXE_MTLO : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_MTLO_OP; alusel_o <= `EXE_RES_MOVE;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                        end
                        //arithmetic inst
                        `EXE_ADD  : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_ADD_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_ADDU : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_ADDU_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_SUB  : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_SUB_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_SUBU : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_SUBU_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_SLT  : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_SLT_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_SLTU : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_SLTU_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        //mul inst
                        `EXE_MULT : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_MULT_OP; alusel_o <= `EXE_RES_MUL;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                        end
                        `EXE_MULTU: begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_MULTU_OP; alusel_o <= `EXE_RES_MUL;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                        end
                        // branch inst
                        `EXE_JR : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_JR_OP; alusel_o <= `EXE_RES_JUMP_BRANCH;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            branch_flag_o <= `Branch;
                            branch_target_address_o <= reg1_o;
                            next_inst_in_delayslot_o <= `InDelaySlot;
                        end
                        `EXE_JALR : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_JALR_OP; alusel_o <= `EXE_RES_JUMP_BRANCH;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                            link_addr_o <= pc_plus_8;
                            branch_flag_o <= `Branch;
                            branch_target_address_o <= reg1_o;
                            next_inst_in_delayslot_o <= `InDelaySlot;
                        end
                        // chap11 : trap
                        `EXE_TEQ: begin
                            instvalid <= `InstValid;
					    	aluop_o <= `EXE_TEQ_OP; alusel_o <= `EXE_RES_NOP;
		  			    end
		  			    `EXE_TGE: begin
                            instvalid <= `InstValid;
					    	aluop_o <= `EXE_TGE_OP; alusel_o <= `EXE_RES_NOP;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
		  			    end		
		  			    `EXE_TGEU: begin
                            instvalid <= `InstValid;
					    	aluop_o <= `EXE_TGEU_OP; alusel_o <= `EXE_RES_NOP;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;	
		  			    end	
		  			    `EXE_TLT: begin
                            instvalid <= `InstValid;
					    	aluop_o <= `EXE_TLT_OP; alusel_o <= `EXE_RES_NOP;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;	
		  			    end
		  			    `EXE_TLTU: begin
					    	aluop_o <= `EXE_TLTU_OP; alusel_o <= `EXE_RES_NOP;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
		  			    end	
		  			    `EXE_TNE: begin
                            instvalid <= `InstValid;
					    	aluop_o <= `EXE_TNE_OP; alusel_o <= `EXE_RES_NOP;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;	
		  			    end
		  			    `EXE_SYSCALL: begin
                            instvalid <= `InstValid;
					    	aluop_o <= `EXE_SYSCALL_OP; alusel_o <= `EXE_RES_NOP;
		  			    	excepttype_is_syscall<= `True_v;
                        default : begin
                        end
                    endcase
                end
                `EXE_REGIMM : begin
                    case(rt)
                        `EXE_BLTZ : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_BGEZAL_OP; alusel_o <= `EXE_RES_JUMP_BRANCH; 
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
		  				    if (reg1_o[31] == 1'b1) begin
                                branch_flag_o <= `Branch;
			    			    branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
			    			    next_inst_in_delayslot_o <= `InDelaySlot;		  	
			   			    end
                        end
                        `EXE_BLTZAL : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_BGEZAL_OP; alusel_o <= `EXE_RES_JUMP_BRANCH;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
		  				    wreg_o <= `WriteEnable; wd_o <= 5'b11111;
                            link_addr_o <= pc_plus_8;	
		  				    if (reg1_o[31] == 1'b1) begin
			    			    branch_flag_o <= `Branch;
			    			    branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
			    			    next_inst_in_delayslot_o <= `InDelaySlot;
			   			    end
                        end
                        `EXE_BGEZ : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_BGEZ_OP; alusel_o <= `EXE_RES_JUMP_BRANCH;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
		  				    if (reg1_o[31] == 1'b0) begin
			    			    branch_flag_o <= `Branch;
			    			    branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
			    			    next_inst_in_delayslot_o <= `InDelaySlot;		  	
			   			    end
                        end
                        `EXE_BGEZAL : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_BGEZAL_OP; alusel_o <= `EXE_RES_JUMP_BRANCH;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
		  				    link_addr_o <= pc_plus_8; 
		  				    wreg_o <= `WriteEnable;	wd_o <= 5'b11111;  	
		  				    if (reg1_o[31] == 1'b0) begin
			    			    branch_flag_o <= `Branch;
			    			    branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
			    			    next_inst_in_delayslot_o <= `InDelaySlot;
			   			    end
                        end
                        // chap11 : trap
                        `EXE_TEQI:			begin
                            instvalid <= `InstValid;
		  				    aluop_o <= `EXE_TEQI_OP; alusel_o <= `EXE_RES_NOP;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;  	
							imm <= {{16{inst_i[15]}}, inst_i[15:0]};		  	
						end
						`EXE_TGEI:			begin
                            instvalid <= `InstValid;
		  					aluop_o <= `EXE_TGEI_OP; alusel_o <= `EXE_RES_NOP; 
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
							imm <= {{16{inst_i[15]}}, inst_i[15:0]};		  		
						end
						`EXE_TGEIU:			begin
                            instvalid <= `InstValid;
		  					aluop_o <= `EXE_TGEIU_OP; alusel_o <= `EXE_RES_NOP; 
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;  	
							imm <= {{16{inst_i[15]}}, inst_i[15:0]};		  		
						end
						`EXE_TLTI:			begin
                            instvalid <= `InstValid;
		  					aluop_o <= `EXE_TLTI_OP; alusel_o <= `EXE_RES_NOP; 
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
							imm <= {{16{inst_i[15]}}, inst_i[15:0]};		  		
						end
						`EXE_TLTIU:			begin
                            instvalid <= `InstValid;
		  					aluop_o <= `EXE_TLTIU_OP; alusel_o <= `EXE_RES_NOP; 
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
							imm <= {{16{inst_i[15]}}, inst_i[15:0]};		  	
						end
						`EXE_TNEI:			begin
                            instvalid <= `InstValid;
		  					aluop_o <= `EXE_TNEI_OP; alusel_o <= `EXE_RES_NOP; 
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
							imm <= {{16{inst_i[15]}}, inst_i[15:0]};		  	
						end						
                        default : begin
                        end
                    endcase
                end
                `EXE_SPECIAL2 : begin
                    case(func)
                        `EXE_CLZ   : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_CLZ_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_CLO   : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_CLO_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_MUL : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_MUL_OP; alusel_o <= `EXE_RES_MUL;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                            wreg_o <= `WriteEnable; wd_o <= rd;
                        end
                        `EXE_MADD  : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_MADD_OP; alusel_o <= `EXE_RES_MUL;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                        end
                        `EXE_MADDU : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_MADDU_OP; alusel_o <= `EXE_RES_MUL;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                        end
                        `EXE_MSUB  : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_MSUB_OP; alusel_o <= `EXE_RES_MUL;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                        end
                        `EXE_MSUBU : begin
                            instvalid <= `InstValid;
                            aluop_o <= `EXE_MSUBU_OP; alusel_o <= `EXE_RES_MUL;
                            reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                            reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                        end
                        default : begin
                        end
                    endcase
                end
                //logic inst
                `EXE_ANDI : begin
                    instvalid <= `InstValid;
                    aluop_o <= `EXE_AND_OP; alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    imm <= {16'b0, inst_i[15:0]};
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                `EXE_ORI : begin
                    instvalid <= `InstValid;
                    aluop_o <= `EXE_OR_OP; alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    imm <= {16'b0, inst_i[15:0]}; //should be `RegWidth - 16
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                `EXE_XORI : begin
                    instvalid <= `InstValid;
                    aluop_o <= `EXE_XOR_OP; alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    imm <= {16'b0, inst_i[15:0]};
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                `EXE_LUI : begin
                    instvalid <= `InstValid;
                    aluop_o <= `EXE_OR_OP; alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    imm <= {inst_i[15:0], 16'b0};
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                `EXE_PREF : begin
                    instvalid <= `InstValid;
                    aluop_o <= `EXE_NOP_OP; alusel_o <= `EXE_RES_NOP;
                end
                //arithmetic inst
                `EXE_ADDI  : begin
                    instvalid <= `InstValid;
                    aluop_o <= `EXE_ADDI_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    imm <= {16'b0, inst_i[15:0]};
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                `EXE_ADDIU : begin
                    instvalid <= `InstValid;
                    aluop_o <= `EXE_ADDIU_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    imm <= {{16{inst_i[15]}}, inst_i[15:0]};
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                `EXE_SLTI  : begin
                    instvalid <= `InstValid;
                    aluop_o <= `EXE_SLT_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    imm <= {16'b0, inst_i[15:0]};
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                `EXE_SLTIU : begin
                    instvalid <= `InstValid;
                    aluop_o <= `EXE_SLTU_OP; alusel_o <= `EXE_RES_ARITHMETIC;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    imm <= {{16{inst_i[15]}}, inst_i[15:0]};
                    wreg_o <= `WriteEnable; wd_o <= rt;
                end
                //branch inst
                `EXE_J : begin
                    instvalid <= `InstValid;
                    aluop_o <= `EXE_J_OP; alusel_o <= `EXE_RES_JUMP_BRANCH;
                    branch_flag_o <= `Branch;
                    branch_target_address_o <= {pc_plus_4[31:28], inst_i[25:0], 2'b00};
                    next_inst_in_delayslot_o <= `InDelaySlot;
                end                
                `EXE_JAL : begin
                    instvalid <= `InstValid;
                    aluop_o <= `EXE_JAL_OP; alusel_o <= `EXE_RES_JUMP_BRANCH;
                    wreg_o <= `WriteEnable; wd_o <= 5'b11111;
                    link_addr_o <= pc_plus_8;
                    branch_flag_o <= `Branch;
                    branch_target_address_o <= {pc_plus_4[31:28], inst_i[25:0], 2'b00};
                    next_inst_in_delayslot_o <= `InDelaySlot;
                end
                `EXE_BEQ : begin
                    instvalid <= `InstValid;
                    aluop_o <= `EXE_BEQ_OP; alusel_o <= `EXE_RES_JUMP_BRANCH;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
		  		    if (reg1_o == reg2_o) begin
			    	    branch_flag_o <= `Branch;
			    	    branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
			    	    next_inst_in_delayslot_o <= `InDelaySlot;		  	
			        end
                end
                `EXE_BGTZ : begin
                    instvalid <= `InstValid;
                    aluop_o <= `EXE_BGTZ_OP; alusel_o <= `EXE_RES_JUMP_BRANCH;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
		  		    if ((reg1_o[31] == 1'b0) && (reg1_o != `ZeroWord)) begin
                        branch_flag_o <= `Branch;
			    	    branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
			    	    next_inst_in_delayslot_o <= `InDelaySlot;		  	
			        end
                end
                `EXE_BLEZ : begin
                    instvalid <= `InstValid;
                    aluop_o <= `EXE_BLEZ_OP; alusel_o <= `EXE_RES_JUMP_BRANCH;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
		  		    if ((reg1_o[31] == 1'b1) || (reg1_o == `ZeroWord)) begin
                        branch_flag_o <= `Branch;
			    	    branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
			    	    next_inst_in_delayslot_o <= `InDelaySlot;		  	
			        end
                end
                `EXE_BNE : begin
                    instvalid <= `InstValid;
                    aluop_o <= `EXE_BLEZ_OP; alusel_o <= `EXE_RES_JUMP_BRANCH;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
		  		    if (reg1_o != reg2_o) begin
                        branch_flag_o <= `Branch;
			    	    branch_target_address_o <= pc_plus_4 + imm_sll2_signedext;
			    	    next_inst_in_delayslot_o <= `InDelaySlot;		  	
			        end
                end
                //load-store inst
                `EXE_LB : begin
                    instvalid <= `InstValid;
		  			aluop_o <= `EXE_LB_OP; alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
					wreg_o <= `WriteEnable;	wd_o <= rt;
				end
				`EXE_LBU : begin
                    instvalid <= `InstValid;
		  		    aluop_o <= `EXE_LBU_OP; alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
					wreg_o <= `WriteEnable;	wd_o <= rt;
				end
				`EXE_LH : begin
                    instvalid <= `InstValid;
		  		    aluop_o <= `EXE_LH_OP; alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
					wreg_o <= `WriteEnable;	wd_o <= rt;
				end
				`EXE_LHU : begin
                    instvalid <= `InstValid;
		  		    aluop_o <= `EXE_LHU_OP; alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
					wreg_o <= `WriteEnable;	wd_o <= rt;
				end
				`EXE_LW : begin
                    instvalid <= `InstValid;
		  		    aluop_o <= `EXE_LW_OP; alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
					wreg_o <= `WriteEnable;	wd_o <= rt;
				end
				`EXE_LWL : begin
                    instvalid <= `InstValid;
		  		    aluop_o <= `EXE_LWL_OP; alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
					wreg_o <= `WriteEnable;	wd_o <= rt;
				end
				`EXE_LWR : begin
                    instvalid <= `InstValid;
		  		    aluop_o <= `EXE_LWR_OP; alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
					wreg_o <= `WriteEnable;	wd_o <= rt;
				end
				`EXE_SB : begin
                    instvalid <= `InstValid;
		  		    aluop_o <= `EXE_SB_OP; alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
				end
				`EXE_SH : begin
                    instvalid <= `InstValid;
		  		   aluop_o <= `EXE_SH_OP; alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
				end
				`EXE_SW : begin
                    instvalid <= `InstValid;
		  		    aluop_o <= `EXE_SW_OP; alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
				end
				`EXE_SWL : begin
                    instvalid <= `InstValid;
		  		    aluop_o <= `EXE_SWL_OP; alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
				end
				`EXE_SWR : begin
                    instvalid <= `InstValid;
		  		    aluop_o <= `EXE_SWR_OP; alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
                    reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
				end
                `EXE_LL : begin
                    instvalid <= `InstValid;
		  		    aluop_o <= `EXE_LL_OP; alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
					wreg_o <= `WriteEnable;	wd_o <= rt;
				end
                `EXE_SC : begin
                    instvalid <= `InstValid;
		  		    aluop_o <= `EXE_SC_OP; alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= `ReadEnable; reg1_addr_o <= rs;
					reg2_read_o <= `ReadEnable; reg2_addr_o <= rt;
                    wreg_o <= `WriteEnable;	wd_o <= rt;
				end
                default : begin
                end
            endcase
            //chap10 : mtc0, mfc0
            //chap11 : eret
            if(inst_i == `EXE_ERET) begin
                instvalid <= `InstValid;
				aluop_o <= `EXE_ERET_OP; alusel_o <= `EXE_RES_NOP; 
		        excepttype_is_eret<= `True_v;
            end else if ((inst_i[31:21] == 11'b01000000000) && (inst_i[10:0] == 11'b00000000000)) begin
                instvalid <= `InstValid;
                aluop_o <= `EXE_MFC0_OP; alusel_o <= `EXE_RES_MOVE;
                wreg_o <= `WriteEnable;	wd_o <= rt;
            end else if ((inst_i[31:21] == 11'b01000000100) && (inst_i[10:0] == 11'b00000000000)) begin
                instvalid <= `InstValid;
                aluop_o <= `EXE_MTC0_OP; alusel_o <= `EXE_RES_NOP;
                reg1_read_o <= `ReadEnable; reg1_addr_o <= rt;
            end
        end
    end

    // phase2.1 : get data of rs
    always @ (*) begin
        if (rst == `RstEnable) begin
            reg1_o <= `ZeroWord;
        end else if ((reg1_read_o == `ReadEnable) && (reg1_addr_o == ex_wd_i) && (ex_wreg_i == `WriteEnable)) begin
            reg1_o <= ex_wdata_i; //bypass for Data Harzard
        end else if ((reg1_read_o == `ReadEnable) && (reg1_addr_o == mem_wd_i) && (mem_wreg_i == `WriteEnable)) begin
            reg1_o <= mem_wdata_i; //bypass for Data Harzard
        end else if (reg1_read_o == `ReadEnable) begin
            reg1_o <= reg1_data_i;
        end else if (reg1_read_o == `ReadDisable) begin
            reg1_o <= imm;
        end else begin
            reg1_o <= `ZeroWord;
        end
    end 

    // phase2.2 : get data of rt
    always @ (*) begin
        if (rst == `RstEnable) begin
            reg2_o <= `ZeroWord;
        end else if ((reg2_read_o == `ReadEnable) && (reg2_addr_o == ex_wd_i) && (ex_wreg_i == `WriteEnable)) begin
            reg2_o <= ex_wdata_i;
        end else if ((reg2_read_o == `ReadEnable) && (reg2_addr_o == mem_wd_i) && (mem_wreg_i == `WriteEnable)) begin
            reg2_o <= mem_wdata_i;
        end else if (reg2_read_o == `ReadEnable) begin
            reg2_o <= reg2_data_i;
        end else if (reg2_read_o == `ReadDisable) begin
            reg2_o <= imm;
        end else begin
            reg2_o <= `ZeroWord;
        end
    end 

    // phase3 : delayslot inst
    always @ (*) begin
        if (rst == `RstEnable) begin
            is_in_delayslot_o <= `NotInDelaySlot;
        end else begin
            is_in_delayslot_o <= is_in_delayslot_i;
        end
    end


endmodule

