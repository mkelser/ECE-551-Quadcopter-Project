module QuadCopter_tb4();

// interconnects to DUT/support as wire
wire SS_n, SCLK, MOSI, MISO, INT;            // serial signals, data lines, & interrupt
wire RX, TX;                                 // RX and TX lines for UART
wire [7:0] resp;				                         // response back to RemoteComm
wire cmd_sent, resp_rdy;                     // signifies end of cmd and when response ready
wire frnt_ESC, back_ESC, left_ESC, rght_ESC; // PWM from ESC for each motor

// stimulus defined as reg
reg clk, RST_n;                              // system clock and active low reset
reg [7:0] cmd;                               // command opcode
reg [15:0] data;                             // data to accompany command
reg send_cmd;                                // singals to RemoteComm to send cmd to QuadCopter
reg clr_resp_rdy;                            // clears when the response has been received

// command opcodes
localparam SET_PTCH = 8'h02;                 // set desired pitch as a signed 16-bit number                        
localparam SET_ROLL = 8'h03;                 // set desired roll as a signed 16-bit number
localparam SET_YAW = 8'h04;                  // set desired yaw as a signed 16-bit number
localparam SET_THRST = 8'h05;                // set desired thrust as an unsigned 9-bit number
localparam CALIBRATE = 8'h06;                // calibrate quadcopter and causes gyro calibration
localparam EMER_LAND = 8'h07;                // emergency land that sets all speeds to zero
localparam MTRS_OFF = 8'h08;                 // turn motors off until we receive a calibration
 
localparam pos_ack = 8'hA5;                  // response used for positive acknowledgement

localparam tolerance = 5;                    // tolerance between actual and desired ptch, roll, and yaw

////////////////////////////////////////////////////////////////////////////////////
// instantiation of the physical model of the copter device with inertial sensor //
//////////////////////////////////////////////////////////////////////////////////
CycloneIV iQUAD(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),
                .MOSI(MOSI),.INT(INT),.frnt_ESC(frnt_ESC),.back_ESC(back_ESC),
				            .left_ESC(left_ESC),.rght_ESC(rght_ESC));				  			

/////////////////////////////////////////////////////////////////////////////////////////////////
// instantiation of QuadCopter, our DUT that receives cmds from RemoteComm and runs CycloneIV //
///////////////////////////////////////////////////////////////////////////////////////////////
QuadCopter iDUT(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MOSI(MOSI),.MISO(MISO),
                .INT(INT),.RX(RX),.TX(TX),.FRNT(frnt_ESC),.BCK(back_ESC),
				            .LFT(left_ESC),.RGHT(rght_ESC));

///////////////////////////////////////////////////////////////////////////////////////////
// instantiation of master UART that mimics host cmds that communicates with QuadCopter //
/////////////////////////////////////////////////////////////////////////////////////////
RemoteComm iREMOTE(.clk(clk), .rst_n(RST_n), .RX(TX), .TX(RX), .cmd(cmd), .data(data),
                   .send_cmd(send_cmd), .cmd_sent(cmd_sent), .resp_rdy(resp_rdy),
					              .resp(resp), .clr_resp_rdy(clr_resp_rdy));

/////////////////////////////////////////////////
// generation of clock signal for all modules //
///////////////////////////////////////////////
always begin
   #10 clk = ~clk;
end

////////////////////////////////////////////////////
// tests QuadCopter by using tasks from tb_tasks //
//////////////////////////////////////////////////
initial begin
   // mimic normal functionality
   initialize();
   // test calibrate, input value for data isn't crucial for test
   test_calibrate(16'h0006);

   // conduct a simple test for convergence
   // inputs are in order: ptch, roll, yaw, & thrst
   test_convergence(16'h0076, 16'hFF03, 16'h0034, 16'h0FF);

   // now that QuadCopter is airborne test emergency land
   // input value for data isn't crucial for test
   test_emer_land(16'h0007);
   
   // now that QuadCopter has landed safely, turn motors off
   // input value for data isn't crucial for test
   test_mtrs_off(16'h0008);

   // now that we have turned motors off recalibrate
   // input value for data isn't crucial for test
   test_calibrate(16'h0006);
   
   display_success();
   $stop();
end

`include "QuadCopter_tb_tasks.sv"

endmodule