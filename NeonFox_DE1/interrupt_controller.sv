module interrupt_controller(
		input logic clk,
		input logic rst,
		input logic ce,
		input logic wren,
		input logic in0, in1, in2, in3, in4, in5, in6, in7,
		input logic ri_addr,
		input logic[7:0] from_cpu,
		output logic[7:0] to_cpu,
		output logic[2:0] int_addr,
		output logic int_rq);
logic[7:0] status;		// status[i]  = 1 where trig[i] = 1 (and hasn't had status[i] flag cleared yet)
logic[7:0] control;		// control[i] = 1	where an interrupt is able to be triggered 
logic[7:0] in;				// in[i] 	  = 1 where an interrupt is requesting its trigger
logic[7:0] prev_in;		// prev_in[i] = 1 for clock cycle n+1 where in[i] = 1 for clock cycle n (similarly for prev_in[i] = 0)
logic[7:0] trig;			// trig[i] 	  = 1 where an interrupt was requested, it is enabled, and prev_in[i] != 1 
logic[7:0] interrupt;
logic[3:0] timer;
logic suspend;

assign in = {in7, in6, in5, in4, in3, in2, in1, in0};
assign trig = in & ~prev_in;
assign interrupt = control & status;
assign suspend = |timer;

always_ff @(posedge clk)
begin
	if(rst)
	begin
		status <= 8'h00;
		control <= 8'h00;
		prev_in <= 8'hff;
		timer <= 4'h0;
	end
	else
	begin
		prev_in <= in;
		
		if(suspend)
			timer <= timer - 4'h1;
			
		if(ce & wren & ri_addr)
			control <= from_cpu;
		if(ce & wren & ~ri_addr)
		begin
			status <= status & from_cpu;
			timer <= 4'hf;
		end
		else
			status <= status | trig;
			
		if(ce)
		begin
			if(ri_addr)
				to_cpu <= control;
			else
				to_cpu <= status;
		end
		
		int_rq <= ~suspend & (|interrupt);
		if(|interrupt[3:0])
		begin
			if(interrupt[0])
				int_addr <= 3'h0;
			else if(interrupt[1])
				int_addr <= 3'h1;
			else if(interrupt[2])
				int_addr <= 3'h2;
			else
				int_addr <= 3'h3;
		end
		else
		begin
			if(interrupt[4])
				int_addr <= 3'h4;
			else if(interrupt[5])
				int_addr <= 3'h5;
			else if(interrupt[6])
				int_addr <= 3'h6;
			else
				int_addr <= 3'h7;
		end
	end
end

endmodule
