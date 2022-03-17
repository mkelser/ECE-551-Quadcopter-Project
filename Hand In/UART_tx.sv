module UART_tx(clk,rst_n,TX,trmt,tx_data,tx_done);

input clk,rst_n;		// clock and active low reset
input trmt;				// trmt tells TX section to transmit tx_data
input [7:0] tx_data;	// byte to transmit
output TX, tx_done;		// tx_done asserted when transmission complete

reg [8:0] shift_reg;	// 1-bit wider to store start bit
reg [3:0] bit_cnt;		// bit counter
reg [11:0] baud_cnt;	// baud rate counter (50MHz/19200) = div of 2604
reg tx_done;			// tx_done will be a set/reset flop

reg load, trnsmttng;		// assigned in state machine

wire shift;

////////////////////////////////
// Define state as enum type //
//////////////////////////////
typedef enum reg {IDLE,TX_STATE} state_t;
state_t state,nxt_state;

////////////////////////////
// Infer state flop next //
//////////////////////////
always @(posedge clk or negedge rst_n)
  if (!rst_n)
    state <= IDLE;
  else
    state <= nxt_state;

/////////////////////////
// Infer bit_cnt next //
///////////////////////
always @(posedge clk or negedge rst_n)
  if (!rst_n)
    bit_cnt <= 4'b0000;
  else if (load)
    bit_cnt <= 4'b0000;
  else if (shift)
    bit_cnt <= bit_cnt+1;

//////////////////////////
// Infer baud_cnt next //
////////////////////////
always @(posedge clk or negedge rst_n)
  if (!rst_n)
    baud_cnt <= 2604;
  else if (load || shift)
    baud_cnt <= 2604;			// baud of 19200 with 50MHz clk
  else if (trnsmttng)
    baud_cnt <= baud_cnt-1;		// only burn power incrementing if tranmitting

////////////////////////////////
// Infer shift register next //
//////////////////////////////
always @(posedge clk or negedge rst_n)
  if (!rst_n)
    shift_reg <= 9'h1FF;		// reset to idle state being transmitted
  else if (load)
    shift_reg <= {tx_data,1'b0};	// start bit is loaded as well as data to TX
  else if (shift)
    shift_reg <= {1'b1,shift_reg[8:1]};	// LSB shifted out and idle state shifted in 

///////////////////////////////////////////////
// Easiest to make tx_done a set/reset flop //
/////////////////////////////////////////////
always @(posedge clk or negedge rst_n)
  if (!rst_n)
    tx_done <= 1'b0;
  else if (trmt)
    tx_done <= 1'b0;
  else if (bit_cnt==4'b1010)
    tx_done <= 1'b1;

//////////////////////////////////////////////
// Now for hard part...State machine logic //
////////////////////////////////////////////
always @(state,trmt,shift,bit_cnt)
  begin
    //////////////////////////////////////
    // Default assign all output of SM //
    ////////////////////////////////////
    load         = 0;
    trnsmttng = 0;
    nxt_state    = IDLE;	// always a good idea to default to IDLE state
    
    case (state)
      IDLE : begin
        if (trmt)
          begin
            nxt_state = TX_STATE;
            load = 1;
          end
        else nxt_state = IDLE;
      end
      default : begin		// this is TX state
        if (bit_cnt==4'b1010)
          nxt_state = IDLE;
        else
          nxt_state = TX_STATE;
        trnsmttng = 1;
      end
    endcase
  end

////////////////////////////////////
// Continuous assignement follow //
//////////////////////////////////
assign shift = ~|baud_cnt;
assign TX = shift_reg[0];		// LSB of shift register is TX

endmodule

