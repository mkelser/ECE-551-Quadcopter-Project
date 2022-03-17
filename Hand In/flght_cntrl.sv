module flght_cntrl(clk, rst_n, vld, inertial_cal, d_ptch, d_roll, d_yaw,
                   ptch, roll, yaw, thrst, frnt_spd, bck_spd, lft_spd, rght_spd);

input clk;                       // 50 MHz system clock
input rst_n;					                // active low asynchronous reset
input vld;					                  // tells when a new valid inertial reading read
input inertial_cal;				          // need to run motors at CAL_SPEED
input signed [15:0] d_ptch;      // desired ptch
input signed [15:0] d_roll;			   // desired roll
input signed [15:0] d_yaw;			    // desired yaw
input [15:0] ptch;				           // actual pitch
input [15:0] roll;				           // actual roll
input [15:0] yaw; 				           // actual yaw
input [8:0] thrst;				           // thrust level from slider
output [10:0] frnt_spd;				      // 11-bit unsigned speed at which to run front motor
output [10:0] bck_spd;				       // 11-bit unsigned speed at which to back front motor
output [10:0] lft_spd;				       // 11-bit unsigned speed at which to left front motor
output [10:0] rght_spd;				      // 11-bit unsigned speed at which to right front motor

// speed to run motors at during inertial calibration
localparam CAL_SPEED = 11'h290;
// minimum speed while running
localparam MIN_RUN_SPEED = 13'h2C0;  

// pterm values to retain data from PD_Math DUT
logic [9:0] ptch_pterm;
logic [9:0] roll_pterm;
logic [9:0] yaw_pterm;

// dterm values to retain data from PD_Math DUT
logic [11:0] ptch_dterm;
logic [11:0] roll_dterm;
logic [11:0] yaw_dterm;

// 13 bit values for speed to avoid summation overflow
logic [12:0] frnt_spd_fat;
logic [12:0] bck_spd_fat;
logic [12:0] lft_spd_fat;
logic [12:0] rght_spd_fat;

// 11 bit saturated values assigned to the speed of the motors
logic [10:0] frnt_spd_sat;
logic [10:0] bck_spd_sat;
logic [10:0] lft_spd_sat;
logic [10:0] rght_spd_sat;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// instantiation of 3 copies of PD_math for each inertial component to calculate pterm and dterm from actual and desired //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
PD_math iPTCH(.clk(clk), .rst_n(rst_n), .vld(vld), .desired(d_ptch), .actual(ptch), .pterm(ptch_pterm), .dterm(ptch_dterm));
PD_math iROLL(.clk(clk), .rst_n(rst_n), .vld(vld), .desired(d_roll), .actual(roll), .pterm(roll_pterm), .dterm(roll_dterm));
PD_math iYAW(.clk(clk), .rst_n(rst_n), .vld(vld), .desired(d_yaw), .actual(yaw), .pterm(yaw_pterm), .dterm(yaw_dterm));

/////////////////////////////////////////////////////////////////////////////////////////////////////
//     continuously assign each directional speed based on this formula (I-term not included) :   //
// speed = thrst + MIN_RUN_SPEED +- first_pterm +- first_dterm +- second_pterm +- second_dterm   //
//   note that thrust, pterm, & dterm are signed numbers and thrust is sign extended as well    //
/////////////////////////////////////////////////////////////////////////////////////////////////
 
assign frnt_spd_fat =
		({4'b0000, thrst}) + 
		MIN_RUN_SPEED -
		({{3{ptch_pterm[9]}}, ptch_pterm}) - 
		({{ptch_dterm[11]}, ptch_dterm}) -
		({{3{yaw_pterm[9]}}, yaw_pterm}) -
		({{yaw_dterm[11]}, yaw_dterm});

assign bck_spd_fat = 
		({4'b0000, thrst}) +
		MIN_RUN_SPEED +
		({{3{ptch_pterm[9]}}, ptch_pterm}) +
		({{ptch_dterm[11]}, ptch_dterm}) -
		({{3{yaw_pterm[9]}}, yaw_pterm}) -
		({{yaw_dterm[11]}, yaw_dterm});

assign lft_spd_fat = 
		({4'b0000, thrst}) + 
		MIN_RUN_SPEED -
		({{3{roll_pterm[9]}}, roll_pterm}) - 
		({{roll_dterm[11]}, roll_dterm}) +
		({{3{yaw_pterm[9]}}, yaw_pterm}) +
		({{yaw_dterm[11]}, yaw_dterm});


assign rght_spd_fat = 
		({4'b0000, thrst}) + 
		MIN_RUN_SPEED +
		({{3{roll_pterm[9]}}, roll_pterm}) +
		({{roll_dterm[11]}, roll_dterm}) +
		({{3{yaw_pterm[9]}}, yaw_pterm}) +
		({{yaw_dterm[11]}, yaw_dterm});

// saturate all components to 11 bit to be assigned to the motor speed
assign frnt_spd_sat = |frnt_spd_fat[12:11] ? 11'b11111111111 : frnt_spd_fat[10:0];
assign bck_spd_sat = |bck_spd_fat[12:11] ? 11'b11111111111 : bck_spd_fat[10:0];
assign lft_spd_sat = |lft_spd_fat[12:11] ? 11'b11111111111 : lft_spd_fat[10:0];
assign rght_spd_sat = |rght_spd_fat[12:11] ? 11'b11111111111 : rght_spd_fat[10:0];

// if inertial_cal is asserted assign speed to CAL_SPEED otherwise the saturated speed
assign frnt_spd = inertial_cal ? CAL_SPEED : frnt_spd_sat;
assign bck_spd = inertial_cal ? CAL_SPEED : bck_spd_sat;
assign lft_spd = inertial_cal ? CAL_SPEED : lft_spd_sat;
assign rght_spd = inertial_cal ? CAL_SPEED : rght_spd_sat;

endmodule
