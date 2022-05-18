module hazard_unit(
		//input logic clk,
		input logic pc_jmp, pc_jmp1,
		input logic pc_brx,
		input logic pc_call, pc_call1,
		input logic pc_ret1,
		input logic interrupt,
		input logic take_brx1,
		input logic[3:0] alu_op1,
		input logic halt,
		//input logic rst,
		input logic extend_flush,
		input logic IO_select1, IO_select2,
		input logic address_select1, address_select2,
		input logic data_select1, data_select2, 
		input logic IO_ren,
		input logic IO_wren1, IO_wren2,
		input logic data_ren,
		input logic data_wren1, data_wren2,
		input logic status_ren,
		input logic d_cache_read_miss,
		input logic d_cache_write_miss,
		output logic hazard,
		//output logic data_hazard,
		output logic branch_hazard,
		output logic decoder_input_flush,
		output logic decoder_output_flush);
//logic rst_hold;
logic branch_taken;
//logic decoder_flush;
logic status_hazard;
logic IO_hazard, IO_hazard1, IO_hazard2;
logic data_hazard_read1, data_hazard_read2;
logic data_hazard_read;
logic branch_hazard_ca;
logic branch_hazard_nzp;

assign status_hazard = (alu_op1 != 4'b0111) & status_ren;
assign branch_hazard_nzp = (alu_op1 != 4'b0111) & pc_brx;	//recent write to nzp and brx
assign branch_hazard_ca = (address_select1 | address_select2) & (pc_call | pc_jmp);	//call or jump after writing call address
assign branch_hazard = branch_hazard_ca | branch_hazard_nzp;
assign decoder_output_flush = take_brx1 | pc_jmp1 | pc_call1 | pc_ret1 | interrupt;
//always_ff @(posedge clk) rst_hold <= rst;
//assign decoder_rst = rst | rst_hold | (decoder_flush & extend_flush) | interrupt;
assign decoder_input_flush = (decoder_output_flush & extend_flush) | interrupt;
assign IO_hazard1 = IO_ren & (IO_select1 | IO_wren1);
assign IO_hazard2 = IO_ren & (IO_select2 | IO_wren2);
assign IO_hazard = IO_hazard1 | IO_hazard2;
assign data_hazard_read1 = data_ren & (data_select1 | data_wren1);
assign data_hazard_read2 = data_ren & (data_select2 | data_wren2);
assign data_hazard_read = data_hazard_read1 | data_hazard_read2;
assign hazard = IO_hazard | data_hazard_read | d_cache_read_miss | d_cache_write_miss | halt | branch_hazard | status_hazard;
endmodule : hazard_unit
