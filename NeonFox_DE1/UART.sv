module UART(
			input logic clk,
			input logic reset,
			input logic tx_req,
			input logic[7:0] tx_data,
			input logic rx,
			output logic tx,
			output logic[7:0] rx_data,
			output logic tx_ready,
			output logic rx_ready);
logic[8:0] rx_timer;
logic[9:0] rx_frame;
logic rx_active;
logic[8:0] tx_timer;
logic[9:0] tx_frame;
logic tx_active;
logic rx_time;
logic tx_time;
logic rx_s;
logic prev_tx_req;

assign tx_time = (tx_timer == 9'd434);	//115200 baud at 50MHz system clock.
assign rx_time = (rx_timer == 9'd434);
assign tx = tx_frame[0];

initial
begin
	rx_s = 1'b1;
	rx_frame = 10'b1111111111;
end

always @(posedge clk)
begin
	rx_s <= rx;
	prev_tx_req <= tx_req;
	if(reset)
	begin
		rx_timer <= 0;
		rx_active <= 0;
		tx_active <= 0;
		tx_timer <= 0;
		tx_ready <= 0;
		rx_ready <= 0;
		rx_data <= 0;
		tx_frame <= 10'b1111111111;
		rx_frame <= 10'b1111111111;
	end
	else
	begin
		if(rx_active)
		begin
			if(rx_time)
			begin
				rx_timer <= 0;
				rx_frame <= {rx_s, rx_frame[9:1]};
			end
			else
				rx_timer <= rx_timer + 9'h01;
		end
		else
		begin
			rx_timer <= 9'd217;	//half period 115200 baud at 50MHz system clock.
			rx_frame <= 10'b1111111111;
		end
		if(~rx_s)	//detect start bit
			rx_active <= 1'b1;
		if(~rx_frame[0] & rx_active)
		begin
			rx_active <= 1'b0;
			rx_ready <= 1'b1;
			rx_data <= rx_frame[8:1];
		end
		else
			rx_ready <= 1'b0;
			
		if(tx_active)
		begin
			if(tx_time)
			begin
				tx_timer <= 0;
				tx_frame <= {1'b0, tx_frame[9:1]};
			end
			else
				tx_timer <= tx_timer + 9'h01;
		end
		else
		begin
			tx_timer <= 0;
			tx_frame <= 10'b1111111111;
		end
		if(tx_req & (~prev_tx_req))
		begin
			tx_active <= 1'b1;
			tx_frame <= {1'b1, tx_data, 1'b0};
		end
		if((tx_frame[9:1] == 9'h00) && tx_time)
		begin
			tx_active <= 1'b0;
			tx_frame <= 10'b1111111111;
			tx_ready <= 1'b1;
		end
		else
			tx_ready <= 1'b0;
	end
end

endmodule
