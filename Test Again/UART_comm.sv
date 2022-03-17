module UART_comm(clk, rst_n, RX, TX, resp, send_resp, resp_sent, cmd_rdy, cmd, data, clr_cmd_rdy);

input clk, rst_n;          // clock and active low reset
input RX;                  // serial data input
input send_resp;           // indicates to transmit 8-bit data (resp)
input [7:0] resp;          // byte to transmit
input clr_cmd_rdy;         // host asserts when command digested

output TX;                 // serial data output
output logic resp_sent;    // indicates transmission of response complete
output logic cmd_rdy;      // indicates 24-bit command has been received
output logic [7:0] cmd;    // 8-bit opcode sent from host via BLE
output logic [15:0] data;  // 16-bit parameter sent LSB first via BLE

logic [7:0] rx_data;       // 8-bit data received from UART
logic rx_rdy;              // indicates new 8-bit data ready from UART
logic rx_rdy_ff1;         // FlipFLop hold value
logic rx_rdy_ff2;
logic rx_rdy_posedge;      // output of posedge detector on rx_rdy used to transition SM
logic clr_rdy;
logic clr_cmd_rdy_i;

typedef enum reg [1:0] {IDLE, CMD, DONE} state_t;
state_t state, nxt_state;
logic set_cmd_rdy;
logic set_cmd_byte, set_high_byte;
logic [7:0] high_byte;
logic [7:0] mid_byte;
logic [7:0] cmd_byte;

UART iUART(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .tx_data(resp), .trmt(send_resp),
.tx_done(resp_sent), .rx_data(rx_data), .rx_rdy(rx_rdy), .clr_rx_rdy(1'b0));

assign cmd = high_byte;
assign data = {mid_byte[7:0], rx_data[7:0]};

assign rx_rdy_posedge = (rx_rdy_ff2 == 1'b0 && rx_rdy_ff1 == 1'b1) ? 1'b1 : 1'b0;

// cmd_rdy reset/set
always_ff @(posedge clk, negedge rst_n) begin
   if(!rst_n)
      cmd_rdy <= 1'b0;
   else if(clr_cmd_rdy || clr_cmd_rdy_i)
      cmd_rdy <= 1'b0;
   else if (set_cmd_rdy)
      cmd_rdy <= 1'b1;
end

// double flopped edge detector
always_ff@(posedge clk, negedge rst_n) begin
   if(!rst_n) begin
      rx_rdy_ff1 <= 1'b0;
      rx_rdy_ff2 <= 1'b0;
   end
   else begin
      rx_rdy_ff1 <= rx_rdy;
      rx_rdy_ff2 <= rx_rdy_ff1;
   end
end

//Holds the current value of the cmd and data fields
always_ff @(posedge clk,negedge rst_n) begin
   if(!rst_n)
      high_byte <= 0;
   else if(!set_cmd_byte)
      high_byte <= rx_data;
end
// flip flop for mid_byte to hold current value of cmd and data
always_ff @(posedge clk, negedge rst_n) begin
   if(!rst_n)
      mid_byte <= 0;
   else if (!set_high_byte)
      mid_byte <= rx_data;
end

// State flop to hold current state
always_ff @(posedge clk, negedge rst_n) begin
   if(!rst_n)
      state <= IDLE;
   else
      state <= nxt_state;
end

// State Machine
always_comb begin
  // default values
   nxt_state = state;
   
   set_cmd_byte = 1'b1;
   set_high_byte = 1'b1;
   
   clr_cmd_rdy_i = 1'b0;
   
   set_cmd_rdy = 1'b0;
   
   clr_rdy = 1'b0;

   case(state)
   // In this state, if reciever is ready, rdy is cleared, cmd is set as 1'b0 and next state is CMD
      IDLE : begin
         if(rx_rdy_posedge) begin
            clr_rdy = 1'b1;
            set_cmd_byte = 1'b0;
            clr_cmd_rdy_i = 1'b1;
            nxt_state = CMD;
         end
      end
   // In this state, if receiver is ready, ready is cleared and the high byte is set to 0, next state is DONE
      CMD : begin
         if(rx_rdy_posedge) begin
            clr_rdy = 1'b1;
            set_high_byte = 1'b0;
            nxt_state = DONE;
         end
      end
      
      // DONE : sets the SM back to IDLE and sets cmd_rdy as 1'b1.
      default : begin
         if(rx_rdy_posedge) begin
            nxt_state = IDLE;
            set_cmd_rdy = 1'b1;
            clr_rdy = 1'b1;
         end
      end
      
   endcase
    
end

endmodule