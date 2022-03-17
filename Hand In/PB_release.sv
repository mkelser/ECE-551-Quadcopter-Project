module PB_release(PB, clk, rst_n, released);
input PB, clk, rst_n;
output released;
reg PB_1, PB_2, PB_3; 

always@(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		PB_1 <= 1'b1;
		PB_2 <= 1'b1;
		PB_3 <= 1'b1;
	end
	else begin
		PB_1 <= PB;
		PB_2 <= PB_1;
		PB_3 <= PB_2;
	end
end

assign released = PB_2 & ~PB_3;
endmodule
