module ALU(
		input logic clk,
		input logic data_hazard,
		input logic set_cc, 
		input logic h_en, l_en,
		input logic[15:0] in_a, 
		input logic[15:0] in_b,
		input logic[7:0] I_field,
		input logic[3:0] alu_op,
		output logic[15:0] alu_out,
		output logic n, z, p, c);
logic[16:0] add_result;
logic[15:0] alu_result;
//logic c;
logic swap;
logic[15:0] bit_sel;
logic[7:0] immediate_high;
logic[7:0] immediate_low;

assign bit_sel = 16'h01 << I_field[3:0];
assign swap = ~h_en & ~l_en;
assign add_result = in_a + (in_b ^ {16{alu_op[0]}}) + (alu_op[3] ? c : alu_op[0]);
assign immediate_low = I_field;
assign immediate_high = ~l_en ? I_field : {8{I_field[7]}};	//if swap or high duplicate instead of sign extend

always_comb
begin
	case(alu_op[2:0])
		3'b000: alu_result = add_result[15:0];	//add, addc
		3'b001: alu_result = add_result[15:0];	//sub, subc
		3'b010: alu_result = in_a ^ {16{alu_op[3]}};	//move, not
		3'b011: alu_result = alu_op[3] ? {in_a[14:0], in_a[15]} : {in_a[0], in_a[15:1]};	//ror, rol
		3'b100: alu_result = in_a & in_b;	//and
		3'b101: alu_result = in_a ^ in_b;	//xor
		3'b110: alu_result = in_a | in_b;	//or
		3'b111: alu_result = alu_op[3] ? in_a : {immediate_high, immediate_low};	//alu nop, bitt TODO: remove this mux
	endcase // alu_op[2:0]
end
always_ff @(posedge clk)
begin
	if(~data_hazard)
	begin
		alu_out <= swap ? {alu_result[7:0], alu_result[15:8]} : alu_result;	//no need to mask bytes not enabled, the register file will ignore them.
	end
	if(~data_hazard & (alu_op[3] | ~(&alu_op[2:0]) | set_cc))	// not hazard and not alu nop or set_cc
	begin
		if(&alu_op[2:0])	//bitt
		begin
			n <= 1'b0;
			z <= ~(|(in_a & bit_sel));	//hardware for bitt need not care about h_en and l_en, this can be handled by the assembler.
			p <= 1'b0;
		end
		else if(~set_cc)	//normal alu ops
		begin
			n <= h_en ? alu_result[15] : alu_result[7];
			z <= ~( ((|alu_result[15:8]) & (h_en | swap)) | ((|alu_result[7:0]) & (l_en | swap)) );
			p <= ( ((|alu_result[15:8]) & (h_en | swap)) | ((|alu_result[7:0]) & (l_en | swap)) ) & ~(h_en ? alu_result[15] : alu_result[7]);
		end
		else	//set_cc
		begin
			n <= in_a[2];
			z <= in_a[1];
			p <= in_a[0];
		end
	end
	if(~data_hazard & (~(|alu_op[2:1]) | set_cc))	//not hazard and (add | addc | sub | subc) or set_cc
	begin
		if(set_cc)
		begin
			c <= in_a[3];
		end
		else
		begin
			c <= (h_en ? add_result[16] : add_result[8]);
		end
	end
end
endmodule : ALU
