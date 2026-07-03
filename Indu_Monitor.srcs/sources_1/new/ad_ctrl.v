`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/05/15 20:28:09
// Design Name: 
// Module Name: ad_ctrl
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


module ad_ctrl#(
    parameter P_SYS_CLK         = 28'd50_000_000 ,
    parameter P_IIC_SCL         = 28'd125_000    , 
    parameter P_DEVICE_ADDR     = 7'b101_0100 ,
    parameter P_ADDR_BYTE_NUM   = 8 'd1  ,  
    parameter P_DATA_BYTE_NUM   = 8 'd2   
    )
(
    input clk,
    input rst,
    input adc_start,
    output adc_end,
    output [7:0] adc,
    inout iic_sda,
    output iic_scl
    );
    wire [15:0] adc_rdata;
    
    assign adc = adc_rdata[11:4];
    
iic_drive
#(
    .P_SYS_CLK(P_SYS_CLK),  
    .P_IIC_SCL         (P_IIC_SCL)    ,  
    .P_DEVICE_ADDR     (P_DEVICE_ADDR)   ,  
    .P_ADDR_BYTE_NUM   (P_ADDR_BYTE_NUM)          , 
    .P_DATA_BYTE_NUM (P_DATA_BYTE_NUM)              
)
iic_drive_list(
    .iic_clk(clk),
    .iic_rst(rst),
    .iic_start(adc_start),
    .iic_ready(adc_end),
    .iic_rw_flag(1),
    .iic_word_addr(0),
    .iic_wdata(),
    .iic_rdata (adc_rdata),
    .iic_rdata_valid(),
    .iic_ack_error(),
    .iic_scl(iic_scl),    
    .iic_sda(iic_sda) 

);
    
endmodule
