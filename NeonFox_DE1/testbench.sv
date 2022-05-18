`timescale 10ns/1ns
module Testbench();

//####### Platform External Signals ###########################################
reg clk;
reg n_reset;
reg button;
wire[1:0] LED;
logic[14:0] hex_indicators;
reg RXD;
wire TXD;
wire sdram_clk;
wire sdram_cke;
wire sdram_cs_n;
wire sdram_wre_n;
wire sdram_cas_n;
wire sdram_ras_n;
wire[12:0] sdram_a;
wire[1:0] sdram_ba;
wire[1:0] sdram_dqm;
wire[15:0] sdram_dq;

//####### Platform Internal Signals ###########################################
//wire clk_25;
//wire clk_sys;

wire p1_req;
wire p1_ready;
wire[1:0] p1_offset;
wire[31:0] p1_address;
wire[15:0] from_mem;

wire[31:0] p2_address;
wire p2_req;
wire p2_wren;
wire p2_ready;
wire[1:0] p2_offset;
wire[15:0] p2_to_mem;

logic[16:0] p3_address;
logic[15:0] p3_to_mem;
logic p3_req;
logic p3_wren;
logic p3_ready;
logic[1:0] p3_offset;

wire[31:0] prg_address;
wire[15:0] prg_data;

wire[31:0] data_address;
wire[15:0] data_to_cpu;
wire[15:0] from_cpu;
wire data_wren;
wire data_ren;

wire[15:0] IO_address;
wire[15:0] IO_to_cpu;
wire IO_wren;
wire IO_ren;
wire L_en;
wire H_en;

//reg[3:0] button_s;
//reg rst;

wire p_cache_rst;
wire p_cache_flush;
wire p_cache_prefetch;
wire p_cache_miss;

wire d_cache_rst;
wire d_cache_flush;
wire d_cache_prefetch;
wire d_cache_writeback;
wire d_read_miss;
wire d_write_miss;

wire init_req;
wire init_ready;
wire[15:0] init_data;
wire[11:0] init_address;

//wire serial_en;
//wire[7:0] from_serial;
//wire uart_rx_int;
//wire uart_tx_int;
//
//wire keyboard_en;
//wire[7:0] from_keyboard;
//wire kb_rx_int;
//
//wire timer_en;
//wire[7:0] from_timer;
//wire timer_int;
//
//wire intcon_en;
//wire[7:0] from_intcon;
//wire int_rq;
//wire[2:0] int_addr;
//
//wire MSC_en;
//
//wire VGA_MS;
//wire VGA_En;
//wire VGA_WrEn;
//wire[7:0] from_VGA;
//
//reg prev_VGA_en;
//reg prev_keyboard_en;
//reg prev_serial_en;
//reg prev_timer_en;
//reg prev_intcon_en;

//####### Interrupt Controller Internal Signals ###############################
//wire[7:0] in;
//wire[7:0] prev_in;
//wire[7:0] control;
//wire[7:0] status;
//wire[7:0] trig;
//wire[7:0] interrupt;

//####### CPU Internal Signals ################################################
//logic prev_int_rq;
//logic interrupt;

logic data_hazard;
logic hazard;
logic branch_hazard;
logic decoder_rst;
logic H_en0, H_en1, H_en2;
logic L_en0, L_en1, L_en2;
logic regf_wren, regf_wren1, regf_wren2;
logic[4:0] src_raddr;
logic[4:0] dest_waddr, dest_waddr1, dest_waddr2;
logic[15:0] alu_out;
logic[15:0] a_data;
logic[15:0] b_data;
logic[31:0] last_callx_addr;
logic[31:0] next_callx_addr;

logic set_cc;
logic[9:0] I_field;
logic[7:0] I_field1;
logic[3:0] alu_op, alu_op1;
logic n, z, p;

logic pc_jmp, pc_jmp1;
logic pc_brx;
logic pc_brxt;
logic pc_call, pc_call1;
logic pc_ret, pc_ret1;
logic take_brx, take_brx1;
//logic PC_stall;

logic[15:0] aux0;
logic[15:0] aux1;
logic[15:0] aux2;
logic[15:0] aux3;

logic[15:0] r0;
logic[15:0] r1;
logic[15:0] r2;
logic[15:0] r3;

logic[15:0] dal;
logic[15:0] dah;
logic[15:0] ial;
logic[15:0] cal;
logic[15:0] cah;

//logic[15:0] DIO_in;
//logic data_wren0, data_wren1, data_wren2;
//logic data_ren0;
//logic IO_wren0, IO_wren1, IO_wren2;
//logic IO_ren0;
//logic status_ren;
//logic data_select, data_select1, data_select2;
//logic IO_select, IO_select1, IO_select2;

logic[15:0] I_reg;
logic[15:0] I_alternate;

assign d_cache_writeback = p2_req & p2_wren;

NeonFox_PVP PVP_inst(
		.reset(n_reset),
		.clk(clk),
		.button(button),
		.RXD(RXD),
		.TXD(TXD),
		.ps2_clk_d(1'b1),
		.ps2_data_d(1'b1),
		.ps2_clk_q(),
		.ps2_data_q(),
		.LED(LED),
		.sdram_clk(sdram_clk),
		.sdram_cke(sdram_cke),
		.sdram_cs_n(sdram_cs_n),
		.sdram_wre_n(sdram_wre_n),
		.sdram_cas_n(sdram_cas_n),
		.sdram_ras_n(sdram_ras_n),
		.sdram_a(sdram_a),
		.sdram_ba(sdram_ba),
		.sdram_dqm(sdram_dqm),
		.sdram_dq(sdram_dq),
		.tmds_r_p(),
		.tmds_r_n(),
		.tmds_g_p(),
		.tmds_g_n(),
		.tmds_b_p(),
		.tmds_b_n(),
		.tmds_clk_p(),
		.tmds_clk_n(),
		.seg_sel(),
		.hex_out());
		
sdr sdram0(
		.Dq(sdram_dq),
		.Addr(sdram_a),
		.Ba(sdram_ba),
		.Clk(sdram_clk),
		.Cke(sdram_cke),
		.Cs_n(sdram_cs_n),
		.Ras_n(sdram_ras_n),
		.Cas_n(sdram_cas_n),
		.We_n(sdram_wre_n),
		.Dqm(sdram_dqm));

//####### Platform Internal Signals ###########################################
//assign clk_25 = PVP_inst.clk_25;
//assign clk_sys = PVP_inst.clk_sys;

assign IO_address = PVP_inst.IO_address;
assign from_cpu = PVP_inst.from_cpu;
assign IO_to_cpu = PVP_inst.IO_to_cpu;
assign IO_wren = PVP_inst.IO_wren;
assign IO_ren = PVP_inst.IO_ren;
assign L_en = PVP_inst.L_en;
assign H_en = PVP_inst.H_en;

//assign button_s = PVP_inst.button_s;
//assign rst = PVP_inst.rst;
assign hex_indicators = PVP_inst.hex_indicators;

assign prg_address = PVP_inst.prg_address;
assign prg_data = PVP_inst.prg_data;
assign p1_address = PVP_inst.p1_address;
assign p1_req = PVP_inst.p1_req;
assign p1_ready = PVP_inst.p1_ready;
assign p1_offset = PVP_inst.p1_offset;
assign from_mem = PVP_inst.from_mem;
assign p_cache_rst = PVP_inst.p_cache_rst;
assign p_cache_flush = PVP_inst.p_cache_flush;
assign p_cache_prefetch = PVP_inst.p_cache_prefetch;
assign p_cache_miss = PVP_inst.p_cache_miss;

assign data_address = PVP_inst.data_address;
assign data_to_cpu = PVP_inst.data_to_cpu;
assign data_wren = PVP_inst.data_wren;
assign data_ren = PVP_inst.data_ren;
assign p2_address = PVP_inst.p2_address;
assign p2_req = PVP_inst.p2_req;
assign p2_wren = PVP_inst.p2_wren;
assign p2_ready = PVP_inst.p2_ready;
assign p2_offset = PVP_inst.p2_offset;
assign p2_to_mem = PVP_inst.p2_to_mem;
assign d_cache_rst = PVP_inst.d_cache_rst;
assign d_cache_flush = PVP_inst.d_cache_flush;
assign d_cache_prefetch = PVP_inst.d_cache_prefetch;
assign d_read_miss = PVP_inst.d_read_miss;
assign d_write_miss = PVP_inst.d_write_miss;

assign p3_address = PVP_inst.p3_address;
assign p3_to_mem = PVP_inst.p3_to_mem;
assign p3_req = PVP_inst.p3_req;
assign p3_wren = PVP_inst.p3_wren;
assign p3_ready = PVP_inst.p3_ready;
assign p3_offset = PVP_inst.p3_offset;

assign init_req = PVP_inst.init_req;
assign init_ready = PVP_inst.init_ready;
assign init_data = PVP_inst.init_data;
assign init_address = PVP_inst.init_address;

//assign serial_en = PVP_inst.serial_en;
//assign from_serial = PVP_inst.from_serial;
//assign uart_rx_int = PVP_inst.uart_rx_int;
//assign uart_tx_int = PVP_inst.uart_tx_int;
//
//assign keyboard_en = PVP_inst.keyboard_en;
//assign from_keyboard = PVP_inst.from_keyboard;
//assign kb_rx_int = PVP_inst.kb_rx_int;
//
//assign timer_en = PVP_inst.timer_en;
//assign from_timer = PVP_inst.from_timer;
//assign timer_int = PVP_inst.timer_int;
//
//assign intcon_en = PVP_inst.intcon_en;
//assign from_intcon = PVP_inst.from_intcon;
//assign int_rq = PVP_inst.int_rq;
//assign int_addr = PVP_inst.int_addr;
//
//assign MSC_en = PVP_inst.MSC_en;
//
//assign VGA_MS = PVP_inst.VGA_MS;
//assign VGA_En = PVP_inst.VGA_En;
//assign VGA_WrEn = PVP_inst.VGA_WrEn;
//assign from_VGA = PVP_inst.from_VGA;
//
//assign prev_VGA_en = PVP_inst.prev_VGA_en;
//assign prev_keyboard_en = PVP_inst.prev_keyboard_en;
//assign prev_serial_en = PVP_inst.prev_serial_en;
//assign prev_timer_en = PVP_inst.prev_timer_en;
//assign prev_intcon_en = PVP_inst.prev_intcon_en;

//####### CPU Internal Signals ################################################
//assign prev_int_rq = PVP_inst.CPU_inst.prev_int_rq;
//assign interrupt = PVP_inst.CPU_inst.interrupt;
//assign DIO_in = PVP_inst.CPU_inst.DIO_in;

assign data_hazard = PVP_inst.CPU_inst.data_hazard;
assign regf_wren = PVP_inst.CPU_inst.regf_wren;
assign regf_wren1 = PVP_inst.CPU_inst.regf_wren1;
assign regf_wren2 = PVP_inst.CPU_inst.regf_wren2;
assign H_en0 = PVP_inst.CPU_inst.H_en0;
assign H_en1 = PVP_inst.CPU_inst.H_en1;
assign H_en2 = PVP_inst.CPU_inst.H_en2;
assign L_en0 = PVP_inst.CPU_inst.L_en0;
assign L_en1 = PVP_inst.CPU_inst.L_en1;
assign L_en2 = PVP_inst.CPU_inst.L_en2;
assign src_raddr = PVP_inst.CPU_inst.src_raddr;
assign dest_waddr = PVP_inst.CPU_inst.dest_waddr;
assign dest_waddr1 = PVP_inst.CPU_inst.dest_waddr1;
assign dest_waddr2 = PVP_inst.CPU_inst.dest_waddr2;
assign alu_out = PVP_inst.CPU_inst.alu_out;
assign a_data = PVP_inst.CPU_inst.a_data;
assign b_data = PVP_inst.CPU_inst.b_data;
assign last_callx_addr = PVP_inst.CPU_inst.last_callx_addr;
assign next_callx_addr = PVP_inst.CPU_inst.next_callx_addr;

assign set_cc = PVP_inst.CPU_inst.set_cc;
assign I_field = PVP_inst.CPU_inst.I_field;
assign I_field1 = PVP_inst.CPU_inst.I_field1;
assign alu_op = PVP_inst.CPU_inst.alu_op;
assign alu_op1 = PVP_inst.CPU_inst.alu_op1;
assign n = PVP_inst.CPU_inst.n;
assign z = PVP_inst.CPU_inst.z;
assign p = PVP_inst.CPU_inst.p;

assign pc_jmp = PVP_inst.CPU_inst.pc_jmp;
assign pc_jmp1 = PVP_inst.CPU_inst.pc_jmp1;
assign pc_brx = PVP_inst.CPU_inst.pc_brx;
assign pc_brxt = PVP_inst.CPU_inst.pc_brxt;
assign pc_call = PVP_inst.CPU_inst.pc_call;
assign pc_call1 = PVP_inst.CPU_inst.pc_call1;
assign pc_ret = PVP_inst.CPU_inst.pc_ret;
assign pc_ret1 = PVP_inst.CPU_inst.pc_ret1;
assign hazard = PVP_inst.CPU_inst.hazard;
assign branch_hazard = PVP_inst.CPU_inst.branch_hazard;
assign take_brx = PVP_inst.CPU_inst.take_brx;
assign take_brx1 = PVP_inst.CPU_inst.take_brx1;
//assign PC_stall = PVP_inst.CPU_inst.PC_stall;
assign aux0 = PVP_inst.CPU_inst.reg_file_inst.aux0;
assign aux1 = PVP_inst.CPU_inst.reg_file_inst.aux1;
assign aux2 = PVP_inst.CPU_inst.reg_file_inst.aux2;
assign aux3 = PVP_inst.CPU_inst.reg_file_inst.aux3;

assign r0 = PVP_inst.CPU_inst.reg_file_inst.r0;
assign r1 = PVP_inst.CPU_inst.reg_file_inst.r1;
assign r2 = PVP_inst.CPU_inst.reg_file_inst.r2;
assign r3 = PVP_inst.CPU_inst.reg_file_inst.r3;

assign dal = PVP_inst.CPU_inst.reg_file_inst.dal;
assign dah = PVP_inst.CPU_inst.reg_file_inst.dah;
assign ial = PVP_inst.CPU_inst.reg_file_inst.ial;

assign cal = PVP_inst.CPU_inst.reg_file_inst.cal;
assign cah = PVP_inst.CPU_inst.reg_file_inst.cah;

assign decoder_rst = PVP_inst.CPU_inst.decoder_rst;
//assign data_wren0 = PVP_inst.CPU_inst.data_wren0;
//assign data_wren1 = PVP_inst.CPU_inst.data_wren1;
//assign data_wren2 = PVP_inst.CPU_inst.data_wren2;
//assign data_ren0 = PVP_inst.CPU_inst.data_ren0;
//assign IO_wren0 = PVP_inst.CPU_inst.IO_wren0;
//assign IO_wren1 = PVP_inst.CPU_inst.IO_wren1;
//assign IO_wren2 = PVP_inst.CPU_inst.IO_wren2;
//assign IO_ren0 = PVP_inst.CPU_inst.IO_ren0;
//assign status_ren = PVP_inst.CPU_inst.status_ren;
//assign data_select = PVP_inst.CPU_inst.data_select;
//assign data_select1 = PVP_inst.CPU_inst.data_select1;
//assign data_select2 = PVP_inst.CPU_inst.data_select2;
//assign IO_select = PVP_inst.CPU_inst.IO_select;
//assign IO_select1 = PVP_inst.CPU_inst.IO_select1;
//assign IO_select2 = PVP_inst.CPU_inst.IO_select2;

assign I_reg = PVP_inst.CPU_inst.decoder_inst.I_reg;
assign I_alternate = PVP_inst.CPU_inst.decoder_inst.I_alternate;

always begin: CLOCK_GENERATION
#1 clk =  ~clk;
end

initial begin: CLOCK_INITIALIZATION
	clk = 0;
end

initial begin: TEST_VECTORS
//initial conditions
n_reset = 1'b0;
button = 1'b1;
RXD = 1'b1;

#20 n_reset = 1'b1;	//release reset
#40707 button <= 1'b0;
#4 button <= 1'b1;
//#177134 n_reset = 1'b0;
//#20 n_reset = 1'b1;
end
endmodule
