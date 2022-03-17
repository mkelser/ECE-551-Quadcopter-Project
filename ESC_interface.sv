module ESC_interface(clk, rst_n, wrt, SPEED, PWM);

input clk;			                 // 50 MHz system clock
input rst_n;			               // active low asynchronous clock
input wrt;			                 // initiates new pulse and synch with PD control
input [10:0] SPEED;		         // result from flight controller
output reg PWM;			                // output to the ESC to control motor speed
 
reg [12:0] spd_prd;           // register for the speed period
reg [12:0] spd_prd_int;
reg [10:0] SPEED_int;	      // register for speed ff	
reg [13:0] pls_prd;           // register for the pulse period
reg [13:0] pls_prd_int;       // register for the pulse period
reg [13:0] pls_cnt;           // register for pulse counter to use for PWM
logic rst;                    // flag to reset the PWM signal

//Speed ff
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		SPEED_int <= 11'h0;
	end
	else begin
		SPEED_int <= SPEED;
	end
end

// continuously assign the period of clock cycles from the speed
assign spd_prd = SPEED_int * 2'b11;

//spd_prd ff
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		spd_prd_int <= 14'h0;
	end
	else begin
		spd_prd_int <= spd_prd;
	end
end

// continuously assign the period of clock cycles for the overall pulse
assign pls_prd = spd_prd_int + 6250;

//pls_prd ff
/*always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		pls_prd_int <= 14'h0;
	end
	else begin
		pls_prd_int <= pls_prd;
	end
end*/
// continuously assign reset to check the pulse counter to send the PWM low
assign rst = ~|pls_cnt[13:0];
	
// flip flop for pulse as a down counter
always_ff @(posedge clk, negedge rst_n) begin
   if (!rst_n)
      pls_cnt <= 0;
   else if (wrt)
      pls_cnt <= pls_prd;
   else
      pls_cnt <= pls_cnt - 1;
end

// SR flip flop for PWM to prevent glitching
always_ff @(posedge clk, negedge rst_n) begin
   if (!rst_n)
      PWM <= 0;
   else if (rst)
      PWM <= 0;
   else if (wrt)
      PWM <= 1;
end

endmodule
