module inert_intf(clk, rst_n, ptch, roll, yaw, strt_cal, cal_done, vld, SS_n, SCLK, MOSI, MISO, INT);
				  
parameter FAST_SIM = 1;                         // used to accelerate simulation
 
input clk, rst_n;
input MISO;					                                // SPI input from inertial sensor
input INT;					                                 // goes high when measurement ready
input strt_cal;				                             // indicates we should start calibration
  
output signed [15:0] ptch, roll, yaw;	          // fusion corrected angles
output cal_done;						                          // indicates calibration is done
output reg vld;						                           // goes high for 1 clock when new outputs available
output SS_n, SCLK, MOSI;				                    // SPI outputs                 
            
logic CPH, CPL, CRH, CRL,                       // status flags to signal to hold pitch, roll,
      CYH, CYL, CAXH, CAXL, CAYH, CAYL;         // yaw, and acceleration bytes

logic [15:0] timer;                             // 16 bit register for timer
 
logic INT_ff1, INT_ff2;                         // registers to double flop the interrupt signal

logic [15:0] inert_data;                        // inertial data set to pitch, roll, yaw, or acceleration

logic wrt;                                      // status signal to write command
logic [15:0] cmd;                               // holds the command for NEMO

logic signed [15:0] ptch_rt, roll_rt, yaw_rt;   // feeds inertial_integrator
logic signed [15:0] ax, ay;			                  // accel data to inertial_integrator
 
// states for intialization and readings from the inertial sensor
typedef enum { INIT1, INIT2, INIT3, INIT4, WAIT, PH, 
               PL, RH, RL, YH, YL, AXH, AXL, AYH, AYL, DONE } state_t;
state_t state, nxt_state; 
  
/////////////////////////////////////////////////////////////////
// instantiation of SPI monarch for inertial sensor interface //
///////////////////////////////////////////////////////////////
SPI_mnrch iSPI(.clk(clk),.rst_n(rst_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),.MOSI(MOSI),
               .wrt(wrt),.done(done),.rd_data(inert_data),.wt_data(cmd));
				  
////////////////////////////////////////////////////////////////////////
// instantiation of Angle Engine that takes in angular rate readings //
// and acceleration info and produces ptch, roll, and yaw readings  // 
/////////////////////////////////////////////////////////////////////
inertial_integrator #(FAST_SIM) iINT(.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal), .cal_done(cal_done),
                                     .vld(vld), .ptch_rt(ptch_rt), .roll_rt(roll_rt), .yaw_rt(yaw_rt), .ax(ax),
						                               .ay(ay), .ptch(ptch), .roll(roll), .yaw(yaw));
                                                                

// flip flop to hold the ptch high and low bytes
always_ff @(posedge clk, negedge rst_n) begin
   if(!rst_n)
      ptch_rt <= 16'h0000;
   else if(CPH)
      ptch_rt[15:8] <= inert_data[7:0];
   else if(CPL)
      ptch_rt[7:0] <= inert_data[7:0];
end

// flip flop to hold the roll high and low bytes
always_ff @(posedge clk, negedge rst_n) begin
   if(!rst_n)
      roll_rt <= 16'h0000;
   else if(CRH)
      roll_rt[15:8] <= inert_data[7:0];
   else if(CRL)
      roll_rt[7:0] <= inert_data[7:0];
end

// flip flop to hold the yaw high and low bytes
always_ff @(posedge clk, negedge rst_n) begin
   if(!rst_n)
      yaw_rt <= 16'h0000;
   else if(CYH)
      yaw_rt[15:8] <= inert_data[7:0];
   else if(CYL)
      yaw_rt[7:0] <= inert_data[7:0];
end

// flip flop to hold the ax high and low bytes
always_ff @(posedge clk, negedge rst_n) begin
   if(!rst_n)
      ax <= 16'h0000;
   else if(CAXH)
      ax[15:8] <= inert_data[7:0];
   else if(CAXL)
      ax[7:0] <= inert_data[7:0];
end

// flip flop to hold the ay high and low bytes
always_ff @(posedge clk, negedge rst_n) begin
   if(!rst_n)
      ay <= 16'h0000;
   else if(CAYH)
      ay[15:8] <= inert_data[7:0];
   else if(CAYL)
      ay[7:0] <= inert_data[7:0];
end

// flip flop for 16 bit timer
always_ff @(posedge clk, negedge rst_n) begin
   if(!rst_n) 
      timer <= 16'h0000;
   else if(&timer)
      timer <= 16'h0000;
   else 
      timer <= timer + 1'b1;
end

// double flip flop for the interrupt from the NEMO
always_ff @(posedge clk, negedge rst_n) begin
   if(!rst_n) begin
      INT_ff1 <= 1'b0;
      INT_ff2 <= 1'b0;
   end
   else begin
      INT_ff1 <= INT;
      INT_ff2 <= INT_ff1;
   end
end

// flip flop for state assignments
always_ff @(posedge clk, negedge rst_n) begin
   if(!rst_n) 
      state <= INIT1;
   else
      state <= nxt_state;
end

// combinational block for state transitions and output logic
always_comb begin
 
   // default logic up front to avoid latches
    
   // at default do not assert wrt
   wrt = 1'b0;
   
   // at default data is not valid
   vld = 1'b0;
   
   // at default all signal flags are zero
   CPH = 1'b0;
   CPL = 1'b0;
   CRH = 1'b0;
   CRL = 1'b0;
   CYH = 1'b0;
   CYL = 1'b0;
   CAXH = 1'b0;
   CAXL = 1'b0;
   CAYH = 1'b0;
   CAYL = 1'b0;
   
   // at default stay in current state
   nxt_state = state;
   
   case(state)
      INIT1 : begin
         // enable interrupt pin
         cmd = 16'h0D02;
         // wait for setup time
         if(&timer) begin
            wrt = 1'b1;
		          nxt_state = INIT2;	
         end
      end
      INIT2 : begin
         // setup accel for 416 Hz
         cmd = 16'h1062;
         if(done) begin
            wrt = 1'b1;
		          nxt_state = INIT3;
         end
      end
      INIT3 : begin
         // set up gyro for 416 Hz
         cmd = 16'h1162;
         if(done) begin
            wrt = 1'b1;
		          nxt_state = INIT4;
         end
      end
      INIT4 : begin
          // turn rounding on
          cmd = 16'h1460;
          if(done) begin
             wrt = 1'b1;
		           nxt_state = WAIT;
          end
      end
      WAIT : begin
         // wait for interrupt
         if(INT_ff2) begin
            nxt_state = PL;
            cmd = 16'hA2xx;
            wrt = 1'b1;
         end
      end
      PL : begin
         // assert hold ptch low
         CPL = 1'b1;
         if(done) begin
		          nxt_state = PH;
            cmd = 16'hA3xx;
            wrt = 1'b1;
         end
      end
      PH : begin
         // assert hold ptch high
         CPH = 1'b1;
         if(done) begin
		          nxt_state = RL;
            cmd = 16'hA4xx;
            wrt = 1'b1;
         end
      end
      RL : begin
         // assert hold roll low
         CRL = 1'b1;
         if(done) begin
		          nxt_state = RH;
            cmd = 16'hA5xx;
            wrt = 1'b1;
         end
      end
      RH : begin
         // assert hold roll high
         CRH = 1'b1;
         if(done) begin
            nxt_state = YL;
            cmd = 16'hA6xx;
		          wrt = 1'b1;
         end
      end
      YL : begin
         // assert hold yaw low
         CYL = 1'b1;
         if(done) begin
            nxt_state = YH;          
            cmd = 16'hA7xx;            
		          wrt = 1'b1;    
         end
      end
      YH : begin
         // assert hold yaw high
         CYH = 1'b1;
         if(done) begin
            nxt_state = AXL;
            cmd = 16'hA8xx;
		          wrt = 1'b1;
         end
      end
      AXL : begin
         // assert hold ax low
         CAXL = 1'b1;
         if(done) begin
            nxt_state = AXH;
		          cmd = 16'hA9xx;
            wrt = 1'b1;
         end
      end
      AXH : begin
         // assert hold ax high
         CAXH = 1'b1;
         if(done) begin
            nxt_state = AYL;
            cmd = 16'hAAxx;
		          wrt = 1'b1;
         end
      end
      AYL : begin
         // assert hold ay low
         CAYL = 1'b1;
         if(done) begin
            nxt_state = AYH;
            cmd = 16'hABxx;
		          wrt = 1'b1;     
         end
      end
      AYH : begin
         // assert hold ay high
         CAYH = 1'b1;
         if(done)
            // don't assert wrt
		          nxt_state = DONE;
      end
      // valid state
      default : begin
         // assert valid
         vld = 1'b1;
         // return to wait for INT
         nxt_state = WAIT;
      end
   endcase
end

endmodule