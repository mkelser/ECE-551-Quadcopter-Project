module PD_math(
input clk,
input rst_n,
input vld,
input [15:0] desired,
input [15:0] actual,
output signed [9:0] pterm,
output signed [11:0] dterm
);
	
	reg signed [16:0] err;
	reg signed [16:0] err_int;
	reg signed [9:0] err_sat;
	reg signed [9:0]prev_err[0:11];
	reg signed [10:0] d_diff;
	reg signed [6:0] d_diff_sat;
	reg signed [6:0] d_diff_sat_int;
	reg [4:0] i;
	localparam D_QUEUE_DEPTH = 12;
	localparam COEFF = 5'b00111;

	// get the error term
	assign err = ({{actual[15]}, actual}) - ({{desired[15]}, desired});
	
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) begin
			err_int <= 17'h0;
		end
		else begin
			err_int <= err;
		end
	end	

	// saturate error term
	assign err_sat = err_int[16] ? (&err_int[15:9] ? err_int[9:0] : 10'b1000000000) : (|err_int[15:9] ? 10'b0111111111 :  err_int[9:0]);

	// multiply the error term by 5/8s by shifting
	assign pterm = (err_sat >>> 1) + (err_sat >>> 3);
	
	// queue
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) begin
			prev_err[i] <= 10'h000;
		end
		else if (vld) begin
			for (i = 0; i < D_QUEUE_DEPTH; i++) begin
				if (i == 0) begin
					prev_err[i] <= err_sat;
				end
				//  otherwise if valid shift the previous error
				else begin
					prev_err[i] <= prev_err[i - 1];
				end
			end
		end
	end

	assign d_diff = err_sat - prev_err[D_QUEUE_DEPTH - 1];

	// saturate the differential term down to a 7-bit number
	assign d_diff_sat = d_diff[10] ? (&d_diff[9:6] ? d_diff[6:0] : 7'b1000000) : (|d_diff[9:6] ? 7'b0111111 : d_diff[6:0]);

	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) begin
			d_diff_sat_int <= 17'h0;
		end
		else begin
			d_diff_sat_int <= d_diff_sat;
		end
	end

	// multiply the differential term by a coeffecient
	assign dterm = d_diff_sat_int * $signed(COEFF);

endmodule
