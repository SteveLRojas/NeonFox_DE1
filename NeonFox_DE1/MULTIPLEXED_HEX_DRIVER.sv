module MULTIPLEXED_HEX_DRIVER_3D(
		input logic Clk,
		input logic[3:0] SEG0,
		input logic[3:0] SEG1,
		input logic[3:0] SEG2,
		input logic[2:0] LED,
		output logic[2:0] SEG_SEL,
		output logic[7:0] HEX_OUT);
		
	logic[1:0] count;
	logic[6:0] HEX0, HEX1, HEX2;
	logic[3:0] SEG0_s, SEG1_s, SEG2_s;
	logic[2:0] LED_s;

	always @(posedge Clk)
	begin
		SEG0_s <= SEG0;
		SEG1_s <= SEG1;
		SEG2_s <= SEG2;
		LED_s <= LED;
	end

	hexdriver hex_inst_0(.In(SEG0_s), .Out(HEX0));
	hexdriver hex_inst_1(.In(SEG1_s), .Out(HEX1));
	hexdriver hex_inst_2(.In(SEG2_s), .Out(HEX2));
	frame_clk frame_clk_inst(.Clk, .seg_count(count));

	always_comb
	begin
		unique case(count)
			2'b00: SEG_SEL = 3'b001;
			2'b01: SEG_SEL = 3'b010;
			2'b10: SEG_SEL = 3'b100;
			2'b11: SEG_SEL = 3'bxxx;
		endcase
	end

	always_comb
	begin
		unique case(count)
			2'b00: HEX_OUT = {~LED_s[0], HEX0};
			2'b01: HEX_OUT = {~LED_s[1], HEX1};
			2'b10: HEX_OUT = {~LED_s[2], HEX2};
			2'b11: HEX_OUT = 7'hxx;
		endcase
	end
endmodule	
	
module hexdriver(input logic[3:0] In, output logic[6:0] Out);
	always_comb begin
		unique case (In)
			4'b0000   : Out = 7'b1000000; // '0'
			4'b0001   : Out = 7'b1111001; // '1'
			4'b0010   : Out = 7'b0100100; // '2'
			4'b0011   : Out = 7'b0110000; // '3'
			4'b0100   : Out = 7'b0011001; // '4'
			4'b0101   : Out = 7'b0010010; // '5'
			4'b0110   : Out = 7'b0000010; // '6'
			4'b0111   : Out = 7'b1111000; // '7'
			4'b1000   : Out = 7'b0000000; // '8'
			4'b1001   : Out = 7'b0010000; // '9'
			4'b1010   : Out = 7'b0001000; // 'A'
			4'b1011   : Out = 7'b0000011; // 'b'
			4'b1100   : Out = 7'b1000110; // 'C'
			4'b1101   : Out = 7'b0100001; // 'd'
			4'b1110   : Out = 7'b0000110; // 'E'
			4'b1111   : Out = 7'b0001110; // 'F'
		endcase
	end
endmodule

module frame_clk(input logic Clk, output logic[1:0] seg_count);
	logic [16:0] count;
	always_ff @ (posedge Clk)
	begin
		count <= count + 17'h01;
		if(count == 17'h00)
		begin
			if(seg_count == 2'h2)
				seg_count <= 2'h0;
			else
				seg_count <= seg_count + 2'h1;
		end
	end
endmodule
