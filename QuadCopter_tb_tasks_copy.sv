////////////////////////////////////////////////////////////
// task: initialize - reset QuadCopter using reset synch //
//////////////////////////////////////////////////////////
task initialize;
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
 
////////////////////////////////////////////////////
// task: send_test_cmd - sends a cmd for testing //
//////////////////////////////////////////////////
task send_test_cmd;
   input logic [7:0] t_cmd;
   input logic signed [15:0] t_data;  

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

////////////////////////////////////////////////////////////////////
// task: check_resp - checks resp_rdy & positive acknowledgement //
//////////////////////////////////////////////////////////////////
task check_resp;
   fork
      begin : resp_rdy_timeout
         repeat(1000000) @(posedge clk);
         disable wait_for_resp_rdy;
         $display("check_resp: failed due to timeout for resp_rdy.\n");
         $stop();
      end	    
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

//////////////////////////////////////////////////////////////////////////
// task: test_cmd - tests sending a cmd and checks actual for set cmds //
////////////////////////////////////////////////////////////////////////
task test_cmd;
   input logic [7:0] t_cmd;
   input logic signed [15:0] t_data;

   begin
      // send a set test_cmd with desired test_data
      send_test_cmd(t_cmd, t_data);

      // wait and check that cmd_sent is asserted
      fork
         begin : timeout_cmd_sent
            repeat(1000000) @(posedge clk);
            disable wait_for_cmd_sent;
            $display("test_send_cmd: failed due to timeout for cmd_sent.\n");
            $stop();
         end
         begin : wait_for_cmd_sent
            @(posedge cmd_sent);
            disable timeout_cmd_sent;
         end
      join
      
      // based on the cmd compare the desired value to the actual
      case(t_cmd)
         SET_PTCH : begin
            // check if d_ptch updates correctly to 16'h0002 in flght_cntrl
            if(iDUT.ifly.d_ptch !== t_data) begin
               $display("test_send_cmd: failed because d_ptch is incorrect value: %h instead of correct value: %h.\n", iDUT.ifly.d_ptch, t_data);
               $stop();
            end
         end
         SET_ROLL : begin
            // check if d_roll updates correctly to 16'h0003 in flght_cntrl
            if(iDUT.ifly.d_roll !== t_data) begin
               $display("test_send_cmd: failed because d_roll is incorrect value: %h instead of correct value: %h.\n", iDUT.ifly.d_roll, t_data);
               $stop();
            end
         end
         SET_YAW : begin
            // check if d_yaw updates correctly to 16'h0004 in flght_cntrl
            if(iDUT.ifly.d_yaw !== t_data) begin
               $display("test_send_cmd: failed because d_yaw is incorrect value: %h instead of correct value: %h.\n", iDUT.ifly.d_yaw, t_data);
               $stop();
            end
         end
         SET_THRST : begin
            // check if thrst updates correctly to 16'h0005 in flght_cntrl
            if(iDUT.ifly.thrst !== t_data) begin
               $display("test_send_cmd: failed because thrst is incorrect value: %h instead of correct value: %h.\n", iDUT.ifly.thrst, t_data);
               $stop();
            end
         end
         CALIBRATE : begin
            // do nothing for now
         end
         EMER_LAND : begin
            // do nothing for now
         end
         MTRS_OFF: begin
            // do nothing for now
         end
         default : begin
               $display("test_send_cmd: failed because cmd not recognized.\n");
               $stop();
         end
      endcase

      // make sure to receive a positive acknowledgement from resp
      check_resp();
   end
endtask;

///////////////////////////////////////////////////////////////////////
// task: check_motors_on - waits to see if motors is on or turns on //
/////////////////////////////////////////////////////////////////////
task check_motors_on;
   begin
      $display("check_motors_on: started.");
      fork
         begin : timeout_motors_on
            repeat(100000) @(posedge clk);
            disable wait_for_motors_on;
            $display("check_motors_on: failed.\n");
            $stop();
         end
         begin : wait_for_motors_on
            if(!iDUT.motors_off) begin
               disable timeout_motors_on;
               $display("check_motors_on: passed.\n");
            end
         end
      join
   end
endtask

//////////////////////////////////////////////////////////////////////////
// task: check_motors_off - waits to see if motors is off or turns off //
////////////////////////////////////////////////////////////////////////
task check_motors_off;
   begin
      $display("check_motors_off: started.");
      fork
         begin : timeout_motors_off
            repeat(100000) @(posedge clk);
            disable wait_for_motors_off;
            $display("check_motors_off: failed.\n");
            $stop();
         end
         begin : wait_for_motors_off
            if(iDUT.motors_off) begin
               disable timeout_motors_off;
               $display("check_motors_off: passed.\n");
            end
         end
      join
   end
endtask

/////////////////////////////////////////////////////////
// task: wait_strt_cal - wait for strt_cal to go high //
///////////////////////////////////////////////////////
task wait_strt_cal;
   begin
      $display("wait_strt_cal: waiting.");
      fork
         begin : timeout_strt_cal
            repeat(100000000) @(posedge clk);
            disable wait_for_strt_cal;
            $display("wait_cal_done: failed due to timeout time for strt_cal.\n");
            $stop();
         end
         begin : wait_for_strt_cal
            @(posedge iDUT.strt_cal);
            disable timeout_strt_cal;
            $display("wait_strt_cal: done.\n");
         end
      join
   end
endtask

/////////////////////////////////////////////////////////////////////////////////////
// task: check_inertial_cal - checks if actual inertial cal is equal to expected  //
///////////////////////////////////////////////////////////////////////////////////
task check_inertial_cal;
   input expected;

   begin
      if (iDUT.inertial_cal !== expected) begin
         $display("check_inertial_cal: failed inertial_cal is not held.\n");
         $stop();
      end
      $display("check_inertial_cal: passed.\n");
   end
endtask

//////////////////////////////////////////////////////////
// task: wait_cal_done - waits for cal_done to go high //
////////////////////////////////////////////////////////
task wait_cal_done;
   begin
      $display("wait_cal_done: waiting.");
      fork
         begin : timeout_cal_done
            repeat(100000000) @(posedge clk);
            disable wait_for_cal_done;
            $display("wait_cal_done: failed due to timeout for cal_done.\n");
            $stop();
         end
         begin : wait_for_cal_done
            @(posedge iDUT.cal_done);
            disable timeout_cal_done;
            $display("wait_cal_done: done.\n");
         end
      join
   end
endtask

//////////////////////////////////////////////////////////////////////////////////////////
// task: wait_convergence - wait for the difference to become less than the tolerance  //
////////////////////////////////////////////////////////////////////////////////////////
task wait_convergence;
   input logic [7:0] t_cmd;

   string s_cmd;
   logic signed [15:0] actual;
   logic signed [15:0] desired;
   integer diff;

   begin
      fork
         begin : timeout_convergence
            repeat(100000000) @(posedge clk);
            disable wait_for_convergence;
            $display("wait_convergence: failed due to timeout for convergence.\n");
            $stop();
         end
         begin : wait_for_convergence
            $display("wait_convergence: waiting.");
            // rudundant code because need to access actual as it changes every posedge clk
            do begin
               // based on the cmd check "update" the actual and desired (desired shouldn't change)
               case(t_cmd)
                  SET_PTCH : begin
                     actual = iDUT.ifly.ptch;
                     desired = iDUT.ifly.d_ptch;
                     s_cmd = "ptch";
                  end
                  SET_ROLL : begin
                     actual = iDUT.ifly.roll;
                     desired = iDUT.ifly.d_roll;
                     s_cmd = "roll";
                  end
                  SET_YAW : begin
                     actual = iDUT.ifly.yaw;
                     desired = iDUT.ifly.d_yaw;
                     s_cmd = "yaw";
                  end
                  default : begin
                     $display("wait_convergence: failed because cmd not recognized.\n");
                     $stop();
                  end
               endcase
               // find the absolute difference between actual and desired every posedge clk
               abs_diff(diff, actual, desired);
               @(posedge clk);
            end
            // wait until difference between actual and desired is within tolerance
            while(diff > tolerance);

            disable timeout_convergence;
            $display("wait_convergence: %s done.\n", s_cmd);
         end
      join
   end
endtask

////////////////////////////////////////////////////////////////////
// task: check_airborne - waits to see if QuadCopter is airborne //
//////////////////////////////////////////////////////////////////
task check_airborne;
   begin
      $display("check_airborne: waiting.");
      fork
         begin : timeout_airborne
            repeat(100000000) @(posedge clk);
            disable wait_for_airborne;
            $display("check_airborne: failed due to timeout for airborne.\n");
            $stop();
         end
         begin : wait_for_airborne
            if (iQUAD.airborne);
               disable timeout_airborne;
         end
      join
   end
endtask

/////////////////////////////////////////////////////////////////
// task: check_landed - waits to see if QuadCopter has landed //
///////////////////////////////////////////////////////////////
task check_landed;
   begin
      $display("check_landed: waiting.");
      fork
         begin : timeout_landed
            repeat(100000000) @(posedge clk);
            disable wait_for_landed;
            $display("check_landed: failed due to timeout for airborne.\n");
            $stop();
         end
         begin : wait_for_landed
            if (!iQUAD.airborne);
            disable timeout_landed;
            $display("QuadCopter landed.\n");
         end
      join
   end
endtask

////////////////////////////////////////////////////////////////////////
// task: check_thrst - seperate test from 'test_cmd' to check thrust //
//////////////////////////////////////////////////////////////////////
task check_thrst;
   input logic signed [9:0] t_thrst;
   
   begin
      $display("check_thrst: waiting.");
      fork
         begin : timeout_thrst
            repeat(100000) @(posedge clk);
            disable wait_for_thrst;
            $display("check_thrst: failed due to timeout for thrst never being set to correct value: %h.\n", t_thrst);
            $stop();
         end
         begin : wait_for_thrst
            while(iDUT.ifly.thrst !== t_thrst) begin
               @(posedge clk);
            end
            disable timeout_thrst;
            $display("check_thrst: done.\n");
         end
      join
   end
endtask

//////////////////////////////////////////////////////////////////
// task: display_success - displays tests passed to transcript //
////////////////////////////////////////////////////////////////
task display_success;
   begin
      $display("--------------------------");
      $display("All tests passed!");
   end
endtask
 
////////////////////////////////////////////////////////////////////////////////
// task: abs_diff - finds the absolute difference between actual and desired //
//////////////////////////////////////////////////////////////////////////////
task abs_diff(output integer diff, input logic signed [15:0] actual, desired);
   begin
      // compute difference
      diff = actual - desired;
      // if the difference is negative negate 
      if(diff[31])
         diff = ~diff + 1;
   end
endtask

///////////////////////////////////////////////////////////////////////////////////////////
// task: test_send_cmd - tests sending a cmd to the QuadCopter for each of the set cmds //
/////////////////////////////////////////////////////////////////////////////////////////
task test_send_cmd;
   input logic signed [15:0] t_ptch;
   input logic signed [15:0] t_roll;
   input logic signed [15:0] t_yaw;
   input logic signed [15:0] t_thrst;
   
   begin
      $display("--------------------------");
      $display("test_send_cmd: started.\n");

      test_cmd(SET_PTCH, t_ptch);
      test_cmd(SET_ROLL, t_roll);
      test_cmd(SET_YAW, t_yaw);
      test_cmd(SET_THRST, t_thrst);

      $display("test_send_cmd: passed.");
   end
endtask

///////////////////////////////////////////////////////////////////////////////////////////////
// task: test_calibrate - sends CALIBRATE cmd and checks if QuadCopter calibrates correctly //
/////////////////////////////////////////////////////////////////////////////////////////////
task test_calibrate;
   input logic signed [15:0] t_data;
   
   begin
      $display("--------------------------");
      $display("test_calibrate: started.\n");
      
      // sends CALIBRATE cmd (checks cmd_sent and resp)
      send_test_cmd(CALIBRATE, t_data);
      $display();
      
      // waits until strt_cal is asserted and check motors
      wait_strt_cal();
      check_motors_on();

      // after strt_cal is asserted inertial_cal should be 0
      @(posedge clk);
      check_inertial_cal(1'b1);
      
      // after cal_done is asserted inertial_cal should be 1      
      wait_cal_done();
      // need to wait for inertial_cal to deassert
      repeat(100) @(posedge clk);
      check_inertial_cal(1'b0);

      check_resp();

      $display("test_calibrate: passed.");
   end
endtask

/////////////////////////////////////////////////////////////////////////////////////////
// task: test_convergence - sends set cmds and waits for ptch, roll, yaw to calibrate //
///////////////////////////////////////////////////////////////////////////////////////
task test_convergence;
   input logic signed [15:0] t_ptch;
   input logic signed [15:0] t_roll;
   input logic signed [15:0] t_yaw;
   input logic signed [15:0] t_thrst;
   
   begin
      $display("--------------------------");
      $display("test_convergence: started.\n");

      // set thrst and wait till airborne
      test_cmd(SET_THRST, t_thrst);
      // check_airborne();

      // set the ptch and wait till convergence
      test_cmd(SET_PTCH, t_ptch);
      // input the cmd to designate test ptch values
      wait_convergence(SET_PTCH);
   
      // set the roll and wait till convergence
      test_cmd(SET_ROLL, t_roll);
      // input the cmd to designate test roll values
      wait_convergence(SET_ROLL);

      // set the yaw and wait till convergence
      test_cmd(SET_YAW, t_yaw);
      // input the cmd to designate test yaw values
      wait_convergence(SET_YAW);

      $display("test_convergence: passed.");
   end
endtask
 
/////////////////////////////////////////////////////////////////////////////////////////////////////
// task: test_mid_convergence - sends set cmds and sets a new desired before reaching convergence //
///////////////////////////////////////////////////////////////////////////////////////////////////
task test_mid_convergence;
   input logic signed [15:0] t_ptch;
   input logic signed [15:0] t_roll;
   input logic signed [15:0] t_yaw;
   input logic signed [15:0] t_thrst;
   input integer clk_cycles;
   
   begin
      $display("--------------------------");
      $display("test_mid_convergence: started.\n");

      // set thrst and wait till airborne
      test_cmd(SET_THRST, t_thrst);
      // check_airborne();

      // set the ptch, wait, and then stop before convergence
      test_cmd(SET_PTCH, t_ptch);
      // assumes our tb gives a correct number of clock cycles
      // before convergence occurs
      repeat(clk_cycles) @(posedge clk);
      // create new inverted value from input
      // could generate random to make more thorough
      // set new ptch for QuadCopter to converge to
      test_cmd(SET_PTCH, ~t_ptch);
      wait_convergence(SET_PTCH);

      // set the roll, wait, and then stop before convergence
      test_cmd(SET_ROLL, t_roll);
      // assumes our tb gives a correct number of clock cycles
      // before convergence occurs
      repeat(clk_cycles) @(posedge clk);
      // create new inverted value from input
      // could generate random to make more thorough
      // set new roll for QuadCopter to converge to
      test_cmd(SET_ROLL, ~t_roll);
      wait_convergence(SET_ROLL);

      // set the yaw, wait, and then stop before convergence
      test_cmd(SET_YAW, t_yaw);
      // assumes our tb gives a correct number of clock cycles
      // before convergence occurs
      repeat(clk_cycles) @(posedge clk);
      // create new inverted value from input
      // could generate random to make more thorough
      // set new yaw for QuadCopter to converge to
      test_cmd(SET_YAW, ~t_yaw);
      wait_convergence(SET_YAW);

      $display("test_mid_convergence: passed.");
   end
endtask

//////////////////////////////////////////////////////////////////////////////////////////////
// task: test_emer_land - sends EMER_LAND cmd and checks ptch, roll, & yaw and for landing //
////////////////////////////////////////////////////////////////////////////////////////////
task test_emer_land;
   input logic signed [15:0] t_data;
   
   begin
      $display("--------------------------");
      $display("test_emer_land: started.\n");
      
      // send EMER_LAND cmd (checks cmd_send and resp)
      test_cmd(EMER_LAND, t_data);

      // wait for ptch, roll & yaw to converge to 0
      wait_convergence(SET_PTCH);
      wait_convergence(SET_ROLL);
      wait_convergence(SET_YAW);

      // use seperate task apart from 'test_cmd' to test if thrst is 0
      check_thrst(16'h0000);
      
      // after convergence and setting thrust QuadCopter should not be airborne
      check_landed();

      $display("test_emer_land: passed.");            
   end
endtask

/////////////////////////////////////////////////////////////////
// task: test_mtrs_off - sends MTRS_OFF cmd and check are off //
///////////////////////////////////////////////////////////////
task test_mtrs_off;
   input logic signed [15:0] t_data;
   
   begin
      $display("--------------------------");
      $display("test_mtrs_off: started.\n");
      
      // send MTRS_OFF cmd (checks cmd_sent and resp)
      test_cmd(MTRS_OFF, t_data);

      check_motors_off();
      
      $display("test_mtrs_off: passed.");    
   end
endtask