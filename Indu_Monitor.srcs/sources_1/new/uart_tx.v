`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/05/17 22:17:36
// Design Name: 
// Module Name: uart_tx
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


module uart_tx#(
    parameter UART_BPS = 115200,
    parameter P_SYS_CLK         = 28'd50_000_000,
    parameter DATA_WIDTH = 32 
)(
    input clk,
    input rst,
    input [7:0] pi_data,
    input pi_flag,
    output reg tx,
    output wire tx_busy

    );
    
    localparam BAUD_CNT_MAX = P_SYS_CLK/UART_BPS;
    
    reg [12:0] baud_cnt;
    reg bit_flag;
    reg [3:0] bit_cnt;
    reg work_en;
    reg [7:0] tx_data;
    
    assign tx_busy = work_en;
    
    always @(posedge clk)begin
        if(rst)begin
            tx_data <=0;
        end
        else if(pi_flag && !work_en)begin
            tx_data <= pi_data;
        end
    end
    
    always @(posedge clk)begin
        if(rst)begin
            work_en <= 0;
        end
        else if(!work_en && pi_flag)begin
            work_en <= 1;
        end
        else if(bit_cnt ==9 && bit_flag)begin
            work_en <= 0;
        end
    end
    
    always @(posedge clk)begin
        if(rst)begin
            baud_cnt <= 0;
        end
        else if(!work_en || baud_cnt == BAUD_CNT_MAX - 1)begin
            baud_cnt <= 0;
        end
        else begin
            baud_cnt <= baud_cnt + 1;
        end
    end
    
    always @(posedge clk)begin
        if(rst)begin
            bit_flag <= 0;
        end
        else if(baud_cnt == BAUD_CNT_MAX - 1)begin
            bit_flag <= 1;
        end
        else begin
            bit_flag <= 0;
        end
    end
    
    always @(posedge clk)begin
        if(rst)begin
            bit_cnt <= 0;
        end
        else if(!work_en)begin
            bit_cnt <= 0;
        end
        else if(bit_flag)begin
            if(bit_cnt == 4'd9)begin
                bit_cnt <= 0;
            end
            else begin
                bit_cnt <= bit_cnt + 1;
            end
        end
     end
     
     always @(posedge clk)begin
        if(rst)begin
            tx <= 0;
        end
        else begin
            case(bit_cnt)
                4'd0:   tx <= 0;
                4'd1:   tx <= tx_data[0];
                4'd2:   tx <= tx_data[1];
                4'd3:   tx <= tx_data[2];
                4'd4:   tx <= tx_data[3];
                4'd5:   tx <= tx_data[4];
                4'd6:   tx <= tx_data[5];
                4'd7:   tx <= tx_data[6];
                4'd8:   tx <= tx_data[7];
                4'd9:   tx <= 1;
                default:tx <= 0;
            endcase
       end
    end
        
    
    
        
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
endmodule
