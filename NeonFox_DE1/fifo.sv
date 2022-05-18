module queue_16_16(input logic clk, reset, push, pop, output logic full, empty, input logic[15:0] din, output logic[15:0] dout);
logic[3:0] read_addr;
logic[3:0] write_addr;
logic prev_push;
logic prev_pop;
logic addr_comp;
(* ramstyle = "logic" *) reg[15:0] queue_mem[15:0];

assign addr_comp = |(read_addr ^ write_addr);

initial
begin
	read_addr = 4'h0;
	write_addr = 4'h0;
	full = 1'b0;
	empty = 1'b1;
end

always @(posedge clk)
begin
	prev_push <= push;
	prev_pop <= pop;
	dout <= queue_mem[read_addr];
	if(reset)
	begin
		read_addr <= 4'h0;
		write_addr <= 4'h0;
		full <= 1'b0;
		empty <= 1'b1;
	end
	else
	begin
		if(push)
		begin
			write_addr <= write_addr + 4'h01;
			queue_mem[write_addr] <= din;
		end
		if(pop)
		begin
			read_addr <= read_addr + 4'h01;
		end
		if(addr_comp)
		begin
			full <= 1'b0;
			empty <= 1'b0;
		end
		else
		begin
			if(prev_push & ~prev_pop)
				full <= 1'b1;
			if(prev_pop & ~prev_push)
				empty <= 1'b1;
		end
	end
end
endmodule

module queue_16_4(input logic clk, reset, push, pop, output logic full, empty, input logic[15:0] din, output logic[15:0] dout);
logic[1:0] read_addr;
logic[1:0] write_addr;
logic prev_push;
logic prev_pop;
logic addr_comp;
(* ramstyle = "logic" *) reg[15:0] queue_mem[3:0];

assign addr_comp = |(read_addr ^ write_addr);

initial
begin
	read_addr = 2'h0;
	write_addr = 2'h0;
	full = 1'b0;
	empty = 1'b1;
end

always @(posedge clk)
begin
	prev_push <= push;
	prev_pop <= pop;
	dout <= queue_mem[read_addr];
	if(reset)
	begin
		read_addr <= 2'h0;
		write_addr <= 2'h0;
		full <= 1'b0;
		empty <= 1'b1;
	end
	else
	begin
		if(push)
		begin
			write_addr <= write_addr + 2'h01;
			queue_mem[write_addr] <= din;
		end
		if(pop)
		begin
			read_addr <= read_addr + 2'h01;
		end
		if(addr_comp)
		begin
			full <= 1'b0;
			empty <= 1'b0;
		end
		else
		begin
			if(prev_push & ~prev_pop)
				full <= 1'b1;
			if(prev_pop & ~prev_push)
				empty <= 1'b1;
		end
	end
end
endmodule
