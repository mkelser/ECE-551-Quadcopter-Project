module cmd_cfg(clk, rst_n, cmd_rdy, cmd, cal_done, data, clr_cmd_rdy, resp, 
               send_resp, d_ptch, d_roll, d_yaw, thrst, strt_cal, inertial_cal, 
               motors_off);

input clk, rst_n;                         // system clock and active low reset

input [15:0] data;                        // data to accompany command

input cmd_rdy;                            // new valid command from UART_comm
input [7:0] cmd;                          // command opcode
output logic clr_cmd_rdy;                 // knocks down cmd_rdy after cmd_cfg is done

output logic [7:0] resp;                  // response back to remote, typically a pos_ack
output logic send_resp;                   // indicates UART_comm should send respond byte

output logic signed [15:0] d_ptch;        // desired pitch as a signed 16-bit number
output logic signed [15:0] d_roll;        // desired roll as a signed 16-bit number
output logic signed [15:0] d_yaw;         // desired yaw as a signed 16-bit number
output logic [8:0] thrst;                 // desired thrust as an unsigned 9-bit number

output logic strt_cal;                    // indicates to inegrator to start calibration
output logic inertial_cal;                // goes to flght_cntrl and held for calibration
input cal_done;                           // from integrator to for calibration done

output logic motors_off;                  // goes to ESC and shuts off motors
 
parameter FAST_SIM = 1;                   // used to expidite simulation if set to 1

logic [25:0] tmr;                         // 26-bit timer to wait 1.34s for calibration
logic clr_tmr, tmr_full;                  // used to clear and check when timer is full

logic wptch, wroll, wyaw, wthrst;         // write signals for pitch, roll, yaw, and thrust

logic en_emer_land;                       // enables an emergency land to set speeds to zero

logic mtrs_off;                           // used to assert motors_off from state machine
 
localparam SET_PTCH = 8'h02;              // set desired pitch as a signed 16-bit number                        
localparam SET_ROLL = 8'h03;              // set desired roll as a signed 16-bit number
localparam SET_YAW = 8'h04;               // set desired yaw as a signed 16-bit number
localparam SET_THRST = 8'h05;             // set desired thrust as an unsigned 9-bit number
localparam CALIBRATE = 8'h06;             // calibrate quadcopter and causes gyro calibration
localparam EMER_LAND = 8'h07;             // emergency land that sets all speeds to zero
localparam MTRS_OFF = 8'h08;              // turn motors off until we receive a calibration
 
localparam pos_ack = 8'ha5;               // response used for positive acknowledgement

// flip flop for states to handle commands
typedef enum reg [1:0] {IDLE, WAIT, CAL, ACK} state_t;
state_t state, nxt_state;

// use FAST_SIM to assert timer full for 9-bit timer
assign tmr_full = FAST_SIM ? &tmr[8:0] : &tmr[24:0];

// flip flop for timer to wait for calibration
always_ff @(posedge clk, negedge rst_n) begin
   if(!rst_n)
      tmr <= 1'b0;
   else if(clr_tmr)
      tmr <= 1'b0;
   else
      tmr <= tmr + 1'b1;
end

// flip flop for storing d_ptch
always_ff @(posedge clk, negedge rst_n) begin
   if(!rst_n)
      d_ptch <= 16'h0000;
   else if(en_emer_land)
      d_ptch <= 16'h0000;
   else if(wptch)
      d_ptch <= data;
end

// flip flop for storing d_roll
always_ff @(posedge clk, negedge rst_n) begin
   if(!rst_n)
      d_roll <= 16'h0000;
   else if(en_emer_land)
      d_roll <= 16'h0000;
   else if(wroll)
      d_roll <= data;
end

// flip flop for storing d_yaw
always_ff @(posedge clk, negedge rst_n) begin
   if(!rst_n)
      d_yaw <= 16'h0000;
   else if(en_emer_land)
      d_yaw <= 16'h0000;
   else if(wyaw)
      d_yaw <= data;
end

// flip flop for storing thrst
always_ff @(posedge clk, negedge rst_n) begin
   if(!rst_n)
      thrst <= 9'h000;
   else if(en_emer_land)
      thrst <= 9'h000;
   else if(wthrst)
      thrst <= {data[8:0]};
end

// flip flop for motors_off which resets to 1
always_ff @(posedge clk, negedge rst_n) begin
   // on reset motors should be off
   if(!rst_n)
      motors_off <= 1'b1;
   // on emergency land motors should be off
   else if(mtrs_off)
      motors_off <= 1'b1;
   else if(!mtrs_off && inertial_cal)
      motors_off <= 1'b0;
end

// flip flop for next state assignments
always_ff @(posedge clk, negedge rst_n) begin
   if(!rst_n)
      state <= IDLE;
   else 
      state <= nxt_state;
end

// combinational block for state transitions and outputs
always_comb begin
 
   // default state outputs to avoid latches
    
   // at default haven't cleared a cmd yet
   clr_cmd_rdy = 1'b0;
   
   // all write signals should be 0
   wptch = 1'b0;
   wroll = 1'b0;
   wyaw = 1'b0;
   wthrst = 1'b0;
   
   // at default calibration and tmr haven't been used
   strt_cal = 1'b0;
   clr_tmr = 1'b0;
   
   // only emergency land from EMER_LAND cmd
   en_emer_land = 1'b0;
   
   // at default have not received a cmd yet
   send_resp = 1'b0;
   
   // at default stay in current state
   nxt_state = state;

   case(state)
      IDLE : begin
         // idle until a cmd is ready
         if(cmd_rdy) begin
            // assert only during calibration
            inertial_cal = 1'b0;
            // reset cmd_rdy for next cmd
            clr_cmd_rdy = 1'b1;
            // handle all cmd opcodes
            case(cmd)
               SET_PTCH : begin
                  wptch = 1'b1;
                  nxt_state = ACK;
               end
               SET_ROLL : begin
                  wroll = 1'b1;
                  nxt_state = ACK;
               end
               SET_YAW : begin
                  wyaw = 1'b1;
                  nxt_state = ACK;
               end
               SET_THRST : begin
                  wthrst = 1'b1;
                  nxt_state = ACK;
               end
               CALIBRATE : begin
                  // turn motors on
                  mtrs_off = 1'b0;
                  // clr to wait for full
                  clr_tmr = 1'b1;
                  nxt_state = WAIT;
               end
               EMER_LAND : begin
                  // clear pitch, roll, yaw, & thrust
                  en_emer_land = 1'b1;
                  nxt_state = ACK;
               end
               MTRS_OFF : begin
                  // turn motors off
                  mtrs_off = 1'b1;
                  nxt_state = ACK;
               end
               default: begin
                  // catch unkwnown cmd & still idle
               end
            endcase  
         end         
      end
      WAIT : begin
         // assert for calibration speeds
         inertial_cal = 1'b1;
         if(tmr_full) begin
            nxt_state = CAL;
            // begin actual calibration
            strt_cal = 1'b1;
         end
      end
      CAL : begin
         // wait until calibrated
         if(cal_done) begin
            // deassert after calibrated
            inertial_cal = 1'b0;
            nxt_state = ACK;
         end
      end
      // ACK : state
      default : begin
         // postive acknowledge
         resp = pos_ack;
         send_resp = 1'b1;
         // wait for next cmd
         nxt_state = IDLE;
      end
   endcase
    
end

endmodule