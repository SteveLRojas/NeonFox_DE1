module DE1_PS2_driver(
		output wire ps2_data_d,
		output wire ps2_clk_d,
		input wire ps2_data_q,
		input wire ps2_clk_q,
		inout wire ps2_data,
		inout wire ps2_clk);
	
	assign ps2_data = ps2_data_q ? 1'b0 : 1'bz;
	assign ps2_clk = ps2_clk_q ? 1'b0 : 1'bz;
	assign ps2_data_d = ps2_data;
	assign ps2_clk_d = ps2_clk;
		
endmodule
