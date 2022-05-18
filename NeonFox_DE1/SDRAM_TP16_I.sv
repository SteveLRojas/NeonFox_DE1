module SDRAM_TP16_I(
		input logic clk,
		input logic rst,
		output logic[15:0] from_mem,
		
		//input logic[23:0] p1_address,
		input logic[21:0] p1_address,
		input logic p1_req,
		output logic p1_ready,
		output logic[1:0] p1_offset,
		
		//input logic[23:0] p2_address,
		input logic[21:0] p2_address,
		input logic[15:0] p2_to_mem,
		input logic p2_req,
		input logic p2_wren,
		output logic p2_ready,
		output logic[1:0] p2_offset,
		
		//input logic[23:0] p3_address,
		input logic[21:0] p3_address,
		input logic[15:0] p3_to_mem,
		input logic p3_req,
		input logic p3_wren,
		output logic p3_ready,
		output logic[1:0] p3_offset,

		output logic sdram_cke,
		output logic sdram_cs_n,
		output logic sdram_wre_n,
		output logic sdram_cas_n,
		output logic sdram_ras_n,
		//output logic[12:0] sdram_a,
		output logic[11:0] sdram_a,
		output logic[1:0] sdram_ba,
		output logic[1:0] sdram_dqm,
		inout wire[15:0] sdram_dq,
		
		output logic init_req,
		input logic init_ready,
		output logic[11:0] init_address,
		input logic[15:0] init_data);

localparam [2:0] SDRAM_CMD_LOADMODE  = 3'b000;
localparam [2:0] SDRAM_CMD_REFRESH   = 3'b001;
localparam [2:0] SDRAM_CMD_PRECHARGE = 3'b010;
localparam [2:0] SDRAM_CMD_ACTIVE    = 3'b011;
localparam [2:0] SDRAM_CMD_WRITE     = 3'b100;
localparam [2:0] SDRAM_CMD_READ      = 3'b101;
localparam [2:0] SDRAM_CMD_NOP       = 3'b111;

enum logic[5:0] {
		S_CMD_RESET,
		S_CMD_INIT_DEVICE,
		S_CMD_INIT_DEVICE_NOP,
		S_CMD_MODE,
		S_CMD_MODE_NOP,

		S_CMD_ACTIVATE,
		S_CMD_READ_P1,
		S_CMD_READ_P2,
		S_CMD_READ_P3,
		S_CMD_WRITE_P2_NOP,
		S_CMD_WRITE_P2,
		S_CMD_WRITE_P3_NOP,
		S_CMD_WRITE_P3,

		S_CMD_REFRESH,
		S_CMD_REFRESH_NOP1,
		S_CMD_REFRESH_NOP2,
		S_CMD_REFRESH_NOP3,
		S_CMD_REFRESH_NOP4,
		S_CMD_REFRESH_NOP5,

		S_CMD_INIT_DATA,
		S_CMD_INIT_READ,
		S_CMD_WRITE_ACTIVATE,
		S_CMD_WRITE_ACTIVATE_NOP,
		S_CMD_INIT_WRITE,
		S_CMD_INC } cmd_state;

enum logic[4:0] {
		S_IO_IDLE,
		S_IO_P1_FROM_MEM,
		S_IO_P2_FROM_MEM,
		S_IO_P3_FROM_MEM,
		S_IO_P2_TO_MEM,
		S_IO_P3_TO_MEM } io_state;

logic prev_p1_req;
logic prev_p2_req;
logic prev_p3_req;
logic p1_req_flag;
logic p2_req_flag;
logic p3_req_flag;
logic p1_request;
logic p2_request;
logic p3_request;

logic bank0_active;	//bank0 is not idle
logic bank1_active;
logic bank2_active;
logic bank3_active;
logic current_active;	//state of currently selected bank

logic[1:0] precharge_timer;	//count down to precharge complete
logic precharge_time;	//precharge timer ran out
logic[1:0] precharge_bank;	//bank to precharge
logic[1:0] next_precharge_bank;
logic precharge_flag;
logic[1:0] start_delay;	//cycles after command before starting IO read

logic port1_bank_state;	//state of the bank requested by port1
logic port2_bank_state;
logic port3_bank_state;

logic port1_bank_ready;	//port1 is requesting a bank that is idle
logic port2_bank_ready;
logic port3_bank_ready;

logic[9:0] refresh_timer;
logic refresh_flag;
logic[2:0] init_refresh_count;	//initially set to 7. On refresh the number of refresh cycles performed will be this number plus one.
logic init_flag;
logic mark_flag;	//indicates that a bank has been activated and should be marked as active.
logic[9:0] init_base;
logic[1:0] init_offset;
(* ramstyle = "logic" *) logic[15:0] init_data_hold[3:0];
logic[1:0] burst_offset;

logic p1_ready_reg;
logic p2_ready_reg;
logic p3_ready_reg;

logic[15:0] data_out;
logic gate_out;
logic[2:0] sdram_cmd;

assign p1_request = (p1_req & ~prev_p1_req) | p1_req_flag;
assign p2_request = (p2_req & ~prev_p2_req) | p2_req_flag;
assign p3_request = (p3_req & ~prev_p3_req) | p3_req_flag;
assign precharge_time = ~|precharge_timer;

always_comb
begin
	case(sdram_ba)
		2'h0: current_active = bank0_active;
		2'h1: current_active = bank1_active;
		2'h2: current_active = bank2_active;
		2'h3: current_active = bank3_active;
	endcase // sdram_ba
	case(p1_address[3:2])
		2'b00: port1_bank_state = bank0_active;
		2'b01: port1_bank_state = bank1_active;
		2'b10: port1_bank_state = bank2_active;
		2'b11: port1_bank_state = bank3_active;
	endcase // p1_address[3:2]
	case(p2_address[3:2])
		2'b00: port2_bank_state = bank0_active;
		2'b01: port2_bank_state = bank1_active;
		2'b10: port2_bank_state = bank2_active;
		2'b11: port2_bank_state = bank3_active;
	endcase // p2_address[3:2]
	case(p3_address[3:2])
		2'b00: port3_bank_state = bank0_active;
		2'b01: port3_bank_state = bank1_active;
		2'b10: port3_bank_state = bank2_active;
		2'b11: port3_bank_state = bank3_active;
	endcase // p3_address[3:2]
	port1_bank_ready = p1_request & ~port1_bank_state;
	port2_bank_ready = p2_request & ~port2_bank_state;
	port3_bank_ready = p3_request & ~port3_bank_state;
end

always_ff @(posedge clk)
begin
	if(rst)
	begin
		io_state <= S_IO_IDLE;
		cmd_state <= S_CMD_RESET;
		init_base <= 10'h00;
		init_offset <= 2'b00;
		prev_p1_req <= 1'b0;
		prev_p2_req <= 1'b0;
		prev_p3_req <= 1'b0;
		p1_req_flag <= 1'b0;
		p2_req_flag <= 1'b0;
		p3_req_flag <= 1'b0;
		gate_out <= 1'b0;
		sdram_dqm <= 2'b11;
		bank0_active <= 1'b0;
		bank1_active <= 1'b0;
		bank2_active <= 1'b0;
		bank3_active <= 1'b0;
		precharge_timer <= 2'b00;
		precharge_flag <= 1'b0;
		refresh_timer <= 10'h00;
		refresh_flag <= 1'b1;
	end
	else
	begin
		prev_p1_req <= p1_req;
		prev_p2_req <= p2_req;
		prev_p3_req <= p3_req;
		if(p1_req & ~prev_p1_req)
			p1_req_flag <= 1'b1;
		if(p2_req & ~prev_p2_req)
			p2_req_flag <= 1'b1;
		if(p3_req & ~prev_p3_req)
			p3_req_flag <= 1'b1;

		if(refresh_timer == 10'd781)	//4K / 64ms
		//if(refresh_timer == 10'd390)	//8k / 64ms
		begin
			refresh_timer <= 10'h00;
			refresh_flag <= 1'b1;
		end
		else
			refresh_timer <= refresh_timer + 10'h01;

		if(|precharge_timer)
		begin
			precharge_timer <= precharge_timer - 2'h1;
		end
		if(precharge_flag & precharge_time)
		begin
			precharge_flag <= 1'b0;
			unique case(precharge_bank)
				2'b00: bank0_active <= 1'b0;
				2'b01: bank1_active <= 1'b0;
				2'b10: bank2_active <= 1'b0;
				2'b11: bank3_active <= 1'b0;
			endcase
		end

		if(mark_flag)
		begin
			case(sdram_ba)
				2'h0: bank0_active <= 1'b1;
				2'h1: bank1_active <= 1'b1;
				2'h2: bank2_active <= 1'b1;
				2'h3: bank3_active <= 1'b1;
			endcase // sdram_ba
		end

		case(io_state)
			S_IO_IDLE:
			begin
				if(current_active)
				begin
					case(cmd_state)
						S_CMD_READ_P1: io_state <= S_IO_P1_FROM_MEM;
						S_CMD_READ_P2: io_state <= S_IO_P2_FROM_MEM;
						S_CMD_READ_P3: io_state <= S_IO_P3_FROM_MEM;
						S_CMD_WRITE_P2_NOP: io_state <= S_IO_P2_TO_MEM;
						S_CMD_WRITE_P3_NOP: io_state <= S_IO_P3_TO_MEM;
						default: ;
					endcase // cmd_state
				end
				p1_ready_reg <= 1'b0;
				p2_ready_reg <= (cmd_state == S_CMD_WRITE_P2_NOP);
				p3_ready_reg <= (cmd_state == S_CMD_WRITE_P3_NOP);
				p1_offset <= 2'h0;
				p2_offset <= (current_active && (cmd_state == S_CMD_WRITE_P2_NOP)) ? (p2_offset + 2'h1) : 2'h0;
				p3_offset <= (current_active && (cmd_state == S_CMD_WRITE_P3_NOP)) ? (p3_offset + 2'h1) : 2'h0;
				gate_out <= 1'b0;
				sdram_dqm <= 2'b11;
				start_delay <= 2'b10;
				next_precharge_bank <= sdram_ba;
			end
			S_IO_P1_FROM_MEM:
			begin
				p1_offset <= p1_ready_reg ? (p1_offset + 2'h1) : 2'h0;
				start_delay <= start_delay ? (start_delay - 2'b01) : 2'b00;
				if(start_delay == 2'b00)
				begin
					from_mem <= sdram_dq;
					p1_ready_reg <= 1'b1;
				end
				if(p1_offset[0])	//at cycle 1
				begin
					precharge_bank <= next_precharge_bank;
					precharge_timer <= 2'h0;
					precharge_flag <= 1'b1;
				end
				if(p1_offset == 2'b11)
				begin
					io_state <= S_IO_IDLE;
					p1_ready_reg <= 1'b0;
				end
			end
			S_IO_P2_FROM_MEM:
			begin
				p2_offset <= p2_ready_reg ? (p2_offset + 2'h1) : 2'h0;
				start_delay <= start_delay ? (start_delay - 2'b01) : 2'b00;
				if(start_delay == 2'b00)
				begin
					from_mem <= sdram_dq;
					p2_ready_reg <= 1'b1;
				end
				if(p2_offset[0])
				begin
					precharge_bank <= next_precharge_bank;
					precharge_timer <= 2'h0;
					precharge_flag <= 1'b1;
				end
				if(p2_offset == 2'b11)
				begin
					io_state <= S_IO_IDLE;
					p2_ready_reg <= 1'b0;
				end
			end
			S_IO_P3_FROM_MEM:
			begin
				p3_offset <= p3_ready_reg ? (p3_offset + 2'h1) : 2'h0;
				start_delay <= start_delay ? (start_delay - 2'b01) : 2'b00;
				if(start_delay == 2'b00)
				begin
					from_mem <= sdram_dq;
					p3_ready_reg <= 1'b1;
				end
				if(p3_offset[0])
				begin
					precharge_bank <= next_precharge_bank;
					precharge_timer <= 2'h0;
					precharge_flag <= 1'b1;
				end
				if(p3_offset == 2'b11)
				begin
					io_state <= S_IO_IDLE;
					p3_ready_reg <= 1'b0;
				end
			end
			S_IO_P2_TO_MEM:
			begin
				p2_offset <= p2_ready_reg ? (p2_offset + 2'h1) : 2'h0;
				data_out <= p2_to_mem;
				if(~p2_ready_reg)
				begin
					io_state <= S_IO_IDLE;
					precharge_bank <= next_precharge_bank;
					precharge_timer <= 2'h2;
					precharge_flag <= 1'b1;
				end
				if(p2_offset == 2'b11)
				begin
					p2_ready_reg <= 1'b0;
				end
			end
			S_IO_P3_TO_MEM:
			begin
				p3_offset <= p3_ready_reg ? (p3_offset + 2'h1) : 2'h0;
				data_out <= p3_to_mem;
				if(~p3_ready_reg)
				begin
					io_state <= S_IO_IDLE;
					precharge_bank <= next_precharge_bank;
					precharge_timer <= 2'h2;
					precharge_flag <= 1'b1;
				end
				if(p3_offset == 2'b11)
				begin
					p3_ready_reg <= 1'b0;
				end
			end
			default: ;
		endcase // io_state

		mark_flag <= 1'b0;
		sdram_cmd <= SDRAM_CMD_NOP;
		case(cmd_state)
			S_CMD_RESET:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				init_refresh_count <= 3'b111;
				init_flag <= 1'b1;
				cmd_state <= S_CMD_INIT_DEVICE;
			end
			S_CMD_INIT_DEVICE:
			begin
				sdram_cmd <= SDRAM_CMD_PRECHARGE;
				sdram_a[10] <= 1'b1;	//precharge all
				cmd_state <= S_CMD_INIT_DEVICE_NOP;
			end
			S_CMD_INIT_DEVICE_NOP:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				cmd_state <= S_CMD_MODE;
			end
			S_CMD_MODE:
			begin
				sdram_cmd <= SDRAM_CMD_LOADMODE;
				sdram_a <= 12'b0000_0010_1010;	//burst read and write, CAS latency 2, interleave, burst length 4.
				sdram_ba <= 2'b00;
				cmd_state <= S_CMD_MODE_NOP;
			end
			S_CMD_MODE_NOP:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				cmd_state <= S_CMD_REFRESH;
			end
			S_CMD_ACTIVATE:
			begin
				if(refresh_flag | port1_bank_ready | port2_bank_ready | port3_bank_ready)
				begin
					if(refresh_flag | port1_bank_ready)
					begin
						if(refresh_flag)
						begin
							cmd_state <= S_CMD_REFRESH;
							//refresh_flag <= 1'b0;
						end
						else	//port1_bank_ready
						begin
							cmd_state <= S_CMD_READ_P1;
							p1_req_flag <= 1'b0;
						end
					end
					else
					begin
						if(port2_bank_ready)
						begin
							cmd_state <= p2_wren ? S_CMD_WRITE_P2_NOP : S_CMD_READ_P2;
							p2_req_flag <= 1'b0;
						end
						else	//port3_bank_ready
						begin
							cmd_state <= p3_wren ? S_CMD_WRITE_P3_NOP : S_CMD_READ_P3;
							p3_req_flag <= 1'b0;
						end
					end
				end

				if(~refresh_flag & (port1_bank_ready | port2_bank_ready | port3_bank_ready))
				begin
					sdram_cmd <= SDRAM_CMD_ACTIVE;	//send activate command
					mark_flag <= 1'b1;
				end
				else
					sdram_cmd <= SDRAM_CMD_NOP;

				if(port1_bank_ready | port2_bank_ready | port3_bank_ready)
				begin
					if(port1_bank_ready | port2_bank_ready)
					begin
						if(port1_bank_ready)
						begin
							sdram_ba <= p1_address[3:2];	//set bank
							//sdram_a[12:0] <= p1_address[23:11];	//set row
							sdram_a[11:0] <= p1_address[21:10];	//set row
						end
						else	//port2_bank_ready
						begin
							sdram_ba <= p2_address[3:2];	//set bank
							//sdram_a[12:0] <= p2_address[23:11];	//set row
							sdram_a[11:0] <= p2_address[21:10];	//set row
						end
					end
					else	//port3_bank_ready
					begin
						sdram_ba <= p3_address[3:2];	//set bank
						//sdram_a[12:0] <= p3_address[23:11];	//set row
						sdram_a[11:0] <= p3_address[21:10];	//set row
					end
				end
			end
			S_CMD_READ_P1:
			begin
				if(current_active && io_state == S_IO_IDLE)
				begin
					sdram_cmd <= SDRAM_CMD_READ;
					sdram_a[11] <= 1'b0;
					sdram_a[10] <= 1'b1;	//automatic precharge
					sdram_a[9:8] <= 2'b00;
					//sdram_a[8:0] <= {p1_address[10:4], p1_address[1:0]};
					sdram_a[7:0] <= {p1_address[9:4], p1_address[1:0]};
					sdram_dqm <= 2'b00;
					cmd_state <= S_CMD_ACTIVATE;
				end
			end
			S_CMD_READ_P2:
			begin
				if(current_active && io_state == S_IO_IDLE)
				begin
					sdram_cmd <= SDRAM_CMD_READ;
					sdram_a[11] <= 1'b0;
					sdram_a[10] <= 1'b1;	//automatic precharge
					sdram_a[9:8] <= 2'b00;
					//sdram_a[8:0] <= {p2_address[10:4], p2_address[1:0]};
					sdram_a[7:0] <= {p2_address[9:4], p2_address[1:0]};
					sdram_dqm <= 2'b00;
					cmd_state <= S_CMD_ACTIVATE;
				end
			end
			S_CMD_READ_P3:
			begin
				if(current_active && io_state == S_IO_IDLE)
				begin
					sdram_cmd <= SDRAM_CMD_READ;
					sdram_a[11] <= 1'b0;
					sdram_a[10] <= 1'b1;	//automatic precharge
					sdram_a[9:8] <= 2'b00;
					//sdram_a[8:0] <= {p3_address[10:4], p3_address[1:0]};
					sdram_a[7:0] <= {p3_address[9:4], p3_address[1:0]};
					sdram_dqm <= 2'b00;
					cmd_state <= S_CMD_ACTIVATE;
				end
			end
			S_CMD_WRITE_P2_NOP:
			begin
				if(current_active && io_state == S_IO_IDLE)
				begin
					cmd_state <= S_CMD_WRITE_P2;
				end
			end
			S_CMD_WRITE_P2:
			begin
				sdram_cmd <= SDRAM_CMD_WRITE;
				sdram_a[11] <= 1'b0;
				sdram_a[10] <= 1'b1;	//automatic precharge
				sdram_a[9:8] <= 2'b00;
				//sdram_a[8:0] <= {p2_address[10:4], p2_address[1:0]};
				sdram_a[7:0] <= {p2_address[9:4], p2_address[1:0]};
				gate_out <= 1'b1;
				sdram_dqm <= 2'b00;
				cmd_state <= S_CMD_ACTIVATE;
			end
			S_CMD_WRITE_P3_NOP:
			begin
				if(current_active && io_state == S_IO_IDLE)
				begin
					cmd_state <= S_CMD_WRITE_P3;
				end
			end
			S_CMD_WRITE_P3:
			begin
				sdram_cmd <= SDRAM_CMD_WRITE;
				sdram_a[11] <= 1'b0;
				sdram_a[10] <= 1'b1;	//automatic precharge
				sdram_a[9:8] <= 2'b00;
				//sdram_a[8:0] <= {p3_address[10:4], p3_address[1:0]};
				sdram_a[7:0] <= {p3_address[9:4], p3_address[1:0]};
				gate_out <= 1'b1;
				sdram_dqm <= 2'b00;
				cmd_state <= S_CMD_ACTIVATE;
			end
			S_CMD_REFRESH:
			begin
				if(~(bank0_active | bank1_active | bank2_active | bank3_active))
				begin
					sdram_cmd <= SDRAM_CMD_REFRESH;
					cmd_state <= S_CMD_REFRESH_NOP1;
				end	
			end
			S_CMD_REFRESH_NOP1:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				cmd_state <= S_CMD_REFRESH_NOP2;
			end
			S_CMD_REFRESH_NOP2:
			begin
				cmd_state <= S_CMD_REFRESH_NOP3;
			end
			S_CMD_REFRESH_NOP3:
			begin
				cmd_state <= S_CMD_REFRESH_NOP4;
			end
			S_CMD_REFRESH_NOP4:
			begin
				cmd_state <= S_CMD_REFRESH_NOP5;
			end
			S_CMD_REFRESH_NOP5:
			begin
				if(~(|init_refresh_count))
					refresh_flag <= 1'b0;
				else
					init_refresh_count <= init_refresh_count - 3'b001;
				if(init_flag)
					cmd_state <= S_CMD_INIT_DATA;
				else
					cmd_state <= S_CMD_ACTIVATE;
			end
			S_CMD_INIT_DATA:
			begin
				if(refresh_flag)
				begin
					cmd_state <= S_CMD_REFRESH;
				end
				else
				begin
					init_req <= 1'b1;
					cmd_state <= S_CMD_INIT_READ;
				end
			end
			S_CMD_INIT_READ:
			begin
				init_req <= 1'b0;
				if(init_ready)
				begin
					init_offset <= init_offset + 2'b01;
					init_data_hold[init_offset] <= init_data;
					if(&init_offset)
						cmd_state <= S_CMD_WRITE_ACTIVATE;
					else
						cmd_state <= S_CMD_INIT_DATA;
				end
			end
			S_CMD_WRITE_ACTIVATE:
			begin
				sdram_cmd <= SDRAM_CMD_ACTIVE;	//send activate command
				sdram_ba <= init_base[1:0];	//set bank
				//sdram_a[12:0] <= {12'h000, init_base[9]};	//set row
				sdram_a[11:0] <= {10'h000, init_base[9:8]};	//set row
				cmd_state <= S_CMD_WRITE_ACTIVATE_NOP;
			end
			S_CMD_WRITE_ACTIVATE_NOP:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				burst_offset <= 2'b00;
				cmd_state <= S_CMD_INIT_WRITE;
			end
			S_CMD_INIT_WRITE:
			begin
				if(|burst_offset)
					sdram_cmd <= SDRAM_CMD_NOP;
				else
					sdram_cmd <= SDRAM_CMD_WRITE;
				sdram_a[11] <= 1'b0;
				sdram_a[10] <= 1'b1;	//automatic precharge
				sdram_a[9:8] <= 2'b00;
				//sdram_a[8:0] <= {init_base[8:2], 2'b00};	//set col
				sdram_a[7:0] <= {init_base[7:2], 2'b00};	//set col
				sdram_dqm <= 2'b00;
				gate_out <= 1'b1;
				data_out <= init_data_hold[burst_offset];
				burst_offset <= burst_offset + 2'b01;
				if(&burst_offset)
					cmd_state <= S_CMD_INC;
			end
			S_CMD_INC:
			begin
				sdram_cmd <= SDRAM_CMD_NOP;
				init_base <= init_base + 10'h001;
				if(init_base == 10'h3FF)
				begin
					init_flag <= 1'b0;
					cmd_state <= S_CMD_ACTIVATE;
				end
				else
				begin
					cmd_state <= S_CMD_INIT_DATA;
				end
			end
			default: ;
		endcase // cmd_state
	end
end

assign p1_ready = p1_ready_reg;
assign p2_ready = ((cmd_state == S_CMD_WRITE_P2_NOP) & current_active & (io_state == S_IO_IDLE)) | p2_ready_reg;
assign p3_ready = ((cmd_state == S_CMD_WRITE_P3_NOP) & current_active & (io_state == S_IO_IDLE)) | p3_ready_reg;

assign sdram_cke = 1'b1;
assign sdram_cs_n = 1'b0;
assign {sdram_ras_n, sdram_cas_n, sdram_wre_n} = sdram_cmd;
assign sdram_dq = gate_out ? data_out : 16'hZZZZ;
assign init_address = {init_base, init_offset};

endmodule : SDRAM_TP16_I
