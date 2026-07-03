module rle_encode#(
    parameter DATA_DEPTH = 16,
    parameter DATA_WIDTH = 8,
    parameter CNT_WIDTH  = 8      // 游程计数位宽，独立于数据位宽，防止长重复溢出
)(
    input  clk,
    input  rst,
    input  [DATA_DEPTH*DATA_WIDTH-1:0] din_flat,
    input  [4:0] valid_cnt,
    input  start,

    output reg busy,                                                    // 1=编码中，外部不可发起新请求
    output reg compressed,                                              // 1=压缩有效，0=压缩无效应使用原始数据
    output reg [4:0] seg_num,                                           // 压缩后段数
    output reg [DATA_DEPTH*DATA_WIDTH-1:0] value_flat,                  // 值序列
    output reg [DATA_DEPTH*DATA_WIDTH-1:0] value_cnt_flat,              // 计数序列
    output reg [DATA_DEPTH*DATA_WIDTH-1:0] raw_flat,                    // 直通原始数据（compressed=0 时有效）
    output reg done
);

    // ==================== 内部寄存器 ====================
    reg [4:0] idx;
    reg [4:0] seg_cnt;
    reg [DATA_WIDTH-1:0] c_val;
    reg [CNT_WIDTH-1:0]  c_val_cnt;                                     // 加宽计数器
    reg [DATA_WIDTH-1:0] din      [DATA_DEPTH-1:0];
    reg [DATA_WIDTH-1:0] value    [DATA_DEPTH-1:0];
    reg [CNT_WIDTH-1:0]  value_cnt[DATA_DEPTH-1:0];                     // 加宽计数器
    reg [4:0] valid_cnt_r;
    reg [DATA_DEPTH*DATA_WIDTH-1:0] din_flat_r;                          // 拍下来用于直通

    reg [1:0] state;
    integer i;

    // 计数上限常量
    localparam CNT_MAX = {CNT_WIDTH{1'b1}};                              // 全1 = 2^CNT_WIDTH - 1

    always @(posedge clk) begin
        if (rst) begin
            state      <= 2'd0;
            busy       <= 1'b0;
            compressed <= 1'b0;
            seg_cnt    <= 0;
            idx        <= 0;
            valid_cnt_r <= 0;
            c_val      <= 0;
            c_val_cnt  <= 0;
            done       <= 0;
            seg_num    <= 0;
            din_flat_r <= 0;
            value_flat     <= 0;
            value_cnt_flat <= 0;
            raw_flat       <= 0;
            for (i = 0; i < DATA_DEPTH; i = i + 1) begin
                din[i]       <= 0;
                value[i]     <= 0;
                value_cnt[i] <= 0;
            end
        end
        else begin
            done <= 1'b0;
            case (state)
                // ===== IDLE：等待启动 =====
                2'd0: begin
                    if (start) begin
                        busy        <= 1'b1;
                        compressed  <= 1'b0;
                        state       <= 2'd1;
                        seg_cnt     <= 0;
                        idx         <= 0;
                        valid_cnt_r <= valid_cnt;
                        c_val       <= 0;
                        c_val_cnt   <= 0;
                        din_flat_r  <= din_flat;
                        for (i = 0; i < DATA_DEPTH; i = i + 1) begin
                            din[i]       <= din_flat[i*DATA_WIDTH+:DATA_WIDTH];
                            value[i]     <= 0;
                            value_cnt[i] <= 0;
                        end
                    end
                end

                // ===== PROCESS：逐元素扫描编码 =====
                2'd1: begin
                    if (idx < valid_cnt_r) begin
                        // ---- 第一个段 ----
                        if (seg_cnt == 0) begin
                            c_val     <= din[idx];
                            seg_cnt   <= 1;
                            c_val_cnt <= 1;
                        end
                        // ---- 与当前段值相同 且 计数未满：累加 ----
                        else if (din[idx] == c_val && c_val_cnt < CNT_MAX) begin
                            c_val_cnt <= c_val_cnt + 1;
                        end
                        // ---- 值不同 或 计数已满：关闭旧段，开启新段 ----
                        else begin
                            value[seg_cnt - 1]     <= c_val;
                            value_cnt[seg_cnt - 1] <= c_val_cnt;
                            c_val                  <= din[idx];
                            seg_cnt                <= seg_cnt + 1;
                            c_val_cnt              <= 1;
                        end

                        idx <= idx + 1;
                    end
                    else begin
                        state <= 2'd2;
                    end
                end

                // ===== FINALIZE：写入最后一段 =====
                2'd2: begin
                    if (seg_cnt > 0) begin
                        value_cnt[seg_cnt - 1] <= c_val_cnt;
                        value[seg_cnt - 1]     <= c_val;
                    end
                    state <= 2'd3;
                end

                // ===== OUTPUT：输出 + 压缩率判断 =====
                2'd3: begin
                    // 压缩率判断：2*seg_cnt < valid_cnt_r 时压缩有效
                    // 即编码后数据量 = seg_cnt * 2 * DATA_WIDTH
                    //   原始数据量   = valid_cnt_r * DATA_WIDTH
                    // 压缩有效条件：seg_cnt < valid_cnt_r / 2
                    if (seg_cnt * 2 < valid_cnt_r) begin
                        compressed <= 1'b1;
                        seg_num    <= seg_cnt;
                        for (i = 0; i < DATA_DEPTH; i = i + 1) begin
                            value_flat[i*DATA_WIDTH+:DATA_WIDTH]     <= value[i];
                            value_cnt_flat[i*DATA_WIDTH+:DATA_WIDTH] <= value_cnt[i];
                        end
                    end
                    else begin
                        // 压缩无效：直通原始数据
                        compressed <= 1'b0;
                        seg_num    <= valid_cnt_r;
                        raw_flat   <= din_flat_r;
                    end

                    done  <= 1'b1;
                    busy  <= 1'b0;
                    state <= 2'd0;
                end

                default: state <= 2'd0;
            endcase
        end
    end

endmodule
