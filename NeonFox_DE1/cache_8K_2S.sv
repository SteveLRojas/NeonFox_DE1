// 8KB 2-way set associative 16 bit
// write policy: writeback
// Fetch critical word first: yes
// Prefetch capability: manual, full cache
module cache_8K_2S_16(
		input logic clk,
		input logic rst,
		input logic flush,
		input logic prefetch,
		//output logic cache_miss,
		output logic write_miss,
		output logic read_miss,
		input logic CPU_wren,
		input logic CPU_ren,
		input logic[31:0] CPU_address,
		output logic[15:0] to_CPU,
		input logic[15:0] from_CPU,
		output logic[31:0] mem_address,
		input logic[15:0] from_mem,
		output logic[15:0] to_mem,
		input logic[1:0] mem_offset,
		output logic mem_req,
		output logic mem_wren,
		input logic mem_ready);

logic[8:0] tag_rdaddr;
logic[8:0] tag_wraddr;
logic[20:0] b1_tag_din;
logic[20:0] b1_tag_dout;
logic[20:0] b1_tag_hold;
logic[20:0] b2_tag_din;
logic[20:0] b2_tag_dout;
logic[20:0] b2_tag_hold;
logic[3:0] b1_valid_din;
logic[3:0] b1_valid_dout;
logic[3:0] b2_valid_din;
logic[3:0] b2_valid_dout;
logic b1_mod_din;
logic b1_mod_dout;
logic b2_mod_din;
logic b2_mod_dout;
logic b1_lru_din;
logic b1_lru_dout;
logic b2_lru_din;
logic b2_lru_dout;
logic b1_tag_en;
logic b2_tag_en;
logic tag_wren;

//logic[8:0] lru_rdaddr;
//logic[8:0] lru_wraddr;
//logic lru_din;
logic lru_dout;
//logic lru_wren;

logic[10:0] b1_addr_a;
logic[10:0] b1_addr_b;
logic[10:0] b2_addr_a;
logic[10:0] b2_addr_b;
logic[15:0] b1_din_a;
logic[15:0] b1_din_b;
logic[15:0] b1_dout_a;
logic[15:0] b1_dout_b;
logic[15:0] b2_din_a;
logic[15:0] b2_din_b;
logic[15:0] b2_dout_a;
logic[15:0] b2_dout_b;
logic b1_wren_a;
logic b1_wren_b;
logic b2_wren_a;
logic b2_wren_b;

logic[31:0] address_hold;
logic[31:0] prev_address;
//logic[15:0] prev_from_CPU;
logic[15:0] data_hold;
logic lru_hold;
logic[3:0] word_valid, next_word_valid;
logic[3:0] word_sel;
//logic prev_CPU_ren;
//logic prev_CPU_wren;
logic wren_hold;
logic b1_hit;
logic b2_hit;
logic miss;
//logic prev_miss;
logic hit;
logic prev_mem_ready;
logic mem_done;	//done transfering to/from main memory
logic address_change;	//address_hold changed on last clock rising edge
logic busy;
logic prev_cache_wren;

enum logic[3:0]
{
	S_INIT,
	S_PREFETCH,
	S_FLUSH,
	S_HIT,
	S_WRITEBACK_REQ,
	S_WRITEBACK_WAIT,
	S_WRITEBACK_TRANSFER,
	S_FETCH_REQ,
	S_FETCH_WAIT,
	S_FETCH_TRANSFER
} state;

always @(posedge clk)
begin
	//prev_from_CPU <= from_CPU;
	//prev_CPU_wren <= CPU_wren;
	//prev_CPU_ren <= CPU_ren;
	if(rst | flush | prefetch)
	begin
		state <= S_INIT;
		if(prefetch)
			state <= S_PREFETCH;
		if(flush)
			state <= S_FLUSH;
		address_hold <= 19'h0000;
		address_change <= 1'b1;
		prev_mem_ready <= 1'b0;
		busy <= 1'b1;
		word_valid <= 4'h0;
		wren_hold <= 1'b0;
	end
	else
	begin
		//if(state == S_HIT)
		if(mem_done)
			word_valid <= 4'h0;
		else
			word_valid <= next_word_valid;
		case(CPU_address[1:0])
			2'h0: word_sel <= 4'b0001;
			2'h1: word_sel <= 4'b0010;
			2'h2: word_sel <= 4'b0100;
			2'h3: word_sel <= 4'b1000;
		endcase
		prev_mem_ready <= mem_ready;
		prev_address <= CPU_address;
		prev_cache_wren <= b1_wren_a | b2_wren_a;
		//default values
		address_change <= 1'b0;
		busy <= 1'b0;
		case(state)
			S_INIT:	//clear lru, mod, tag, and valid
			begin
				address_hold <= address_hold + 32'h04;
				address_change <= 1'b1;
				busy <= 1'b1;
				if(&address_hold[10:2])
				begin
					state <= S_HIT;
					address_hold <= CPU_address;
				end
			end
			S_PREFETCH:
			begin
				if(mem_done)
				begin
					address_hold <= address_hold + 32'h04;
					address_change <= 1'b1;
					if(&address_hold[11:2])
					begin
						state <= S_HIT;
					end
				end
			end
			S_FLUSH:
			begin
				if(mem_done | (~address_change & ~(address_hold[11] ? b2_mod_dout : b1_mod_dout)))	//done transfering or data is not modified
				begin
					address_hold <= address_hold + 32'h04;
					address_change <= 1'b1;
					if(&address_hold[11:2])
					begin
						state <= S_INIT;
					end
				end
				busy <= 1'b1;
			end
			S_HIT:
			begin
				data_hold <= from_CPU;
				wren_hold <= CPU_wren;
				if(miss)
				begin
					if((lru_dout & b1_mod_dout) | (~lru_dout & b2_mod_dout))
						state <= S_WRITEBACK_REQ;
					else
						state <= S_FETCH_REQ;
					lru_hold <= lru_dout;
					b1_tag_hold <= b1_tag_dout;
					b2_tag_hold <= b2_tag_dout;
					//data_hold <= from_CPU;
					//wren_hold <= CPU_wren;
				end
				else
				begin
					address_hold <= CPU_address;
					address_change <= 1'b1;
				end
			end
			S_WRITEBACK_REQ:
			begin
				state <= S_WRITEBACK_WAIT;
			end
			S_WRITEBACK_WAIT:
			begin
				if(mem_ready)
					state <= S_WRITEBACK_TRANSFER;
			end
			S_WRITEBACK_TRANSFER:
			begin
				if(~mem_ready)
					state <= S_FETCH_REQ;
			end
			S_FETCH_REQ:
			begin
				state <= S_FETCH_WAIT;
			end
			S_FETCH_WAIT:
			begin
				if(mem_ready)
					state <= S_FETCH_TRANSFER;
			end
			S_FETCH_TRANSFER:
			begin
				if(~mem_ready)
				begin
					state <= S_HIT;
					address_hold <= CPU_address;
				end
			end
			default: ;
		endcase // state
	end
end

always_comb
begin
	mem_done = prev_mem_ready & ~mem_ready;
	b1_hit = (b1_tag_dout == prev_address[31:11]) & (|(b1_valid_dout & word_sel));
	b2_hit = (b2_tag_dout == prev_address[31:11]) & (|(b2_valid_dout & word_sel));
	miss = (~(b1_hit | b2_hit) & (CPU_wren | CPU_ren)) | busy;
	//cache_miss = miss | (CPU_wren & (state != S_HIT)) | prev_cache_wren;
	write_miss = CPU_wren & (~(b1_hit | b2_hit) | busy | (state != S_HIT));
	read_miss = CPU_ren & (~(b1_hit | b2_hit) | busy | prev_cache_wren);
	hit = (b1_hit | b2_hit) & (CPU_wren | CPU_ren);
	to_CPU = ({16{b1_hit}} & b1_dout_a) | ({16{b2_hit}} & b2_dout_a);
	b1_din_a = data_hold;
	b2_din_a = data_hold;
	b1_din_b = from_mem;
	b2_din_b = from_mem;
	b1_addr_a = wren_hold ? address_hold[10:0] : CPU_address[10:0];
	b2_addr_a = wren_hold ? address_hold[10:0] : CPU_address[10:0];
	tag_rdaddr = CPU_address[10:2];
	b1_addr_b = {address_hold[10:2], address_hold[1:0] ^ mem_offset};
	b2_addr_b = {address_hold[10:2], address_hold[1:0] ^ mem_offset};
	lru_dout = b1_lru_dout ^ b2_lru_dout;
	case(mem_offset)
		2'h0: next_word_valid = word_valid | 4'b0001;
		2'h1: next_word_valid = word_valid | 4'b0010;
		2'h2: next_word_valid = word_valid | 4'b0100;
		2'h3: next_word_valid = word_valid | 4'b1000;
	endcase
	case(state)
		S_INIT:	//clear lru, mod, tag, and valid
		begin
			mem_req = 1'b0;
			mem_wren = 1'bx;
			mem_address = 32'hxxxxxxxx;
			to_mem = 16'hxxxx;
			
			b1_wren_a = 1'b0;
			b2_wren_a = 1'b0;
			b1_wren_b = 1'b0;
			b2_wren_b = 1'b0;
			
			tag_wraddr = address_hold[10:2];
			b1_tag_din = 21'hxxxxxx;
			b2_tag_din = 21'hxxxxxx;
			b1_valid_din = 4'h0;
			b2_valid_din = 4'h0;
			b1_mod_din = 1'b0;
			b2_mod_din = 1'b0;
			b1_lru_din = 1'b1;	//LRU = 1, bank 1
			b2_lru_din = 1'b0;
			b1_tag_en = 1'b1;
			b2_tag_en = 1'b1;
			tag_wren = 1'b1;
		end
		S_PREFETCH:
		begin
			mem_req = ~mem_done;
			mem_wren = 1'b0;
			mem_address = address_hold[31:0];
			to_mem = 16'hxxxx;
			
			b1_wren_a = 1'b0;
			b2_wren_a = 1'b0;
			b1_wren_b = ~address_hold[11] & mem_ready;
			b2_wren_b = address_hold[11] & mem_ready;
			
			tag_wraddr = address_hold[10:2];
			b1_tag_din = address_hold[31:11];
			b2_tag_din = address_hold[31:11];
			b1_valid_din = next_word_valid;
			b2_valid_din = next_word_valid;
			b1_mod_din = 1'b0;
			b2_mod_din = 1'b0;
			b1_lru_din = 1'b1;	//LRU = 1
			b2_lru_din = 1'b0;
			b1_tag_en = ~address_hold[11];
			b2_tag_en = address_hold[11];
			tag_wren = mem_ready;
		end
		S_FLUSH:
		begin
			mem_req = ~mem_done & ~address_change & (address_hold[11] ? b2_mod_dout : b1_mod_dout);
			mem_wren = 1'b1;
			if(address_hold[11])
			begin
				mem_address = {b2_tag_dout[20:0], address_hold[10:0]};
				to_mem = b2_dout_b;
			end
			else
			begin
				mem_address = {b1_tag_dout[20:0], address_hold[10:0]};
				to_mem = b1_dout_b;
			end
			
			b1_wren_a = 1'b0;
			b2_wren_a = 1'b0;
			b1_wren_b = 1'b0;
			b2_wren_b = 1'b0;
			
			tag_wraddr = 9'hxxx;
			tag_rdaddr = address_hold[10:2];
			b1_tag_din = 21'hxxxxxx;
			b2_tag_din = 21'hxxxxxx;
			b1_valid_din = 1'bx;
			b2_valid_din = 1'bx;
			b1_mod_din = 1'bx;
			b2_mod_din = 1'bx;
			b1_lru_din = 1'bx;	//LRU = X
			b2_lru_din = 1'bx;
			b1_tag_en = 1'bx;
			b2_tag_en = 1'bx;
			tag_wren = 1'b0;	//tag, LRU not modified
		end
		S_HIT:
		begin
			//mem_req = miss;
			//mem_wren = (lru_dout & b1_mod_dout) | (~lru_dout & b2_mod_dout);	//writeback
			mem_req = 1'b0;
			mem_wren = 1'bx;
			mem_address = address_hold;
			to_mem = 16'hxxxx;
			
			b1_wren_a = wren_hold & b1_hit;
			b2_wren_a = wren_hold & b2_hit;
			b1_wren_b = 1'b0;
			b2_wren_b = 1'b0;
			
			tag_wraddr = prev_address[10:2];
			b1_tag_din = b1_tag_dout;
			b2_tag_din = b2_tag_dout;
			b1_valid_din = b1_valid_dout;
			b2_valid_din = b2_valid_dout;
			b1_mod_din = b1_mod_dout | (b1_hit & wren_hold);
			b2_mod_din = b2_mod_dout | (b2_hit & wren_hold);
			//if these are different the lru points to b1, else b2
			b1_lru_din = b2_lru_dout ^ b2_hit;	//LRU = b2_hit
			b2_lru_din = b1_lru_dout ^ b2_hit;
			b1_tag_en = b1_hit;
			b2_tag_en = b2_hit;
			tag_wren = hit;
		end
		S_WRITEBACK_REQ:
		begin
			mem_req = 1'b1;
			mem_wren = 1'b1;
			mem_address = lru_hold ? {b1_tag_hold[20:0], address_hold[10:0]} : {b2_tag_hold[20:0], address_hold[10:0]};
			to_mem = lru_hold ? b1_dout_b : b2_dout_b;
			
			//CPU writes during cache miss not supported for now (always miss)
			b1_wren_a = 1'b0;
			b2_wren_a = 1'b0;
			b1_wren_b = 1'b0;
			b2_wren_b = 1'b0;
			
			tag_wraddr = prev_address[10:2];
			b1_tag_din = b1_tag_dout;
			b2_tag_din = b2_tag_dout;
			b1_valid_din = b1_valid_dout;
			b2_valid_din = b2_valid_dout;
			b1_mod_din = b1_mod_dout;
			b2_mod_din = b2_mod_dout;
			//if these are different the lru points to b1, else b2
			b1_lru_din = b2_lru_dout ^ b2_hit;	//LRU = b2_hit
			b2_lru_din = b1_lru_dout ^ b2_hit;
			b1_tag_en = b1_hit;
			b2_tag_en = b2_hit;
			tag_wren = hit;
		end
		S_WRITEBACK_WAIT:
		begin
			mem_req = 1'b0;
			mem_wren = 1'b1;
			mem_address = lru_hold ? {b1_tag_hold[20:0], address_hold[10:0]} : {b2_tag_hold[20:0], address_hold[10:0]};
			to_mem = lru_hold ? b1_dout_b : b2_dout_b;
			
			//CPU writes during cache miss not supported for now (always miss)
			b1_wren_a = 1'b0;
			b2_wren_a = 1'b0;
			b1_wren_b = 1'b0;
			b2_wren_b = 1'b0;
			
			tag_wraddr = prev_address[10:2];
			b1_tag_din = b1_tag_dout;
			b2_tag_din = b2_tag_dout;
			b1_valid_din = b1_valid_dout;
			b2_valid_din = b2_valid_dout;
			b1_mod_din = b1_mod_dout;
			b2_mod_din = b2_mod_dout;
			//if these are different the lru points to b1, else b2
			b1_lru_din = b2_lru_dout ^ b2_hit;	//LRU = b2_hit
			b2_lru_din = b1_lru_dout ^ b2_hit;
			b1_tag_en = b1_hit;
			b2_tag_en = b2_hit;
			tag_wren = hit;
		end
		S_WRITEBACK_TRANSFER:
		begin
			//mem_req = ~mem_ready;
			//mem_wren = 1'b0;
			mem_req = 1'b0;
			mem_wren = 1'b1;
			mem_address = lru_hold ? {b1_tag_hold[20:0], address_hold[10:0]} : {b2_tag_hold[20:0], address_hold[10:0]};
			to_mem = lru_hold ? b1_dout_b : b2_dout_b;
			
			//CPU writes during cache miss not supported for now (always miss)
			b1_wren_a = 1'b0;
			b2_wren_a = 1'b0;
			b1_wren_b = 1'b0;
			b2_wren_b = 1'b0;
			
			tag_wraddr = prev_address[10:2];
			b1_tag_din = b1_tag_dout;
			b2_tag_din = b2_tag_dout;
			b1_valid_din = b1_valid_dout;
			b2_valid_din = b2_valid_dout;
			b1_mod_din = b1_mod_dout;
			b2_mod_din = b2_mod_dout;
			//if these are different the lru points to b1, else b2
			b1_lru_din = b2_lru_dout ^ b2_hit;	//LRU = b2_hit
			b2_lru_din = b1_lru_dout ^ b2_hit;
			b1_tag_en = b1_hit;
			b2_tag_en = b2_hit;
			tag_wren = hit;
		end
		S_FETCH_REQ:
		begin
			mem_req = 1'b1;
			mem_wren = 1'b0;
			mem_address = address_hold;
			to_mem = 16'hxxxx;
			
			//CPU writes during cache miss not supported for now (always miss)
			b1_wren_a = 1'b0;
			b2_wren_a = 1'b0;
			b1_wren_b = lru_hold & mem_ready;
			b2_wren_b = ~lru_hold & mem_ready;
			
			tag_wraddr = prev_address[10:2];
			b1_tag_din = b1_tag_dout;
			b2_tag_din = b2_tag_dout;
			b1_valid_din = b1_valid_dout;
			b2_valid_din = b2_valid_dout;
			b1_mod_din = b1_mod_dout;
			b2_mod_din = b2_mod_dout;
			//if these are different the lru points to b1, else b2
			b1_lru_din = b2_lru_dout ^ b2_hit;	//LRU = b2_hit
			b2_lru_din = b1_lru_dout ^ b2_hit;
			b1_tag_en = b1_hit;
			b2_tag_en = b2_hit;
			tag_wren = hit;
		end
		S_FETCH_WAIT:
		begin
			mem_req = 1'b0;
			mem_wren = 1'b0;
			mem_address = address_hold;
			to_mem = 16'hxxxx;
			
			//CPU writes during cache miss not supported for now (always miss)
			b1_wren_a = 1'b0;
			b2_wren_a = 1'b0;
			b1_wren_b = lru_hold & mem_ready;
			b2_wren_b = ~lru_hold & mem_ready;
			
			tag_wraddr = prev_address[10:2];
			b1_tag_din = b1_tag_dout;
			b2_tag_din = b2_tag_dout;
			b1_valid_din = b1_valid_dout;
			b2_valid_din = b2_valid_dout;
			b1_mod_din = b1_mod_dout;
			b2_mod_din = b2_mod_dout;
			//if these are different the lru points to b1, else b2
			b1_lru_din = b2_lru_dout ^ b2_hit;	//LRU = b2_hit
			b2_lru_din = b1_lru_dout ^ b2_hit;
			b1_tag_en = b1_hit;
			b2_tag_en = b2_hit;
			tag_wren = hit;
		end
		S_FETCH_TRANSFER:
		begin
			mem_req = 1'b0;
			mem_wren = 1'b0;
			mem_address = address_hold;
			to_mem = 16'hxxxx;
			
			//CPU writes during cache miss not supported for now (always miss)
			b1_wren_a = 1'b0;
			b2_wren_a = 1'b0;
			b1_wren_b = lru_hold & mem_ready;
			b2_wren_b = ~lru_hold & mem_ready;
			
			tag_wraddr = address_hold[10:2];
			b1_tag_din = address_hold[31:11];
			b2_tag_din = address_hold[31:11];
			b1_valid_din = next_word_valid;
			b2_valid_din = next_word_valid;
			b1_mod_din = 1'b0;
			b2_mod_din = 1'b0;
			//if these are different the lru points to b1, else b2
			b1_lru_din = b2_lru_dout ^ (~lru_hold);	//LRU = ~lru_hold
			b2_lru_din = b1_lru_dout ^ (~lru_hold);
			b1_tag_en = lru_hold;
			b2_tag_en = ~lru_hold;
			tag_wren = mem_ready;
		end
		default:
		begin
         mem_req = 1'bx;
			mem_wren = 1'bx;
			mem_address = 32'hxxxxxxxx;
			to_mem = 16'hxxxx;
			
			b1_wren_a = 1'bx;
			b2_wren_a = 1'bx;
			b1_wren_b = 1'bx;
			b2_wren_b = 1'bx;
			
			tag_wraddr = 9'hxxx;
			b1_tag_din = 21'hxxxxxx;
			b2_tag_din = 21'hxxxxxx;
			b1_valid_din = 4'hx;
			b2_valid_din = 4'hx;
			b1_mod_din = 1'bx;
			b2_mod_din = 1'bx;
			b1_lru_din = 1'bx;	//LRU = 1, bank 1
			b2_lru_din = 1'bx;
			b1_tag_en = 1'bx;
			b2_tag_en = 1'bx;
			tag_wren = 1'bx;
		end
	endcase	//state
end

C_2K_16 cache_1(
		.address_a(b1_addr_a),
		.address_b(b1_addr_b),
		.clock(clk),
		.data_a(b1_din_a),
		.data_b(b1_din_b),
		.wren_a(b1_wren_a),
		.wren_b(b1_wren_b),
		.q_a(b1_dout_a),
		.q_b(b1_dout_b));
		
C_2K_16 cache_2(
		.address_a(b2_addr_a),
		.address_b(b2_addr_b),
		.clock(clk),
		.data_a(b2_din_a),
		.data_b(b2_din_b),
		.wren_a(b2_wren_a),
		.wren_b(b2_wren_b),
		.q_a(b2_dout_a),
		.q_b(b2_dout_b));
		
		
T_512_54 tag_inst(
		.byteena_a({{3{b2_tag_en}}, {3{b1_tag_en}}}),
		.clock(clk),
		.data({b2_lru_din, b2_mod_din, b2_valid_din, b2_tag_din, b1_lru_din, b1_mod_din, b1_valid_din, b1_tag_din}),
		.rdaddress(tag_rdaddr),
		.wraddress(tag_wraddr),
		.wren(tag_wren),
		.q({b2_lru_dout, b2_mod_dout, b2_valid_dout, b2_tag_dout, b1_lru_dout, b1_mod_dout, b1_valid_dout, b1_tag_dout}));

endmodule : cache_8K_2S_16