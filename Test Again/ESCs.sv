module ESCs(clk, rst_n, frnt_spd, bck_spd, lft_spd, rght_spd, wrt, motors_off, frnt,bck, lft, rght);
input clk, rst_n, motors_off, wrt;
input [10:0] frnt_spd, bck_spd, lft_spd, rght_spd;
output frnt, bck, lft, rght;

// front, back, left, & right speeds for ESC_interface to create PWM
logic [10:0] f_spd, b_spd, l_spd, r_spd;                 

// if motors are off assign 0 to speed so no PWM is made
assign f_spd = (motors_off) ? 11'h000 : frnt_spd;         
assign b_spd = (motors_off) ? 11'h000 : bck_spd;
assign l_spd = (motors_off) ? 11'h000 : lft_spd;
assign r_spd = (motors_off) ? 11'h000 : rght_spd;

/////////////////////////////////////////////////////////////////////////////////////////////
// instantiaion of ESC that takes frnt_spd from flght_cntrl to create PWM for front motor //
///////////////////////////////////////////////////////////////////////////////////////////
ESC_interface iFRNT(.clk(clk), .rst_n(rst_n), .wrt(wrt), .SPEED(f_spd), .PWM(frnt));

///////////////////////////////////////////////////////////////////////////////////////////
// instantiaion of ESC that takes bck_spd from flght_cntrl to create PWM for back motor //
/////////////////////////////////////////////////////////////////////////////////////////
ESC_interface iBCK(.clk(clk), .rst_n(rst_n), .wrt(wrt), .SPEED(b_spd), .PWM(bck));

///////////////////////////////////////////////////////////////////////////////////////////
// instantiaion of ESC that takes lft_spd from flght_cntrl to create PWM for left motor //
/////////////////////////////////////////////////////////////////////////////////////////
ESC_interface iLFT(.clk(clk), .rst_n(rst_n), .wrt(wrt), .SPEED(l_spd), .PWM(lft));

/////////////////////////////////////////////////////////////////////////////////////////////
// instantiaion of ESC that takes rght_spd from flght_cntrl to create PWM for right motor //
///////////////////////////////////////////////////////////////////////////////////////////
ESC_interface iRGHT(.clk(clk), .rst_n(rst_n), .wrt(wrt), .SPEED(r_spd), .PWM(rght));

endmodule
