module reset_synch(clk, RST_n, rst_n);
input clk, RST_n;
output reg rst_n;
reg rst_int, rst_in;

always_ff @(negedge clk, negedge RST_n) begin
	if(!RST_n) begin
		rst_int <= 1'b0;
	end
	else begin
		rst_int <= 1'b1;
	end
end

always_ff @(negedge clk, negedge RST_n) begin
	if(!RST_n) begin
		rst_in <= 1'b0;
	end
	else begin
		rst_in <= 1'b1;
	end
end

assign rst_n = rst_in;

endmodule
