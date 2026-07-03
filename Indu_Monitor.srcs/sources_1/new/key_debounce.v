`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/05/15 20:26:54
// Design Name: 
// Module Name: key_debounce
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


module key_debounce#(
    parameter COUNT_10MS = 25'd50_0000
)(
    input clk,
    input rst,
    input key_in,
    output reg key_flag
    );
    
    reg [24:0] cnt;
    
    always @(posedge clk)begin
        if(rst)begin
            cnt <= 0;
        end else if(!key_in)begin
            if(cnt ==  COUNT_10MS)begin
                cnt <= cnt;
            end
            else begin
                cnt <= cnt + 1;
            end
        end
        else begin
            cnt <= 0;
        end
    end 
    
    always @(posedge clk)begin
        if(rst)begin
            key_flag <= 1'b0;
        end
        else if(cnt == COUNT_10MS - 1)begin
            key_flag <= 1'b1;
        end
        else begin
            key_flag <= 1'b0;      
        end
    end

    
endmodule
