`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/05/15 20:26:26
// Design Name: 
// Module Name: top
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


module top #(
    parameter P_SYS_CLK         = 28'd50_000_000 ,
    parameter P_IIC_SCL         = 28'd125_000    , 
    parameter P_DEVICE_ADDR     = 7'b101_0100 ,
    parameter P_ADDR_BYTE_NUM   = 8 'd1  ,  
    parameter P_DATA_BYTE_NUM   = 8 'd2,
    parameter COUNT_10MS = 25'd50_0000 ,
    parameter DATA_WIDTH = 32,
    parameter DATA_DEPTH = 16,
    parameter UART_BPS = 115200  
)
 (
    input clk,
    input rst,
    input s3,
    input s4,
    input s1,
    input s2,
    output wire [7:0] seven_segment,
    output wire [7:0] sel,
    inout iic_sda,
    output iic_scl,
    
    output tx,
    output wire     ds1302_ce                ,
    output wire     ds1302_sclk              ,
    inout  wire     ds1302_data               
);






//////////////////////////////////////////
    wire key_s1_pulse;
    wire key_s2_pulse;
    wire key_s3_pulse;
    wire key_s4_pulse;
    
key_debounce #(
    .COUNT_10MS(COUNT_10MS)
)
key_debounce_s1(
    .rst(rst),
    .clk(clk),
    .key_in(s1),
    .key_flag(key_s1_pulse)
);

key_debounce #(
    .COUNT_10MS(COUNT_10MS)
)
key_debounce_s2(
    .rst(rst),
    .clk(clk),
    .key_in(s2),
    .key_flag(key_s2_pulse)
);

key_debounce #(
    .COUNT_10MS(COUNT_10MS)
)
key_debounce_s3(
    .rst(rst),
    .clk(clk),
    .key_in(s3),
    .key_flag(key_s3_pulse)
);

key_debounce #(
    .COUNT_10MS(COUNT_10MS)
)
key_debounce_s4(
    .rst(rst),
    .clk(clk),
    .key_in(s4),
    .key_flag(key_s4_pulse)
);




/////////////////////////////////////////
    wire [7:0] adc;
    wire adc_end;


ad_ctrl#(
    .P_SYS_CLK(P_SYS_CLK),  
    .P_IIC_SCL         (P_IIC_SCL)    ,  
    .P_DEVICE_ADDR     (P_DEVICE_ADDR)   ,  
    .P_ADDR_BYTE_NUM   (P_ADDR_BYTE_NUM)          , 
    .P_DATA_BYTE_NUM (P_DATA_BYTE_NUM)              
)
ad_crtl_list(
    .clk(clk),
    .rst(rst),
    .adc_start(1),
    .adc_end(adc_end),
    .adc(adc),
    .iic_sda(iic_sda),
    .iic_scl(iic_scl)
);







///////////////////////////////////////////////////
    wire [3:0] data_1;
    wire [3:0] data_2;
    wire [3:0] data_3;
    wire [3:0] data_4;
    wire [3:0] data_5;
    wire [3:0] data_6;
    wire [3:0] data_7;
    wire [3:0] data_8;
    
    wire [7:0] pi_data;
    wire pi_flag;
    wire tx_busy;
    
    wire         [55:0]           ds_data ;
    wire         [   7: 0]        read_second             ;
    wire         [   7: 0]        read_minute             ;
    wire         [   7: 0]        read_hour               ;
    wire         [   7: 0]        read_date               ;
    wire         [   7: 0]        read_month              ;
    wire         [   7: 0]        read_week               ;
    wire         [   7: 0]        read_year               ;

    wire                         read_time_req            ;

fsm #(
    .DATA_WIDTH(DATA_WIDTH),
    .DATA_DEPTH(DATA_DEPTH)
)
fsm_uut(

    .key_s1_pulse(key_s1_pulse),
    .key_s2_pulse(key_s2_pulse),
    .key_s3_pulse(key_s3_pulse),
    .key_s4_pulse(key_s4_pulse),
    
    .clk(clk),
    .rst(rst),
    .tx_busy(tx_busy),
    .adc(adc),
    .adc_end(adc_end),
    
    .ds_data(ds_data),
    .data_1(data_1),
    .data_2(data_2),
    .data_3(data_3),
    .data_4(data_4),
    .data_5(data_5),
    .data_6(data_6),
    .data_7(data_7),
    .data_8(data_8),
    .pi_data(pi_data),
    .pi_flag(pi_flag)

);
///////////////////////////////////////////

seven_segment 
#(
    .COUNT_10MS(COUNT_10MS)
)
seg_uut(
    .data_1(data_1),
    .data_2(data_2),
    .data_3(data_3),
    .data_4(data_4),
    .data_5(data_5),
    .data_6(data_6),
    .data_7(data_7),
    .data_8(data_8),
    .rst(rst),
    .clk(clk),
    .seven_segment(seven_segment),
    .sel(sel)
 );
//////////////////////////////////////////////////

    
    assign  read_time_req = key_s1_pulse;
    assign  ds_data = {read_year,read_month,read_date,read_week,read_hour,read_minute,read_second};
    
ds1302_wr_drive ds1302_wr_drive_list(
        .ds1302_clk(clk),
        .ds1302_rst(rst),

        .write_second(),
        .write_minute(), 
        .write_hour()               ,
        .write_date()               ,
        .write_month()              ,
        .write_week()               ,
        .write_year()               ,
    
        .write_time_req()           ,
        .write_time_ack()           ,


        .read_second(read_second)             ,
        .read_minute(read_minute)             ,
        .read_hour(read_hour)               ,
        .read_date(read_date)               ,
        .read_month(read_month)              ,
        .read_week(read_week)               ,
        .read_year(read_year)               ,
    
        .read_time_req(read_time_req)            ,
        .read_time_ack()            ,
    
    
        .ds1302_ce(ds1302_ce)                ,
        .ds1302_sclk(ds1302_sclk)              ,
        .ds1302_data(ds1302_data)              
 );  

uart_tx #(
    .UART_BPS(UART_BPS),
    .P_SYS_CLK(P_SYS_CLK),
    .DATA_WIDTH(DATA_WIDTH)
)
uart_tx_list
(
    .clk(clk),
    .rst(rst),
    .pi_data(pi_data),
    .pi_flag(pi_flag),
    .tx(tx),
    .tx_busy(tx_busy)
);   
 
endmodule
