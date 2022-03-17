module CycloneIV(clk,RST_n,SS_n,SCLK,MISO,MOSI,INT,frnt_ESC,back_ESC,left_ESC,rght_ESC);
  /////////////////////////////////////////////////
  // Model of a overall physics of quadcopter   //
  // including ST iNEMO 6-axis inertial device //
  // You will see some nasty stuff in here    //
  // that would never synthesize, but this   //
  // is not a block that gets synthesized   //
  ///////////////////////////////////////////

  input clk;				// drive with same system clock you use for quadcopter
  input RST_n;				// global unsynched reset.
  input SS_n;				// active low slave select
  input SCLK;				// Serial clock
  input MOSI;				// serial data in from master
  input frnt_ESC;			// ESC inputs that determine motor speeds
  input back_ESC;
  input left_ESC;
  input rght_ESC;
  
  output MISO;				// serial data out to master
  output reg INT;			// interrupt output
  
  localparam LIFT_OFFSET = 11'h080;		// Amount subtracted from inverse ESCs to serve as baseline for lift
  
  localparam WEIGHT = 13'h0940;			// represents weight of the quadcopter (if thrust>weight we are airborne)
  
  ///////////////////////////////////////////////////////////
  // Declare internal registers used for physics modeling //
  /////////////////////////////////////////////////////////
  reg signed [15:0] AX, AY;								// ESC inputs over time are used to compute
  reg [12:0] thrst;										// sum of thrust of all motors
  reg signed [13:0] vert_a;								// vertical acceleration
  reg signed [13:0] ptch_a;								// pitch acceleration
  reg signed [13:0] roll_a;								// roll acceleration
  reg signed [13:0] yaw_a;								// yaw acceleration
  reg signed [15:0] vert_v, ptch_v, roll_v, yaw_v;		// compute these sensor outputs.  _v terms
  reg signed [15:0] vert_p, ptch_p, roll_p, yaw_p;		// are integrated to get angular position
  reg any_high_ff1,any_high_ff2;						// used to determine when all ESC have had falling edge
  reg airborne;   
   
 
  ////////////////////////////////
  // Declare any internal nets //
  //////////////////////////////
  wire rst_n;											// synched global reset
  wire [10:0] spd_frnt,spd_back,spd_left,spd_rght;		// inverse ESC results
  wire [10:0] thrst_frnt,thrst_back,thrst_rght,thrst_left;	
  wire any_high;										// OR of all ESCs to determine when last one fell
  
  ////////////////////////////////////////////
  // Instantiate reset_synch to form rst_n //
  //////////////////////////////////////////
  reset_synch iRST(.clk(clk),.RST_n(RST_n),.rst_n(rst_n));
  
  /////////////////////////////////////////////////////
  // Instantiate model of SPI based inertial sensor //
  ///////////////////////////////////////////////////
  SPI_iNEMO3 iNEMO(.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),.MOSI(MOSI),.INT(INT),.AX(AX),.AY(AY),
                   .PTCH(ptch_v),.ROLL(roll_v),.YAW(yaw_v));

  ///////////////////////////////////////////////////////////////////////////////
  // Instantiate inverse_ESC modules to derive motor speed as vector quantity //
  /////////////////////////////////////////////////////////////////////////////
  inverse_ESC iINV_FRNT(.clk(clk),.rst_n(rst_n),.PWM(frnt_ESC),.SPEED(spd_frnt));
  inverse_ESC iINV_BACK(.clk(clk),.rst_n(rst_n),.PWM(back_ESC),.SPEED(spd_back));
  inverse_ESC iINV_LEFT(.clk(clk),.rst_n(rst_n),.PWM(left_ESC),.SPEED(spd_left));
  inverse_ESC iINV_RGHT(.clk(clk),.rst_n(rst_n),.PWM(rght_ESC),.SPEED(spd_rght));
  assign thrst_frnt = (spd_frnt>LIFT_OFFSET) ? spd_frnt - LIFT_OFFSET : 11'h000;
  assign thrst_back = (spd_back>LIFT_OFFSET) ? spd_back - LIFT_OFFSET : 11'h000;
  assign thrst_left = (spd_left>LIFT_OFFSET) ? spd_left - LIFT_OFFSET : 11'h000;
  assign thrst_rght = (spd_rght>LIFT_OFFSET) ? spd_rght - LIFT_OFFSET : 11'h000;
  
  
  //////////////////////////////////////////////////////////////////////////////////////////
  // Next section is a model of the physics of quadcopter as determined by motor thrusts //
  ////////////////////////////////////////////////////////////////////////////////////////
  assign any_high = frnt_ESC | back_ESC | left_ESC | rght_ESC;
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n) begin
	  any_high_ff1 <= 1'b0;
	  any_high_ff2 <= 1'b0;
	end else begin
	  any_high_ff1 <= any_high;
	  any_high_ff2 <= any_high_ff1;
	end
  /////////////////////////////////////////////////////
  // calc_physics is initiated on fall of whichever //
  // ESC signal was high last.  At this point we   //
  // know we have an updated set of motor speeds  //
  /////////////////////////////////////////////////
  assign calc_physics = ~any_high_ff1 & any_high_ff2;

  ////////////////////////////////////////////
  // Initiate all calculated physics terms //
  //////////////////////////////////////////
  initial begin
    airborne = 1'b0;	// flag for are we airborne
    AX = 16'h0000;		// assume we start flat
	AY = 16'h0000; 		// assume we start flat
	vert_v = 16'h0000;	// vertical velocity initially zero
	ptch_v = 16'h0000;	// pitch rate initially zero
	roll_v = 16'h0000;	// roll rate initially zero
	yaw_v = 16'h0000;	// yaw rate initailly zero
	vert_p = 16'h0000;	// vertical position is initailly zero (on the ground)
	ptch_p = 16'h0000;	// pitch position initially zero (flat)
	roll_p = 16'h0000;	// roll position initially zero (flat)
	yaw_p = 16'h0000;	// yaw position initially zero
  end
  
  always @(posedge calc_physics) begin
  	///////////////////////////////////////////////////////////////////
	// Accell readings AX & AY are a function of pitch_p and roll_p //
	/////////////////////////////////////////////////////////////////
	//AX = {{4{roll_p[15]}},roll_p[15:4]} + {{3{roll_p[15]}},roll_p[15:3]}-roll_p;		// -13/16 of roll_p
	//AY = ptch_p - {{3{ptch_p[15]}},ptch_p[15:3]} - {{4{ptch_p[15]}},ptch_p[15:4]};	// 13/16 of ptch_p
	//AX = {roll_p[15],roll_p[15:1]} - roll_p;	// -1/2 of roll_p
	//AY = {ptch_p[15],ptch_p[15:1]};				// 1/2 of ptch_p
	AX = {roll_p[15],roll_p[15:1]} - roll_p + {{4{roll_p[15]}},roll_p[15:4]};		// -7/16 of roll_p
	AY = {ptch_p[15],ptch_p[15:1]} - {{4{ptch_p[15]}},ptch_p[15:4]};				// 7/16 of ptch_p
	
	thrst = thrst_frnt + thrst_back + thrst_left + thrst_rght;
	
	/// Accelerations as function of thrusts ///
	vert_a = (airborne || (thrst>WEIGHT)) ? thrst - WEIGHT : 14'h0000;
    ptch_a = (airborne) ? thrst_frnt - thrst_back : 14'h0000;		// pitch angle acceleration
    roll_a = (airborne) ? thrst_left - thrst_rght : 14'h0000;		// roll angle acceleration
    yaw_a = (airborne) ? ((thrst_frnt-thrst_left) + (thrst_back-thrst_rght)) : 14'h0000;	// yaw acceleration
	
	/// Integrate accellerations to get velocities ///
	vert_v = satSum16(vert_v,{{4{vert_a[13]}},vert_a[13:2]});
    ptch_v = satSum16(ptch_v,ptch_a);
    roll_v = satSum16(roll_v,roll_a);
    yaw_v = satSum16(yaw_v,yaw_a);
	
	/// Integrate velocities to get positions ///
    vert_p = satSum16(vert_p,{{6{vert_v[15]}},vert_v[15:6]});
    ptch_p = satSum16(ptch_p,{{7{ptch_v[15]}},ptch_v[15:7]});
    roll_p = satSum16(roll_p,{{7{roll_v[15]}},roll_v[15:7]});
    yaw_p = satSum16(yaw_p,{{7{yaw_v[15]}},yaw_v[15:7]});
  
	if ((vert_p>16'h0001) && !airborne) begin
	  airborne = 1'b1;
	  $display("Quadcopter is now airborne!\n");
	end
	
  end

  always_comb
    if (airborne && vert_p[15]) begin
      $display("Vertical position <0, Quadcopter crashed!");
      $stop();
    end
   
  function [15:0] satSum16 (input [15:0] in1,in2);
    reg [15:0] simp_sum;

    simp_sum = in1 + in2;
    if (in1[15] && in2[15] && !simp_sum[15])
	satSum16 = 16'h8000;
    else if (!in1[15] && !in2[15] && simp_sum[15])
	satSum16 = 16'h7FFF;
    else
	satSum16 = simp_sum;
  endfunction
  
endmodule  

////////////////////////////////////
// Below is code for inverse_ESC //
//////////////////////////////////
module inverse_ESC(clk,rst_n,PWM,SPEED);
  input clk,rst_n;			// system clock and active low asynch reset
  input PWM;				// signal we are monitoring
  output reg [10:0] SPEED;	// Inferred speed as a vector
  
  ////////////////////////////////////////
  // Declare needed internal registers //
  //////////////////////////////////////
  reg [13:0] cnt;
  reg PWM_ff;		// used for edge detect
  
  wire PWM_rise, PWM_fall;		// edge detects on PWM
  
  //////////////////////////////////////////
  // + edge detect of PWM resets counter //
  ////////////////////////////////////////
  always_ff @(posedge clk)
    PWM_ff <= PWM;
	
  assign PWM_rise = PWM & ~PWM_ff;
  assign PWM_fall = ~PWM & PWM_ff;
  
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  cnt <= 14'h0000;
	else if (PWM_rise)
	  cnt <= 14'h0001;
	else if (PWM)
	  cnt <= cnt + 1;
	  
  always_ff @(posedge clk, negedge SPEED)
    if (!rst_n)
	  SPEED <= 14'h0000;
	else if (PWM_fall)
	  SPEED <= (cnt-6250)/3;
	  
endmodule
  
