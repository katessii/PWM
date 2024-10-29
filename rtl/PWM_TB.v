`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   14:16:11 05/19/2018
// Design Name:   PWM
// Module Name:   C:/Xilinx/PWM/PWM_TB.v
// Project Name:  PWM
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: PWM
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module PWM_TB;
	// Inputs
	reg clk, reset;
	// Outputs
	wire LED;
	// Instantiate the Unit Under Test (UUT)
	PWM uut (.clk(clk), .LED(LED), .reset(reset));
	// Initialize Inputs
	initial 
		begin
		clk = 1'd0;
		reset = 1'd1;
		#1;
		reset = 1'd0;
		end
    initial 
		forever #0.001 clk = ~clk;

//Uncomment the following code if you need console output
//Warning! May reduce ISim simulation speed

//	always @ (posedge clk)
	//$display ("clk=%d, pwm_inp=%d, pwm_cnt=%d, LED=%d", clk, uut.pwm_inp, uut.pwm_cnt, LED);
	
endmodule

