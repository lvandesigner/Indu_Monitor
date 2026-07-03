`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/05/15 20:27:43
// Design Name: 
// Module Name: seven_segment
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


module seven_segment #(
    parameter COUNT_10MS = 25'd50_0000
)(
    input [3:0] data_1,
    input [3:0] data_2,
    input [3:0] data_3,
    input [3:0] data_4,
    input [3:0] data_5,
    input [3:0] data_6,
    input [3:0] data_7,
    input [3:0] data_8,
    input clk,
    input rst,
    output reg [7:0] seven_segment,
    output reg [7:0] sel
    );
    reg [3:0] data;
    reg [2:0] bits;
    reg [24:0] cnt;
    
    always @(*)begin
        case(data)
            4'b0000: seven_segment <= 8'hC0;
            4'b0001: seven_segment <= 8'hF9;
            4'b0010: seven_segment <= 8'hA4;
            4'b0011: seven_segment <= 8'hB0;
            4'b0100: seven_segment <= 8'h99;
            4'b0101: seven_segment <= 8'h92;
            4'b0110: seven_segment <= 8'h82;
            4'b0111: seven_segment <= 8'hF8;           
            4'b1000: seven_segment <= 8'h80;
            4'b1001: seven_segment <= 8'h90;
            4'b1010: seven_segment <= 8'h88;
            4'b1011: seven_segment <= 8'h83;    
            4'b1100: seven_segment <= 8'hC6;
            4'b1101: seven_segment <= 8'hA1;
            4'b1110: seven_segment <= 8'h85;
            4'b1111: seven_segment <= 8'b1011_1111;
            default:seven_segment <= 8'hFF;   
        endcase
     end
     
        always @(posedge clk)begin
            if(rst)begin
                cnt <= 0;
            end
            else if(cnt == COUNT_10MS)begin
                cnt <= 0;
            end
            else begin
                cnt <= cnt + 1;
            end
        end
        
        always @(posedge clk)begin
            if(rst)begin
                bits <= 0;
            end
            else if(cnt == COUNT_10MS - 1)begin
                if(bits == 4'd7)begin
                    bits <= 0;
                end
                else begin
                    bits <= bits + 1;
                end
            end
        end
            
        always @(*)begin
            case(bits)
                4'd0: begin data <= data_1;sel <= 8'b1111_1110;end
                4'd1: begin data <= data_2;sel <= 8'b1111_1101;end
                4'd2: begin data <= data_3;sel <= 8'b1111_1011;end
                4'd3: begin data <= data_4;sel <= 8'b1111_0111;end
                4'd4: begin data <= data_5;sel <= 8'b1110_1111;end
                4'd5: begin data <= data_6;sel <= 8'b1101_1111;end
                4'd6: begin data <= data_7;sel <= 8'b1011_1111;end
                4'd7: begin data <= data_8;sel <= 8'b0111_1111;end
            endcase
       end

endmodule
