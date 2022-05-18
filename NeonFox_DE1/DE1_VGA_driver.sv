module DE1_VGA_driver(
		input wire clk_25,
		input wire vga_vsync_in,
		input wire vga_hsync_in,
		input wire vga_vde_in,
		input wire[3:0] vga_r_in,
		input wire[3:0] vga_g_in,
		input wire[3:0] vga_b_in,
		output wire vga_vsync_out,
		output wire vga_hsync_out,
		output wire[3:0] vga_r_out,
		output wire[3:0] vga_g_out,
		output wire[3:0] vga_b_out);
		
	reg vga_hsync_q;
	reg vga_vsync_q;
	reg[3:0] vga_r_q;
	reg[3:0] vga_g_q;
	reg[3:0] vga_b_q;
	
	assign vga_hsync_out = vga_hsync_q;
	assign vga_vsync_out = vga_vsync_q;
	assign vga_r_out = vga_r_q;
	assign vga_g_out = vga_g_q;
	assign vga_b_out = vga_b_q;
	
	always @(posedge clk_25)
	begin
		vga_hsync_q <= vga_hsync_in;
		vga_vsync_q <= vga_vsync_in;
		vga_r_q <= {4{vga_vde_in}} & vga_r_in;
		vga_g_q <= {4{vga_vde_in}} & vga_g_in;
		vga_b_q <= {4{vga_vde_in}} & vga_b_in;
	end
endmodule
