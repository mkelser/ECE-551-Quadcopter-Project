module QuadCopter(clk,RST_n,SS_n,SCLK,MOSI,MISO,INT,RX,TX,FRNT,BCK,LFT,RGHT);

  input clk;			// 50MHz clock
  input RST_n;			// Reset from push button
  input RX;				// command from BLE interface
  input MISO;			// response from inertial sensor
  input INT;			// Interrupt pin from inertial
  
  output SS_n;			// serf select to inertial sensor
  output SCLK;			// SCLK to inertial sensor
  output MOSI;			// MOSI to inertial sensor
  output TX;			// TX to BLE interface

  output FRNT;			// front motor PWM
  output BCK;			// back motor PWM
  output LFT;			// left motor PWM
  output RGHT;			// right motor PWM
  
  
  ///////////////////////////////////////
  // Interconnecting internal signals //
  /////////////////////////////////////
  wire cmd_rdy;					// command from wireless ready
  wire [7:0] cmd;					// 8-bit command from wireless
  wire [15:0] data;				// 16-bit data from wireless
  wire clr_cmd_rdy;				// clear the command from wireless
  wire [7:0] resp;				// response to wireless
  wire send_resp;					// asserted to send response to wireless
  wire resp_sent;					// indicates response to wireless has been sent
  
  wire vld;							// goes high one clock cycle when new inertial measurement
  wire signed [15:0] ptch;		// current pitch
  wire signed [15:0] roll;		// current roll
  wire signed [15:0] yaw;		// current yaw
  wire signed [15:0] d_ptch;		// desired pitch
  wire signed [15:0] d_roll;		// desired roll
  wire signed [15:0] d_yaw;		// desired yaw

  wire [8:0] thrst;				// desired thrust
  wire rst_n;						// internal synchronized global reset
  wire strt_cal;					// from cmd_cfg to inertial_intf
  wire inertial_cal;				// indicates calibration in progress to flght_control
  wire motors_off;				// to flight control, forces motors off
  wire cal_done;					// from inertial_intf to cmd_cfg
  
  wire [10:0] frnt_spd;				// front motor speed from flght_cntrl
  wire [10:0] bck_spd;				// front motor speed from flght_cntrl
  wire [10:0] lft_spd;				// front motor speed from flght_cntrl
  wire [10:0] rght_spd;				// front motor speed from flght_cntrl  
  
  localparam FAST_SIM = 1;			// used to accelerate simulations.
	 
  ////////////////////////////////////////////////////////////
  // Instantiate UART_comm that handles host communication //
  //////////////////////////////////////////////////////////
  UART_comm iCOMM(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .resp(resp),
                  .send_resp(send_resp), .resp_sent(resp_sent),
			         .cmd_rdy(cmd_rdy), .cmd(cmd), .data(data),
						.clr_cmd_rdy(clr_cmd_rdy));
						
  ///////////////////////////////////////////////////////////////////////
  // Instantiate command config unit (interprets & executes commands) //
  /////////////////////////////////////////////////////////////////////	  
  cmd_cfg #(FAST_SIM) iCMD(.clk(clk), .rst_n(rst_n), .cmd_rdy(cmd_rdy), .cmd(cmd), .data(data),
               .clr_cmd_rdy(clr_cmd_rdy), .resp(resp), .send_resp(send_resp),
			      .d_ptch(d_ptch), .d_roll(d_roll), .d_yaw(d_yaw), .thrst(thrst),
					.strt_cal(strt_cal),.inertial_cal(inertial_cal),.motors_off(motors_off),
					.cal_done(cal_done));
				  
  //////////////////////////////////////////////////////////
  // Instantiate interface to inertial sensor (ST iNEMO) //
  ////////////////////////////////////////////////////////
  inert_intf #(FAST_SIM) iNEMO(.clk(clk),.rst_n(rst_n),.ptch(ptch),.roll(roll),
                   .yaw(yaw),.strt_cal(strt_cal),.cal_done(cal_done),
					.vld(vld),.SS_n(SS_n),.SCLK(SCLK),
				     .MOSI(MOSI),.MISO(MISO),.INT(INT));		
					
  ////////////////////////////////////
  // Instantiate flight controller //
  //////////////////////////////////					 
  flght_cntrl ifly(.clk(clk),.rst_n(rst_n),.vld(vld),.d_ptch(d_ptch),.d_roll(d_roll),
                   .d_yaw(d_yaw),.ptch(ptch),.roll(roll),.yaw(yaw),.thrst(thrst),
                   .inertial_cal(inertial_cal),.frnt_spd(frnt_spd),.bck_spd(bck_spd),
				   .lft_spd(lft_spd),.rght_spd(rght_spd));


  ///////////////////////
  // Instantiate ESCs //
  /////////////////////					 
  ESCs iESC (.clk(clk),.rst_n(rst_n),.frnt_spd(frnt_spd),.bck_spd(bck_spd),.lft_spd(lft_spd),
             .rght_spd(rght_spd),.wrt(vld),.motors_off(motors_off),.frnt(FRNT),.bck(BCK),.lft(LFT),
			 .rght(RGHT));
			 
  
  /////////////////////////////////////
  // Instantiate reset synchronizer //
  ///////////////////////////////////  
  reset_synch iRST(.clk(clk),.RST_n(RST_n),.rst_n(rst_n));
  
endmodule
