// Memory Subsystem Control Unit
module MSC(
			input wire clk,
			input wire rst,
			input wire wren,
			input wire[1:0] A,
			input wire[7:0] data,
			output wire[6:0] p1_page,
			output wire[7:0] p2_page,
			output wire p1_reset,
			output wire p1_prefetch,
			output wire p2_reset,
			output wire p2_flush,
			output wire p2_prefetch,
			input wire p2_req,
			input wire p1_req,
			input wire p2_ready,
			input wire p1_ready);
// Address map
//	0x0 program space control register
//		bit0	reset bit
//		bit1	reserved
//		bit2	prefetch bit
//		bit3	control enable bit
//	0x1 program space page register
//	0x2 data space control register
//		bit0	reset bit
//		bit1	flush bit
//		bit2	prefetch bit
//		bit3	control enable bit
// 0x3 data space page register

reg[6:0] program_page;
reg[7:0] data_page;
reg p1_control_enable;
reg p2_control_enable;
reg p1_reset_reg;
reg prev_p1_reset_reg;
reg p1_prefetch_reg;
reg prev_p1_prefetch_reg;
reg p2_reset_reg;
reg prev_p2_reset_reg;
reg p2_flush_reg;
reg prev_p2_flush_reg;
reg p2_prefetch_reg;
reg prev_p2_prefetch_reg;

reg prev_p2_req;
reg prev_p1_req;
reg p2_active;
reg p1_active;
reg prev_p1_ready;
reg prev_p2_ready;
reg p1_reset_req;
reg p1_prefetch_req;
reg p2_reset_req;
reg p2_flush_req;
reg p2_prefetch_req;

wire p2_idle;
wire p1_idle;

assign p2_idle = ~(p2_active | p2_req) | (~p2_ready & prev_p2_ready);	//not active and not requesting or transaction done
assign p1_idle = ~(p1_active | p1_req) | (~p1_ready & prev_p1_ready);

always @(posedge clk or posedge rst)
begin
	if(rst)
	begin
		prev_p2_req <= 1'b0;
		prev_p1_req <= 1'b0;
		p2_active <= 1'b0;
		p1_active <= 1'b0;
		prev_p1_ready <= 1'b1;
		prev_p2_ready <= 1'b1;
		p1_reset_req <= 1'b1;
		p1_prefetch_req <= 1'b0;
		p2_reset_req <= 1'b1;
		p2_flush_req <= 1'b0;
		p2_prefetch_req <= 1'b0;
	end
	else
	begin
		prev_p2_req <= p2_req;
		prev_p1_req <= p1_req;
		prev_p1_ready <= p1_ready;
		prev_p2_ready <= p2_ready;
		if(p2_req & ~prev_p2_req)
			p2_active <= 1'b1;
		if(~p2_ready & prev_p2_ready)
			p2_active <= 1'b0;
		if(p1_req & ~prev_p1_req)
			p1_active <= 1'b1;
		if(~p1_ready & prev_p1_ready)
			p1_active <= 1'b0;
		
		if(p1_reset_reg & ~prev_p1_reset_reg)
			p1_reset_req <= 1'b1;
		if(p1_reset)
			p1_reset_req <= 1'b0;
		if(p1_prefetch_reg & ~prev_p1_prefetch_reg)
			p1_prefetch_req <= 1'b1;
		if(p1_prefetch)
			p1_prefetch_req <= 1'b0;
		if(p2_reset_reg & ~prev_p2_reset_reg)
			p2_reset_req <= 1'b1;
		if(p2_reset)
			p2_reset_req <= 1'b0;
		if(p2_flush_reg & ~prev_p2_flush_reg)
			p2_flush_req <= 1'b1;
		if(p2_flush)
			p2_flush_req <= 1'b0;
		if(p2_prefetch_reg & ~prev_p2_prefetch_reg)
			p2_prefetch_req <= 1'b1;
		if(p2_prefetch)
			p2_prefetch_req <= 1'b0;
	end
end

always @(posedge clk or posedge rst)
begin
	if(rst)
	begin
		program_page <= 0;
		data_page <= 0;
		p1_control_enable <= 1'b0;
		p2_control_enable <= 1'b0;
		p1_reset_reg <= 1'b0;
		prev_p1_reset_reg <= 1'b0;
		p1_prefetch_reg <= 1'b0;
		prev_p1_prefetch_reg <= 1'b0;
		p2_reset_reg <= 1'b0;
		prev_p2_reset_reg <= 1'b0;
		p2_flush_reg <= 1'b0;
		prev_p2_flush_reg <= 1'b0;
		p2_prefetch_reg <= 1'b0;
		prev_p2_prefetch_reg <= 1'b0;
	end
	else
	begin
		prev_p1_reset_reg <= p1_reset_reg;
		prev_p1_prefetch_reg <= p1_prefetch_reg;
		prev_p2_reset_reg <= p2_reset_reg;
		prev_p2_flush_reg <= p2_flush_reg;
		prev_p2_prefetch_reg <= p2_prefetch_reg;
		if(wren)
		begin
			case(A)
			2'b00:
			begin
				p1_control_enable <= data[3];
				if(p1_control_enable)
				begin
					p1_reset_reg <= data[0];
					p1_prefetch_reg <= data[2];
				end
			end
			2'b01:
			begin
				if(p1_control_enable)
					program_page <= data[6:0];
			end
			2'b10:
			begin
				p2_control_enable <= data[3];
				if(p2_control_enable)
				begin
					p2_reset_reg <= data[0];
					p2_flush_reg <= data[1];
					p2_prefetch_reg <= data[2];
				end
			end
			2'b11:
			begin
				if(p2_control_enable)
					data_page <= data[7:0];
			end
			endcase
		end
		else
		begin
			p1_reset_reg <= 1'b0;
			p1_prefetch_reg <= 1'b0;
			p2_reset_reg <= 1'b0;
			p2_flush_reg <= 1'b0;
			p2_prefetch_reg <= 1'b0;
		end
	end
end

assign p1_page = program_page;
assign p2_page = data_page;
assign p1_reset = (p1_reset_req & p1_idle) | rst;
assign p1_prefetch = p1_prefetch_req & p1_idle;
assign p2_reset = (p2_reset_req & p2_idle) | rst;
assign p2_flush = p2_flush_req & p2_idle;
assign p2_prefetch = p2_prefetch_req & p2_idle;

endmodule
