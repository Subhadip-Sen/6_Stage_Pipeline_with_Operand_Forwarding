module test_mips32;
	reg clk1,clk2;
	integer k;
	Pipelined mips(clk1,clk2);
	  initial
		begin
			clk1=0;
			repeat(60)				// Generating 2-Phase Clock
				begin
					#10 clk1=1; #10 clk1=0;
					#5 clk2=1; #5 clk2=0;
				end
		end

	initial
		begin
			for(k=0;k<31;k=k+1)
				mips.Reg[k]=k;
     
			mips.Mem[0] = 32'h2820000a; 	// ADDI R1,RO,10
			mips.Mem[1] = 32'h28400014;		// ADDI R2,RO,20
			mips.Mem[2] = 32'h28600019;		// ADDI R3,RO,25
			mips.Mem[3] = 32'h0ce77800;     // OR R7,R7,R7 -- dummy instr.         
			mips.Mem[4] = 32'h0ce77800;		// OR R7,R7,R7 -- dummy instr. 
			mips.Mem[5] = 32'h00811000;		// ADD R4,R1,R2
			//mips.Mem[6] = 32'h0ce77800;		// OR R7,R7,R7 -- dummy instr. 
			mips.Mem[6] = 32'h00c21800;		// ADD R6,R2,R3
			//mips.Mem[7] = 32'h00e11800;		// ADD R7,R1,R3
			mips.Mem[7] = 32'h00a41800;		// ADD R5,R4,R3
			mips.Mem[8] = 32'hfc000000;		// HLT

			mips.HALTED = 0;
			mips.PC = 0;
			force mips.TAKEN_BRANCH = 0;
			
			#300
			for(k=0;k<7;k=k+1)
			  $display("R%1d - %d",k,mips.Reg[k]);
		end
	initial
		begin
			$dumpfile ("mips.vcd");
			$dumpvars (0,test_mips32);
			#300 $finish;
		end
endmodule	 