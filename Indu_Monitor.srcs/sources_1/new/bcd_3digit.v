`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/05/16 15:19:50
// Design Name: 
// Module Name: bcd_3digit
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


module bcd_3digit #(
    parameter WIDTH = 8  //  ‰»ÎŒªøÌ
)(
    input         clk,
    input         rst,
    input  [WIDTH-1:0] bin,
    output reg [3:0] hund,
    output reg [3:0] ten,
    output reg [3:0] one
);

reg [WIDTH-1:0] bin_r;
reg [3:0] b2,b1,b0;
integer i;

always @(*) begin
    bin_r = bin;
    b2 = 4'd0;
    b1 = 4'd0;
    b0 = 4'd0;

    for(i=0; i<WIDTH; i=i+1) begin
        if(b2 >= 5) b2 = b2 + 3;
        if(b1 >=5) b1 = b1+3;
        if(b0 >=5) b0 = b0+3;
        {b2,b1,b0,bin_r} = {b2,b1,b0,bin_r} <<1;
    end
end

always @(posedge clk or posedge rst) begin
    if(rst) begin
        ten <=0; one <=0;hund <=0;
    end else begin
        hund <= b2;
        ten <= b1;
        one <= b0;
    end
end
    
    
endmodule
