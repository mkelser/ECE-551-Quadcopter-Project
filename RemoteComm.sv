module RemoteComm(clk, rst_n, RX, TX, cmd, data, send_cmd, cmd_sent, resp_rdy, resp, clr_resp_rdy);

input clk, rst_n;       // clock and active low reset
input RX;               // serial data input
input send_cmd;         // indicates to tranmit 24-bit command (cmd)
input [7:0] cmd;        // 8-bit command to send
input [15:0] data;      // 16-bit data that accompanies command
input clr_resp_rdy;     // asserted in test bench to knock down resp_rdy

output TX;              // serial data output
output logic cmd_sent;  // indicates transmission of command complete
output logic resp_rdy;  // indicates 8-bit response has been received
output [7:0] resp;      // 8-bit response from DUT

logic trmt, tx_done;

logic [7:0] tx_data;

logic [1:0] sel;

logic [7:0] high_byte, mid_byte, low_byte;

logic set_cmd_sent, clr_cmd_sent;

typedef enum reg [2:0] {IDLE, HIGH, MID, LOW, DONE} state_t;
state_t state, nxt_state;

UART iUART(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .tx_data(tx_data), .trmt(trmt),
           .tx_done(tx_done), .rx_data(resp), .rx_rdy(resp_rdy), .clr_rx_rdy(clr_resp_rdy));

assign tx_data = sel[1] ? high_byte : (sel[0] ? mid_byte : low_byte); //assigns the high_byte, mid_byte, or low_byte to tx_data depending on the select bit from the mux.
assign high_byte = cmd[7:0]; //assigns high_byte with the command to send.

// d flip flop to hold mid byte
always_ff @(posedge clk) begin
   if(send_cmd)
      mid_byte <= data[15:8];
end

// d flip flop to hold low byte
always_ff @(posedge clk) begin
   if(send_cmd)
      low_byte <= data[7:0];
end

// SR flip flop for command sent signal
always_ff @(posedge clk, negedge rst_n) begin
   if(!rst_n)
      cmd_sent <= 0;
   else if(set_cmd_sent)
      cmd_sent <= 1;
   else if(clr_cmd_sent)
      cmd_sent <= 0;
end

// state flop to hold current state
always_ff @(posedge clk, negedge rst_n) begin
   if(!rst_n)
      state <= IDLE;
   else
      state <= nxt_state;
end

always_comb begin
   // default values
   trmt = 1'b0;
   sel = 2'b10;
   set_cmd_sent = 1'b0;
   clr_cmd_sent = 1'b0;
   nxt_state = state;
   case(state)
   // In this state, if command is sent, command is cleared and the signal is transmitted and next state is HIGH
      IDLE : begin 
         if(send_cmd) begin 
            clr_cmd_sent = 1'b1;
            trmt = 1'b1;
            nxt_state = HIGH;
         end
      end
   // In this state, if the transmitted signal has been sent and done has been asserted, the select bits would select bits 01 and the next state would be MID
      HIGH : begin
         if(tx_done) begin
            sel = 2'b01;
            trmt = 1'b1;
            nxt_state = MID;
         end
      end
   // In this state, if the transmitted signal has been sent and done has been asserted, the select bits would select bits 00 and the next state would be LOW
      MID : begin
         if(tx_done) begin
            sel = 2'b00;
            trmt = 1'b1;
            nxt_state = LOW;
         end
      end
   // In this state, if the transmitted signal has been sent and done has been asserted, the state machine would set the command sent 
      LOW : begin
         if(tx_done) begin
            set_cmd_sent = 1'b1;
            nxt_state = IDLE;
         end
      end
   // Done state, resets State machine to IDLE
      default:
         nxt_state = IDLE;
   endcase
    
end

endmodule
