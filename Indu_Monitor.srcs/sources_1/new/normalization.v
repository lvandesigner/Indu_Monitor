`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// normalization — 最大-最小归一化 [0, 100]
// 2026-07-04: 单周期 / 改为 15拍移位减除法器，消除 54 级组合逻辑瓶颈
//             原 CARRY4 ~130 → 除法拆散后关键路径 < 10ns
//////////////////////////////////////////////////////////////////////////////////

module normalization #(
    parameter DATA_WIDTH = 32,
    parameter DATA_DEPTH = 16
)(
    input  wire [DATA_WIDTH*DATA_DEPTH - 1:0] din_flat,
    input  clk,
    input  rst,
    input  wire [4:0]                     valid_count,
    output reg  [8*DATA_DEPTH - 1:0]      result_val_flat
);

    reg [7:0] max_val;
    reg [7:0] min_val;
    reg [DATA_WIDTH - 1:0] din [DATA_DEPTH - 1:0];
    reg [7:0] result_val [DATA_DEPTH - 1:0];
    reg [2:0] state;
    reg [4:0] cnt;
    integer   i;

    // ---- 流水线/除法器寄存器 ----
    reg        pipe_stage;           // 0=乘减, 1=启动除法
    reg [14:0] diff_x100_reg;        // (din - min) * 100, ≤12700, 14bit
    reg [7:0]  denom_reg;            // max - min, 0 表示 max==min

    // ---- 顺序移位减除法器 ----
    reg [14:0] dividend;             // 被除数, 移位用
    reg [7:0]  divisor;              // 除数
    reg [7:0]  quotient;             // 商 (结果 0~100)
    reg [3:0]  div_bit;              // 当前处理的 bit (14→0, 共15拍)

    localparam S_FIND    = 3'd0;
    localparam S_COMPUTE = 3'd1;
    localparam S_DIV     = 3'd2;     // ★新: 多拍除法
    localparam S_FLAT    = 3'd3;

    // ---- din_flat 持续解包 ----
    always @(posedge clk) begin
        if(rst) begin
            for(i = 0; i < DATA_DEPTH; i = i + 1)
                din[i] <= 0;
        end
        else begin
            for(i = 0; i < DATA_DEPTH; i = i + 1)
                din[i] <= din_flat[i*DATA_WIDTH+:DATA_WIDTH];
        end
    end

    // ---- 主状态机 ----
    always @(posedge clk) begin
        if(rst) begin
            state          <= S_FIND;
            cnt            <= 0;
            max_val        <= 0;
            min_val        <= 0;
            pipe_stage     <= 0;
            diff_x100_reg  <= 0;
            denom_reg      <= 0;
            dividend       <= 0;
            divisor        <= 0;
            quotient       <= 0;
            div_bit        <= 0;
            for(i = 0; i < DATA_DEPTH; i = i + 1)
                result_val[i] <= 0;
            result_val_flat <= 0;
        end
        else begin
            case(state)

                // ---------- S_FIND: 找 max/min ----------
                S_FIND: begin
                    if(valid_count == 0) begin
                        state <= S_FLAT;
                    end
                    else if(cnt == 0) begin
                        max_val <= din[0][7:0];
                        min_val <= din[0][7:0];
                        cnt     <= 1;
                    end
                    else if(cnt < valid_count) begin
                        if(din[cnt][7:0] > max_val)
                            max_val <= din[cnt][7:0];
                        if(din[cnt][7:0] < min_val)
                            min_val <= din[cnt][7:0];
                        cnt <= cnt + 1;
                    end
                    else begin
                        cnt        <= 0;
                        pipe_stage <= 0;
                        state      <= S_COMPUTE;
                    end
                end

                // ---------- S_COMPUTE: 乘减, 启动除法 ----------
                S_COMPUTE: begin
                    if(!pipe_stage) begin
                        // 第1拍: (din - min) * 100, 锁存分母
                        if(cnt < valid_count) begin
                            diff_x100_reg <= (din[cnt][7:0] - min_val) * 100;
                            denom_reg     <= max_val - min_val;
                            pipe_stage    <= 1;
                        end
                        else begin
                            state <= S_FLAT;
                        end
                    end
                    else begin
                        // 第2拍: 启动移位减除法器
                        if(denom_reg == 0) begin
                            // max == min: 结果直接给 0, 跳过除法
                            result_val[cnt] <= 0;
                            pipe_stage <= 0;
                            if(cnt == valid_count - 1)
                                state <= S_FLAT;
                            cnt <= cnt + 1;
                        end
                        else begin
                            dividend <= diff_x100_reg;
                            divisor  <= denom_reg;
                            quotient <= 0;
                            div_bit  <= 14;
                            state    <= S_DIV;
                        end
                    end
                end

                // ---------- S_DIV: 15拍移位减除法 ----------
                S_DIV: begin
                    // 左移被除数, 商左移
                    dividend <= {dividend[13:0], 1'b0};

                    if(dividend[14:7] >= divisor) begin
                        // 够减: 差写回高8位, 商最低位置1
                        dividend[14:7] <= dividend[14:7] - divisor;
                        quotient       <= {quotient[6:0], 1'b1};
                    end
                    else begin
                        // 不够减: 商最低位置0
                        quotient       <= {quotient[6:0], 1'b0};
                    end

                    if(div_bit == 0) begin
                        // 最后一拍: 存结果, 回 S_COMPUTE 算下一个
                        result_val[cnt] <= quotient;
                        pipe_stage      <= 0;
                        state           <= S_COMPUTE;
                        if(cnt == valid_count - 1)
                            state <= S_FLAT;
                        cnt <= cnt + 1;
                    end
                    else begin
                        div_bit <= div_bit - 1;
                    end
                end

                // ---------- S_FLAT: 拍平输出 ----------
                S_FLAT: begin
                    for(i = 0; i < DATA_DEPTH; i = i + 1)
                        result_val_flat[i*8+:8] <= result_val[i];
                    cnt   <= 0;
                    state <= S_FIND;
                end

                default: state <= S_FIND;

            endcase
        end
    end

endmodule
