module UART_rcv(clk,rst_n,RX,rdy,rx_data,clr_rdy);

input clk,rst_n;			// clock and active low reset
input RX;					// rx is the asynch serial input (need to double flop)
input clr_rdy;			// rdy can be cleared by this or start of new byte
output rdy;				// signifies to core a byte has been received
output [7:0] rx_data;		// data that was received

//// Define state as enumerated type /////
typedef enum reg {IDLE, RX_STATE} state_t;
state_t state, nxt_state;

reg [8:0] shift_reg;		// shift reg (9-bits), MSB will contain stop bit when finished
reg [3:0] bit_cnt;			// bit counter (need extra bit for stop bit)
reg [11:0] baud_cnt;			// baud rate counter (50MHz/19200) = div of 2604
reg rdy;					// implemented as a flop
reg rx_ff1, rx_ff2;			// back to back flops for meta-stability

logic start, set_rdy, receiving;		// using type logic for outputs of SM

wire shift;

////////////////////////////
// Infer state flop next //
//////////////////////////
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    state <= IDLE;
  else
    state <= nxt_state;

/////////////////////////
// Infer bit_cnt next //
///////////////////////
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    bit_cnt <= 4'b0000;
  else if (start)
    bit_cnt <= 4'b0000;
  else if (shift)
    bit_cnt <= bit_cnt+1;

//////////////////////////
// Infer baud_cnt next //
////////////////////////
always_ff @(posedge clk or negedge rst_n)
  //// shift is asserted when baud_cnt is 111_1111 ////
  if (!rst_n)
    baud_cnt <= 1302;			// start 1/2 way to zero for div of 2604
  else if (start)
    baud_cnt <= 1302;			// start 1/2 way to zero for div of 2604
  else if (shift)
    baud_cnt <= 2604;			// reset when baud count is full value for 19200 baud with 50MHz clk
  else if (receiving)
    baud_cnt <= baud_cnt-1;		// only burn power incrementing if transmitting

////////////////////////////////
// Infer shift register next //
//////////////////////////////
always_ff @(posedge clk)
  if (shift)
    shift_reg <= {rx_ff2,shift_reg[8:1]};   // LSB comes in first

/////////////////////////////////////////////
// rdy will be implemented with a flop //
///////////////////////////////////////////
always @(posedge clk or negedge rst_n)
  if (!rst_n)
    rdy <= 1'b0;
  else if (start || clr_rdy)
    rdy <= 1'b0;			// knock down rdy when new start bit detected
  else if (set_rdy)
    rdy <= 1'b1;

////////////////////////////////////////////////
// RX is asynch, so need to double flop      //
// prior to use for meta-stability purposes //
/////////////////////////////////////////////
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n)
    begin
      rx_ff1 <= 1'b1;			// reset to idle state
      rx_ff2 <= 1'b1;
    end
  else
    begin
      rx_ff1 <= RX;
      rx_ff2 <= rx_ff1;
    end

//////////////////////////////////////////////
// Now for hard part...State machine logic //
////////////////////////////////////////////
always_comb
  begin
    //////////////////////////////////////
    // Default assign all output of SM //
    ////////////////////////////////////
    start         = 0;
    set_rdy    = 0;
    receiving     = 0;
    nxt_state     = IDLE;	// always a good idea to default to IDLE state
    
    case (state)
      IDLE : begin
        if (!rx_ff2)		// did fall of start bit occur?
          begin
            nxt_state = RX_STATE;
            start = 1;
          end
        else nxt_state = IDLE;
      end
      default : begin		// this is RX state
        if (bit_cnt==4'b1010)
          begin
            set_rdy = 1;
            nxt_state = IDLE;
          end
        else
          nxt_state = RX_STATE;
        receiving = 1;
      end
    endcase
  end

///////////////////////////////////
// Continuous assignment follow //
/////////////////////////////////
assign shift = ~|baud_cnt; 						// shift wen baud_cnt is zero
assign rx_data = shift_reg[7:0];				// MSB of shift reg is stop bit

endmodule
