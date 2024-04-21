module Pipelined(clk1,clk2);
	input clk1,clk2;				 // Two-phase clock
	reg[31:0]  PC,IF_ID_IR,IF_ID_NPC;
	reg[31:0]  ID_RR_IR,ID_RR_NPC,RR_EX_A,RR_EX_B,RR_EX_Imm,RR_EX_NPC,RR_EX_IR;
	reg[2:0]   ID_RR_type,EX_MEM_type,MEM_WB_type,RR_EX_type;
	reg[31:0]  EX_MEM_IR,EX_MEM_ALUOut,EX_MEM_B;
	reg 	   EX_MEM_cond;                             
	reg[31:0]  MEM_WB_IR,MEM_WB_ALUOut,MEM_WB_LMD;
	reg[31:0]  Reg[0:31];				// Register bank(32x32)
	reg[31:0]  Mem[0:1023];				// 1024x32 memory
	wire[31:0] RR_EX_A_OF, RR_EX_B_OF;
	wire bypassAfromMEM, bypassBfromMEM, bypassAfromWB, bypassBfromWB;
	
	reg HALTED;		    // Set after HLT instruction is completed(in WB stage)
	wire TAKEN_BRANCH;	// Required to disable instructions after branch
	
	parameter	ADD=6'b000000,SUB=6'b000001,AND=6'b000010,OR=6'b000011,SLT=6'b000100,MUL=6'b000101,
				HLT=6'b111111,LW=6'b001000,SW=6'b001001,ADDI=6'b001010,SUBI=6'b001011,SLTI=6'b001100,
				BNEQ=6'b001101,BEQ=6'b001110;
    
	parameter   RR_ALU=3'b000,RM_ALU=3'b001,LOAD=3'b010,STORE=3'b011,BRANCH=3'b100,HALT=3'b101;
	/////////////////////////////////Operend_Forwarding/////////////////////////////////////////////
	assign bypassAfromMEM = (RR_EX_IR[20:16] == EX_MEM_IR[25:21]) & (EX_MEM_IR[25:21] != 0);
	assign bypassBfromMEM = (RR_EX_IR[15:11] == EX_MEM_IR[25:21]) & (EX_MEM_IR[25:21] != 0);
	
	assign bypassAfromWB = (RR_EX_IR[20:16] == MEM_WB_IR[25:21]) & (MEM_WB_IR[25:21] != 0) & (EX_MEM_IR[25:21] != RR_EX_IR[20:16]);
	assign bypassBfromWB = (RR_EX_IR[15:11] == MEM_WB_IR[25:21]) & (MEM_WB_IR[25:21] != 0) & (EX_MEM_IR[25:21] != RR_EX_IR[15:11]);
	
	assign RR_EX_A_OF =  bypassAfromMEM ? EX_MEM_ALUOut : (bypassAfromWB) ? MEM_WB_ALUOut : RR_EX_A;
	assign RR_EX_B_OF =  bypassBfromMEM ? EX_MEM_ALUOut : (bypassBfromWB) ? MEM_WB_ALUOut : RR_EX_B;
	
	// Signal for a taken branch: instruction is BEQ and registers are equal
	assign TAKEN_BRANCH = (IF_ID_IR[31:26] == BEQ) && (Reg[IF_ID_IR[20:16]] == Reg[IF_ID_IR[15:11]]) || 
						  (IF_ID_IR[31:26] == BNEQ) && (Reg[IF_ID_IR[20:16]] != Reg[IF_ID_IR[15:11]]);
	
	/* // The signal for detecting a stall based on the use of a result from LW
	 assign stall = (MEMWBIR[31:26]==LW) && // source instruction is a load
	 ((((IDEXop==LW)|(IDEXop==SW)) && (IDEXrs==MEMWBrd)) | // stall for address calc
	((IDEXop==ALUop) && ((IDEXrs==MEMWBrd)|(IDEXrt==MEMWBrd)))); // ALU use */
	
	
	
	reg [5:0] i; //used to initialize registers 
/* 	initial begin 
		PC = 0; 
		IFIDIR=no-op; 
		IDEXIR=no-op; 
		EXMEMIR=no-op; 
		MEMWBIR=no-op; // put no-ops in pipeline registers
		for (i=0;i<=31;i=i+1) 
		Regs[i] = i; //initialize registers--just so they aren’t don’t cares
	 end */
////////////////////////////////////////////////////////IF Stage////////////////////////////////////////////////////////
	always @(posedge clk1)													
		if((~HALTED))
			begin
				if(((EX_MEM_IR[31:26]== BEQ)&&(EX_MEM_cond ==1)) || ((EX_MEM_IR[31:26]== BNEQ)&&(EX_MEM_cond==0)))
					begin
					   IF_ID_IR	    	<=  Mem[EX_MEM_ALUOut];
					   //TAKEN_BRANCH		<=  1'b1;
					   IF_ID_NPC    	<=  EX_MEM_ALUOut + 1;
					   PC				<=  EX_MEM_ALUOut + 1;
					end
				else
					begin
						IF_ID_IR		<= Mem[PC];
						IF_ID_NPC		<= PC+1;
						PC				<= PC+1;
					end
			end
////////////////////////////////////////////////////////ID Stage////////////////////////////////////////////////////////
	always@(posedge clk2)
		if((~HALTED))
			begin
				ID_RR_NPC		<=  IF_ID_NPC;
				ID_RR_IR		<=  IF_ID_IR;
				
				case(IF_ID_IR[31:26])
					ADD,SUB,AND,OR,SLT,MUL:   	ID_RR_type <=  RR_ALU;
					ADDI,SUBI,SLTI:		    	ID_RR_type <=  RM_ALU;
					LW:							ID_RR_type <=  LOAD;
					SW:							ID_RR_type <=  STORE; 
					BNEQ,BEQ:					ID_RR_type <=  BRANCH;
					HLT:						ID_RR_type <=  HALT;
					default:					ID_RR_type <=  HALT;
				endcase
			end
////////////////////////////////////////////////////////RR Stage////////////////////////////////////////////////////////
	always@(posedge clk1)
		if((~HALTED))
			begin
				if(ID_RR_IR[20:16]==5'b00000)	// If R0 is accessed which is always 0
					RR_EX_A	<= 0;
				else 
					RR_EX_A	<=  Reg[ID_RR_IR[20:16]];		// "rs"
                               
				if(ID_RR_IR[15:11]== 5'b00000)	// If R0 is accessed which is always 0
					RR_EX_B	<=0;
				else 
					RR_EX_B	<=  Reg[ID_RR_IR[15:11]];		// "rt"
				
				RR_EX_type      <=  ID_RR_type;
				RR_EX_NPC		<=  ID_RR_NPC;
				RR_EX_IR		<=  ID_RR_IR;
				RR_EX_Imm		<=  {{16{ID_RR_IR[15]}},{ID_RR_IR[15:0]}}; // Immediate type data is sign extended to 32 (I-type) 
			end
			
////////////////////////////////////////////////////////EX Stage////////////////////////////////////////////////////////
	always@(posedge clk2)
		if((~HALTED))
			begin
				EX_MEM_type		<=  RR_EX_type;
				EX_MEM_IR		<=  RR_EX_IR;
				//TAKEN_BRANCH	<=  1'b0;
				////////////////////////////////////////////////////////////////

					
				case(ID_RR_type)
					RR_ALU:	begin
						case(RR_EX_IR[31:26])	//"opcode"                                                        -
							ADD:	EX_MEM_ALUOut	<=  RR_EX_A_OF + RR_EX_B_OF;
							SUB:	EX_MEM_ALUOut	<=  RR_EX_A_OF - RR_EX_B_OF;
							AND:	EX_MEM_ALUOut	<=  RR_EX_A_OF & RR_EX_B_OF;
							OR:     EX_MEM_ALUOut	<=  RR_EX_A_OF | RR_EX_B_OF;
							SLT:    EX_MEM_ALUOut	<=  RR_EX_A_OF < RR_EX_B_OF;
							MUL:    EX_MEM_ALUOut	<=  RR_EX_A_OF * RR_EX_B_OF;
							default:EX_MEM_ALUOut	<=  32'hxxxxxxxx;
						endcase
					end
			
					RM_ALU:	begin
						case(RR_EX_IR[31:26])	//"opcode"
							ADDI:		EX_MEM_ALUOut	<=  RR_EX_A + RR_EX_Imm;
							SUBI:		EX_MEM_ALUOut	<=  RR_EX_A - RR_EX_Imm;
							SLTI:		EX_MEM_ALUOut	<=  RR_EX_A < RR_EX_Imm;
							default:	EX_MEM_ALUOut   <=  32'hxxxxxxxx;
						endcase
					end							  
					
					LOAD,STORE:	begin
						EX_MEM_ALUOut 	<= RR_EX_A + RR_EX_Imm;
						EX_MEM_B 		<= RR_EX_B;
					end
					BRANCH:	begin
						EX_MEM_ALUOut 	<= RR_EX_NPC + RR_EX_Imm;
						EX_MEM_cond 	<= (RR_EX_A == 0);
					end
				endcase
			end
////////////////////////////////////////////////////////MEM Stage////////////////////////////////////////////////////////			
	always@(posedge clk1)
		if((~HALTED))
			begin
				MEM_WB_type	<=  EX_MEM_type;
				MEM_WB_IR	<=  EX_MEM_IR;
				case(EX_MEM_type)
					RR_ALU,RM_ALU:	MEM_WB_ALUOut 		<= EX_MEM_ALUOut;
					LOAD:			MEM_WB_LMD			<= Mem[EX_MEM_ALUOut];
					STORE:			if(TAKEN_BRANCH ==0)						// Disable write
										Mem[EX_MEM_ALUOut]	<= EX_MEM_B;
				endcase
			end
    
////////////////////////////////////////////////////////WB Stage////////////////////////////////////////////////////////
	always@(posedge clk2)
		begin
			if(TAKEN_BRANCH == 0)		// Disable write if branch taken
			case(MEM_WB_type)
				RR_ALU:		Reg[MEM_WB_IR[25:21]] <=  MEM_WB_ALUOut;		//"rd"
				RM_ALU:		Reg[MEM_WB_IR[25:21]] <=  MEM_WB_ALUOut;		//"rt"
				LOAD:		Reg[MEM_WB_IR[25:21]] <=  MEM_WB_LMD;			//"rt"
				HALT:		HALTED 				  <=  1'b1;
			endcase
		end
       
endmodule