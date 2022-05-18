module DE1_flash_controller(
		input wire clk,
		input wire rst,
		//Read port
		input wire read_req,
		output wire read_ready,
		input wire[20:0] read_addr,
		output wire[15:0] read_data,
		//Flash interface
		output wire[21:0] flash_a,
		input wire[7:0] flash_d,
		output wire flash_we_n,
		output wire flash_reset_n,
		output wire flash_ce_n,
		output wire flash_oe_n);
		
	reg[2:0] clk_count;
	reg fsm_clk;
	reg[8:0] reset_timer;
	reg fsm_reset;
	
	reg req_flag;
	reg ready_flag;
	reg[15:0] data_hold;
	
	enum logic[3:0]
	{
		S_IDLE,
		S_READ_LOW,
		S_READ_HIGH
	} state;
	
	assign flash_a = {read_addr[20:0], (state == S_READ_HIGH)};
	assign flash_we_n = 1'b1;
	assign flash_reset_n = ~fsm_reset;
	assign flash_ce_n = 1'b0;
	assign flash_oe_n = (state == S_IDLE);
	assign read_ready = ready_flag;
	assign read_data = data_hold;
	
	always @(posedge clk or posedge rst)
	begin
		if(rst)
		begin
			clk_count <= 3'h0;
			fsm_clk <= 1'b0;
			reset_timer <= 9'h000;
			fsm_reset <= 1'b1;
			req_flag <= 1'b0;
			ready_flag <= 1'b0;
		end
		else
		begin
			clk_count <= clk_count + 3'h1;
			fsm_clk <= 1'b0;
			if(clk_count == 3'h4)
			begin
				clk_count <= 3'h0;
				fsm_clk <= 1'b1;
			end
			
			reset_timer <= reset_timer + 9'h001;
			if(reset_timer == 9'd500)
			begin
				fsm_reset <= 1'b0;
			end
			
			req_flag <= req_flag | read_req;
			ready_flag <= 1'b0;
			if((state == S_READ_HIGH) & fsm_clk)
			begin
				req_flag <= 1'b0;
				ready_flag <= 1'b1;
			end
		end
	end
	
	always_ff @(posedge clk)
	begin
		if(fsm_reset)
		begin
			state <= S_IDLE;
		end
		else if(fsm_clk)
		begin
			case(state)
				S_IDLE:
				begin
					if(req_flag | read_req)
					begin
						state <= S_READ_LOW;
					end
				end
				S_READ_LOW:
				begin
					data_hold[7:0] <= flash_d;
					state <= S_READ_HIGH;
				end
				S_READ_HIGH:
				begin
					data_hold[15:8] <= flash_d;
					state <= S_IDLE;
				end
				default: ;
			endcase
		end
	end
		
endmodule
