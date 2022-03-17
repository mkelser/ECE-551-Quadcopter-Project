`timescale 1ns/1ps
module QuadCopter_synthesis_tb();

wire SS_n, SCLK, MOSI, MISO, INT;
wire RX, TX;
wire [7:0] resp;				
wire cmd_sent, resp_rdy;
wire frnt_ESC, back_ESC, left_ESC, rght_ESC;

reg clk, RST_n;
reg [7:0] cmd;
reg [15:0] data;
reg send_cmd;
reg clr_resp_rdy;

localparam SET_THRST = 8'h05;             // set desired thrust as an unsigned 9-bit number

localparam pos_ack = 8'ha5;               // response used for positive acknowledgement

CycloneIV iQUAD(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MISO(MISO),
                .MOSI(MOSI),.INT(INT),.frnt_ESC(frnt_ESC),.back_ESC(back_ESC),
				            .left_ESC(left_ESC),.rght_ESC(rght_ESC));				  			

QuadCopter iDUT(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.MOSI(MOSI),.MISO(MISO),
                .INT(INT),.RX(RX),.TX(TX),.FRNT(frnt_ESC),.BCK(back_ESC),
				            .LFT(left_ESC),.RGHT(rght_ESC));

RemoteComm iREMOTE(.clk(clk), .rst_n(RST_n), .RX(TX), .TX(RX), .cmd(cmd), .data(data),
                   .send_cmd(send_cmd), .cmd_sent(cmd_sent), .resp_rdy(resp_rdy),
					              .resp(resp), .clr_resp_rdy(clr_resp_rdy));


initial begin
    initialize_synthesis();
    snd_cmd(SET_THRST, 8'h20);

    @(posedge clk);
    check_resp();
    $stop();
end

always begin
    #10 clk = ~clk;
end

task initialize_synthesis;
    begin
      $display("--------------------------");
      $display("Initializing QuadCopter.");

      // default clk and reset to avoid irregular propagation
      clk = 1'b0;
      RST_n = 1'b0;

      // reset over a positive and negative edge
      @(posedge clk);
      RST_n = 1'b0;
      @(posedge clk);
      @(negedge clk);
      RST_n = 1'b1;
   
      // wait for the internal rst_n to go high
      @(posedge iDUT.iRST.rst_n);
   end
endtask

task snd_cmd;
 input [7:0] t_cmd;
   input [15:0] t_data;  

   begin
      // set cmd and data as the inputs to task
      @(posedge clk);
      cmd = t_cmd;
      data = t_data;
      // assert send_cmd to begin transaction
      send_cmd = 1'b1;

      $display("sending cmd: %h and data: %h.", cmd, data);
      
      // deassert send_cmd after a clock edge
      @(posedge clk);
      send_cmd = 1'b0;
      @(posedge clk);
   end
endtask

task check_resp;
   // fork join to make sure response is acknowledged or not
   fork
      // if resp isn't ready, the test waits 10000000 clock cycles and if it goes to 10000000 the response ready has failed and an error message is displayed 
      begin : resp_rdy_timeout
         repeat(10000000) @(posedge clk);
         disable wait_for_resp_rdy;
         $display("check_resp: failed due to timeout for resp_rdy.\n");
         $stop();
      end	
     
      // This waits for response to be ready, and if it is, compares it to the localparam pos_ack and displays acknowledged if it passes    
      begin : wait_for_resp_rdy
         @(posedge resp_rdy);
         if(resp == pos_ack) begin
            disable resp_rdy_timeout;
            $display("acknowledged: %h.\n", resp);
         end
         else begin
            $display("check_resp: failed due to positive acknowledgement not received in resp.\n");
            $stop();
         end
      end
   join    
endtask

endmodule








