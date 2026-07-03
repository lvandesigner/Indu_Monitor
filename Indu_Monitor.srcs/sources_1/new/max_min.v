module max_min#(
    parameter DATA_WIDTH = 8,
    parameter DATA_DEPTH = 16
)
(
    input clk,
    input rst,
    input [DATA_DEPTH*DATA_WIDTH - 1:0]din_flat,
    input [4:0] valid_cnt,
    output reg [DATA_WIDTH - 1:0]max_val,
    output reg [DATA_WIDTH - 1:0]min_val
);
    reg [DATA_WIDTH - 1:0] din [0:DATA_DEPTH - 1];
    reg [DATA_DEPTH*DATA_WIDTH - 1:0]din_flat_r;
    reg [4:0] valid_cnt_r;
    wire [DATA_WIDTH -1:0]L1_min[7:0];
    wire [DATA_WIDTH -1:0]L1_max[7:0];
    wire [DATA_WIDTH -1:0]L2_min[3:0];
    wire [DATA_WIDTH -1:0]L2_max[3:0];
    wire [DATA_WIDTH -1:0]L3_min[1:0];
    wire [DATA_WIDTH -1:0]L3_max[1:0];

    reg [DATA_WIDTH - 1:0] din_max [0:DATA_DEPTH - 1];
    reg [DATA_WIDTH - 1:0] din_min [0:DATA_DEPTH - 1] ;
    wire [DATA_WIDTH - 1:0] max_val_w;
    wire [DATA_WIDTH - 1:0] min_val_w;
    integer i;
    genvar g;

    always @(posedge clk) begin
        if(rst)begin
            din_flat_r <=0;
            valid_cnt_r <=0;
        end
        else begin  
            din_flat_r <= din_flat;
            valid_cnt_r <= valid_cnt;
        end
    end

    always @(*)begin
        for(i=0;i<DATA_DEPTH;i = i+1)begin
            din[i] = din_flat_r[i*DATA_WIDTH+:DATA_WIDTH];
        end
    end


    always @(*)begin
        for(i=0;i<DATA_DEPTH;i = i+1)begin
            if(i<valid_cnt_r)begin
                din_max[i] = din[i];
                din_min[i] = din[i];
            end
            else begin
                din_max[i] = 8'h00;
                din_min[i]= 8'hFF;
            end
        end
    end
        
    generate
        for(g=0;g<8;g=g+1)begin:L1
            assign L1_max[g] = din_max[2*g+1]>din_max[2*g]?din_max[2*g+1]:din_max[2*g];
            assign L1_min[g] = din_min[2*g+1]<din_min[2*g]?din_min[2*g+1]:din_min[2*g];
        end
        for(g=0;g<4;g=g+1)begin:L2
            assign L2_max[g] = L1_max[2*g+1]>L1_max[2*g]?L1_max[2*g+1]:L1_max[2*g];
            assign L2_min[g] = L1_min[2*g+1]<L1_min[2*g]?L1_min[2*g+1]:L1_min[2*g];
        end
        for(g=0;g<2;g=g+1)begin:L3
            assign L3_max[g] = L2_max[2*g+1]>L2_max[2*g]?L2_max[2*g+1]:L2_max[2*g];
            assign L3_min[g] = L2_min[2*g+1]<L2_min[2*g]?L2_min[2*g+1]:L2_min[2*g];
        end
    endgenerate

    
    assign max_val_w = L3_max [1]>L3_max[0]?L3_max [1]:L3_max [0];
    assign min_val_w = L3_min [1]<L3_min[0]?L3_min [1]:L3_min [0];

    always @(posedge clk)begin
        if(rst)begin
            max_val <= 0;
            min_val <= 0;
        end
        else begin
            max_val <= max_val_w;
            min_val <= min_val_w;
        end
    end




endmodule