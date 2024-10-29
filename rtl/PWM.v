`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:15:19 05/19/2018 
// Design Name: 
// Module Name:    PWM 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module PWM(clk, reset, LED);
	input clk, reset;
	output LED;

reg [26:0] cnt;
reg [3:0] pwm_cnt;

//Input counter
always @(posedge clk)
	if (reset)
		cnt <= 27'd0;
	else
		cnt<=cnt+27'd1;

wire [3:0] pwm_inp = cnt[26] ? ~cnt[25:22]: cnt[25:22];

//PWM comparator
always @(posedge clk)
	if (reset)
		pwm_cnt <= 4'd0;
	else
	    pwm_cnt <= pwm_cnt + 4'd1;
		
assign LED = (pwm_cnt<pwm_inp);

endmodule
