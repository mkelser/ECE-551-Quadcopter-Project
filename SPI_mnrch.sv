module SPI_mnrch(clk, rst_n, SS_n, SCLK, MOSI, MISO, wrt, wt_data, done, rd_data);

input clk;                       // 50 MHz system clock
input rst_n;                     // active low reset
input wrt;                       // indicates a write
input [15:0] wt_data;                // 16 bit command with 2 bytes of data
output reg SS_n;                 // active low serf select
output reg SCLK;                 // serial clock
output reg MOSI;                 // monarch out serf in
input reg MISO;                  // monarch in serf out
output reg done;                 // indicates we are done
output reg [15:0] rd_data;       // data that is read in

localparam SCLK_init = 4'b1011;  // the initial value for SCLK that is offset

reg init;                        // signifies the initialization of process
reg ld_SCLK;                     // if asserted load default parameter value to SCLK
reg shft;
reg full;                        // signifies a shift occuring
wire done16;                     // signifies the bit counter is done
reg set_done;                    // if asserted done and SS_n should be triggered

reg [3:0] SCLK_div;              // divides the system clk by 1/16th (4 bits)
reg [4:0] bit_cnt;               // bit counter for shifting
reg [15:0] shft_reg;             // shift register for read data and MOSI

typedef enum reg [1:0] {IDLE, SHFT, BCK} state_t;
state_t state, nxt_state;

assign full = &SCLK_div[3:1];                   // check is SCLK is full (when alls bits are high)
assign shft = SCLK_div == 4'b1001;              // only shift 2 clock cycles after // done16 ? 0 : 
assign SCLK = SS_n ? 1 : SCLK_div[3];           // when SS_n is high keep SCLK high otherwise run SCLK
assign done16 = bit_cnt[4];                     // check when the bit counter is done
assign MOSI = shft_reg[15];                     // MSB of shift register provides the MOSI
assign rd_data = shft_reg;                      // direct assignment for read data


// flip flop for state assignments
always_ff @(posedge clk, negedge rst_n) begin
   if (!rst_n)
      state <= IDLE;
   else
      state <= nxt_state;
end

// combinational block for state output and state transitions
always_comb begin
   // default outputs to avoid inferring latches
   init = 0;
   ld_SCLK = 0;
   set_done = 0;
   nxt_state = state;
   case (state)
      // wait for write
      IDLE : begin
         ld_SCLK = 1;
         if (wrt) begin
            nxt_state = SHFT;
            init = 1;
         end
   end
      // front porch state
      SHFT : begin
         if (done16)
            nxt_state = BCK;
      end
      // back porch state
      default : begin
         if (full) begin
            set_done = 1;
            nxt_state = IDLE;
         end
      end
   endcase
end

// flip flop for SCLK counter
always_ff @(posedge clk) begin
   if (ld_SCLK)
      SCLK_div <= SCLK_init;
   else
      SCLK_div <= SCLK_div + 1;
end

// flip flop for bit counter
always_ff @(posedge clk) begin
   if (init)
      bit_cnt <= 0;
   else if (shft)
   bit_cnt <= bit_cnt + 1;
end

// flip flop for shifted data that is later assigned to read data and MISO
always_ff @(posedge clk, negedge rst_n) begin
   if (!rst_n)
      shft_reg <= 0;
   else if (init)
      shft_reg <= wt_data;
   else if (shft)
      shft_reg <= {shft_reg[14:0], MISO};
end

// SR flip flop for SS_n
always_ff @(posedge clk, negedge rst_n) begin
   if (!rst_n)
      SS_n <= 1;
   else if (init)
      SS_n <= 0;
   else if (set_done)
      SS_n <= 1;
end

// SR flip flop for done
always_ff @(posedge clk, negedge rst_n) begin
   if (!rst_n)
      done <= 0;
   else if (init)
      done <= 0;
   else if (set_done)
      done <= 1;
end

endmodule
