module moving_average #(
    parameter DATA_DEPTH = 16,
    parameter DATA_WIDTH = 8,
    parameter WINDOW = 3
)(
    input clk,
    input rst,
    input [DATA_DEPTH*DATA_WIDTH-1:0] din_flat,
    input [4:0] valid_cnt,
    output reg [DATA_DEPTH*DATA_WIDTH-1:0] dout_flat
);

    // ==================== 输入寄存 ====================
    reg [DATA_DEPTH*DATA_WIDTH-1:0] din_flat_r;
    reg [4:0]                       valid_cnt_r;

    // ==================== 内部数组 ====================
    reg [DATA_WIDTH-1:0] din  [0:DATA_DEPTH-1];   // 解包后的输入
    reg [DATA_WIDTH-1:0] dout [0:DATA_DEPTH-1];   // 滑动平均结果

    // ==================== 时序计算: 每拍算1个, 避免并行除法器 ====================
    reg  [4:0] idx;          // 当前正在计算的元素索引

    integer i;

    // ---- 输入打拍 ----
    always @(posedge clk) begin
        if (rst) begin
            din_flat_r  <= 0;
            valid_cnt_r <= 0;
        end
        else begin
            din_flat_r  <= din_flat;
            valid_cnt_r <= valid_cnt;
        end
    end

    // ---- 解包: 组合逻辑, 始终反映 din_flat_r ----
    always @(*) begin
        for (i = 0; i < DATA_DEPTH; i = i + 1)
            din[i] = din_flat_r[i*DATA_WIDTH +: DATA_WIDTH];
    end

    // ---- 时序状态机: 逐元素计算滑动平均 ----
    always @(posedge clk) begin
        if (rst) begin
            idx <= 0;
            for (i = 0; i < DATA_DEPTH; i = i + 1)
                dout[i] <= 0;
        end
        else if (valid_cnt_r < WINDOW) begin
            // 数据不足: 全部清零, 停在 IDLE
            idx <= 0;
            for (i = 0; i < DATA_DEPTH; i = i + 1)
                dout[i] <= 0;
        end
        else begin
            // ---- 有效范围内 计算当前元素 ----
            if (idx >= WINDOW - 1 && idx < DATA_DEPTH && idx < valid_cnt_r) begin
                dout[idx] <= (din[idx] + din[idx-1] + din[idx-2]) / WINDOW;
            end

            // ---- 索引推进: 到头后回到第一个有效位置, 持续刷新 ----
            if (idx < DATA_DEPTH - 1 && idx < valid_cnt_r - 1)
                idx <= idx + 1;
            else
                idx <= WINDOW - 1;   // 循环: 回到第一个有效输出位置
        end
    end

    // ---- 输出拍平: 组合逻辑 ----
    always @(*) begin
        dout_flat = 0;
        for (i = 0; i < DATA_DEPTH; i = i + 1)
            dout_flat[i*DATA_WIDTH +: DATA_WIDTH] = dout[i];
    end

endmodule
