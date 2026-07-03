`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/05/17 19:46:37
// Design Name: 
// Module Name: tb_fsm
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_fsm;
    reg key_s1_pulse;
    reg key_s2_pulse;
    reg key_s3_pulse;
    reg key_s4_pulse;
    reg clk;
    reg rst;
    reg [7:0] adc;
    reg adc_end;
    wire [3:0] data_1;
    wire [3:0] data_2;
    wire [3:0] data_3;
    wire [3:0] data_4;
    wire [3:0] data_5;
    wire [3:0] data_6;
    wire [3:0] data_7;
    wire [3:0] data_8;

    initial begin
        clk = 0;
    end
    always #10 clk = ~clk;
    
   initial begin
        rst = 1; 
        key_s1_pulse = 0;
        key_s2_pulse = 0;
        key_s3_pulse = 0;
        key_s4_pulse = 0;
        
        adc_end = 0;
        adc = 0;
        
        repeat(2)@(posedge clk);
            rst = 0;
            
   //////////////////////////////
        repeat(2)@(posedge clk);
            adc = 8'd30;
            adc_end = 1;
        repeat(1)@(posedge clk);
            adc_end = 0;
        
        
        repeat(5)@(posedge clk);
            key_s1_pulse = 1;
        @(posedge clk);
            key_s1_pulse = 0;
        
  //////////////////////////////////////      
        
        repeat(5)@(posedge clk);

            adc=8'd50;
            adc_end=1;
        
        @(posedge clk);
        
            adc_end=0;
        
        
            key_s1_pulse=1;
        
        @(posedge clk);
        
            key_s1_pulse=0;
            
 ////////////////////////////////////////////////
       repeat(5)@(posedge clk);

            adc=8'd50;
            adc_end=1;
        
        @(posedge clk);
        
            adc_end=0;
        
        
            key_s1_pulse=1;
        
        @(posedge clk);
        
            key_s1_pulse=0;      
            
 //////////////////////////////
         repeat(5)@(posedge clk);
            key_s4_pulse = 1;
        @(posedge clk);
            key_s4_pulse = 0;
 
 
 //////////////////////////
        repeat(5)@(posedge clk);
            key_s3_pulse = 1;
        @(posedge clk);
            key_s3_pulse = 0; 
            
            
            
       repeat(5)@(posedge clk);
            key_s3_pulse = 1;
        @(posedge clk);
            key_s3_pulse = 0;           
       
        repeat(5)@(posedge clk);
            key_s3_pulse = 1;
        @(posedge clk);
            key_s3_pulse = 0; 
        
        
        repeat(20)@(posedge clk);
     
     
     $stop;
  end


fsm 
fsm_uut(

    .key_s1_pulse(key_s1_pulse),
    .key_s2_pulse(key_s2_pulse),
    .key_s3_pulse(key_s3_pulse),
    .key_s4_pulse(key_s4_pulse),
    
    .clk(clk),
    .rst(rst),
    
    .adc(adc),
    .adc_end(adc_end),
    
    .data_1(data_1),
    .data_2(data_2),
    .data_3(data_3),
    .data_4(data_4),
    .data_5(data_5),
    .data_6(data_6),
    .data_7(data_7),
    .data_8(data_8)

);

endmodule
