`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2026/05/15 20:26:41
// Design Name:
// Module Name: fsm
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//   2026-06-04: 适配新版 max_min(去rank,加valid_cnt, DATA_WIDTH=8)
//               适配新版 moving_average(加valid_cnt, dout_flat改名, DATA_WIDTH=8)
//               适配新版 rle_encode(时序化, 加clk/rst/start/busy/done, 端口改名)
//               统一 max_min/moving_average/rle_encode 共享 din_flat_8bit(128bit)
//               normalization 保持原接口不变(DATA_WIDTH=32, din_flat_3)
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module fsm #(
    parameter DATA_WIDTH = 32,
    parameter DATA_DEPTH = 16
)(
    input key_s1_pulse,
    input key_s2_pulse,
    input key_s3_pulse,
    input key_s4_pulse,
    input clk,
    input rst,
    input [7:0] adc,
    input adc_end,
    input [55:0] ds_data,
    input tx_busy,
    output reg [3:0] data_1,
    output reg [3:0] data_2,
    output reg [3:0] data_3,
    output reg [3:0] data_4,
    output reg [3:0] data_5,
    output reg [3:0] data_6,
    output reg [3:0] data_7,
    output reg [3:0] data_8,
    output reg [7:0] pi_data,
    output reg pi_flag
    );

    localparam RECORD = 0;
    localparam RESULT = 1;


    reg [2*DATA_WIDTH - 1:0] TX_DATA [DATA_DEPTH - 1:0];
    reg [DATA_WIDTH - 1:0] buff_data [DATA_DEPTH - 1:0];
    reg [DATA_WIDTH - 1:0] buff_data_adc [DATA_DEPTH - 1:0];
    reg [DATA_WIDTH - 1:0] buff_time [DATA_DEPTH - 1:0];
    reg [4:0] result_index_1;
    reg [4:0] result_index_2;
    reg [4:0] result_index_3;
    reg [4:0] result_index_4;
    reg [4:0] index;
    reg [4:0] send_cnt;
    reg [4:0] byte_cnt;
    reg send_flag;
    reg send_phase;          // 0=原始数据, 1=算法结果
    reg [7:0] result_byte_cnt;
    reg [7:0] result_total;
    reg state;
    reg [55:0] ds_data_r;
    reg [7:0] adc_r;
    reg [7:0] adc_value;
    reg [2:0] bits_1;

    reg [7:0] rank_value;
    reg [7:0] result_value;

    // ---- max_min 输出: 只有值, 无 rank ----
    wire [7:0] min_val;
    wire [7:0] max_val;
    reg [7:0] min_val_r;
    reg [7:0] max_val_r;

    // ---- 共享 8-bit 拍平数据: max_min / moving_average / rle_encode 共用 ----
    reg  [DATA_DEPTH*8-1:0]        din_flat_8bit;
    // ---- normalization 保持 32-bit 拍平数据 ----
    reg  [DATA_DEPTH*DATA_WIDTH-1:0] din_flat_3;

    // ---- moving_average 输出 ----
    wire [DATA_DEPTH*8 - 1 : 0] result_flat_2;
    // ---- normalization 输出 ----
    wire [DATA_DEPTH*8 - 1 : 0] result_flat_3;
    // ---- rle_encode 输出 ----
    wire [DATA_DEPTH*8 - 1 : 0] result_flat_4;    // value_cnt_flat (count序列)
    wire [DATA_DEPTH*8 - 1 : 0] value_flat_4;     // value序列
    wire [4:0]                  seg_num;
    reg  [4:0]                  seg_num_r;

    // ---- rle_encode 控制信号 (新: 时序模块握手) ----
    reg                         rle_start;
    wire                        rle_busy;
    wire                        rle_compressed;
    wire                        rle_done;
    wire [DATA_DEPTH*8-1:0]     rle_raw_flat;     // 压缩无效时的直通数据

    reg [7:0] result_2 [0:DATA_DEPTH-1];
    reg [7:0] result_3 [0:DATA_DEPTH-1];
    reg [7:0] result_4 [0:DATA_DEPTH-1];         // RLE count 数组
    reg [7:0] rle_value_4 [0:DATA_DEPTH-1];       // RLE value 数组

    wire [3:0] rank_value_one;
    wire [3:0] rank_value_ten;
    wire [3:0] result_value_one;
    wire [3:0] result_value_ten;
    wire [3:0] result_value_hund;

    wire [3:0] adc_one;
    wire [3:0] adc_ten;
    wire [3:0] adc_hund;
    wire [3:0] adc_value_one;
    wire [3:0] adc_value_ten;
    wire [3:0] adc_value_hund;

    // seg_num 寄存
   always @(posedge clk)begin
        if(rst)begin
            seg_num_r <= 0;
        end
        else begin
            seg_num_r <= seg_num;
        end
   end

   // max_val_r / min_val_r 寄存 (max_min 输出纯组合 → 打拍)
   always @(posedge clk)begin
        if(rst)begin
            max_val_r <= 0;
        end
        else begin
            max_val_r <= max_val;
        end
   end

   always @(posedge clk)begin
        if(rst)begin
            min_val_r <= 0;
        end
        else begin
            min_val_r <= min_val;
        end
   end


    // KEY0→录入界面  KEY1→结果界面  KEY2(清零)→录入界面
    always @(posedge clk)begin
        if(rst)begin
            state <= RECORD;
        end
        else begin
            if(key_s1_pulse)                // KEY0: 录入数据 → 录入界面
                state <= RECORD;
            else if(key_s2_pulse)            // KEY1: 算法切换 → 结果界面
                state <= RESULT;
            else if(key_s3_pulse)            // KEY2: 清零 → 录入界面
                state <= RECORD;
        end
    end

    always @(posedge clk)begin
        if(rst)begin
            adc_r <= 0;
        end
        else if(adc_end)begin
            adc_r <= adc;
        end
    end
    always @(posedge clk)begin
        if(rst)begin
            ds_data_r <= 0;
        end
        else if(adc_end)begin
            ds_data_r <= ds_data;
        end
    end

    always @(posedge clk)begin
        if(rst)begin
            adc_value <= 0;
        end
        else begin
            adc_value <= adc_r;
        end
    end

    integer i;

    // 录入缓冲: S1=录入, S3=清零
    always @(posedge clk)begin
        if(rst)begin
            for(i=0;i<DATA_DEPTH;i=i+1)begin
                buff_data[i] <= 0;
                buff_time[i] <= 0;
            end
                index <= 0;
            end
        else if(key_s3_pulse)begin                              // KEY2: 清零
            for(i=0;i<DATA_DEPTH;i=i+1)begin
                buff_data[i] <= 0;
                buff_time[i] <= 0;
            end
            index <= 0;
        end
        else if(key_s1_pulse)begin                              // KEY0: 录入
            buff_data[index] <= adc_value;
            buff_time[index] <= {8'b0, ds_data_r[23:0]};  // 只存 hour/min/sec
            index <= (index == DATA_DEPTH - 1)? 0: index + 1;
        end
    end

    // ---- 共享 8-bit 拍平: 组合逻辑, 始终反映 buff_data 低 8 位 ----
    always @(*) begin
        for(i = 0; i < DATA_DEPTH; i = i + 1)
            din_flat_8bit[i*8 +: 8] = buff_data[i][7:0];
    end

    // ---- normalization 的 32-bit 拍平 (保持原逻辑) ----
    always @(posedge clk)begin
        if(rst)begin
            din_flat_3 <= 0 ;
        end
        else if(key_s2_pulse && (bits_1 == 4'd3))begin
            for(i = 0; i<index && i<DATA_DEPTH; i=i+1)begin
                din_flat_3[i*DATA_WIDTH+:DATA_WIDTH] <= buff_data[i];
            end
        end
    end

    // ---- rle_start 生成: 进入算法4时触发一次编码 ----
    always @(posedge clk) begin
        if(rst)
            rle_start <= 0;
        else if(key_s2_pulse && bits_1 == 4'd3)     // 从A3切换到A4
            rle_start <= 1;
        else if(state == RECORD && key_s4_pulse && bits_1 == 4'd4)  // S4执行A4
            rle_start <= 1;
        else
            rle_start <= 0;
    end

    // rank_value: A1 无 rank → 显示 0; A2/A3 显示索引; A4 显示 count
   always @(posedge clk)begin
        if(rst)begin
            rank_value <=0;
        end
        else begin
            case(bits_1)
                4'd1: rank_value <= 8'd0;                            // max_min 已无 rank
                4'd2: rank_value <= result_index_2;
                4'd3: rank_value <= result_index_3;
                4'd4: rank_value <= result_4[result_index_4];         // RLE: 显示 count
            endcase
        end
   end

    // result_2 捕获: 从 moving_average 的 dout_flat 解包
   always @(posedge clk)begin
        if(rst)begin
            for(i = 0; i<DATA_DEPTH; i=i+1)begin
                result_2[i] <= 0 ;
            end
        end
        else if(bits_1 == 4'd2)begin
            for(i = 0; i<index && i<DATA_DEPTH; i=i+1)begin
                 result_2[i] <= result_flat_2[i*8+:8];
            end
        end
    end

    // result_3 捕获: 从 normalization 解包 (保持原逻辑)
   always @(posedge clk)begin
        if(rst)begin
            for(i = 0; i<DATA_DEPTH; i=i+1)begin
                result_3[i] <= 0 ;
            end
        end
        else if(bits_1 == 4'd3)begin
            for(i = 0; i<index && i<DATA_DEPTH; i=i+1)begin
                 result_3[i] <= result_flat_3[i*8+:8];
            end
        end
    end

    // result_4 捕获: rle_done 时从 value_cnt_flat 解包 (count数组)
   always @(posedge clk)begin
        if(rst)begin
            for(i = 0; i<DATA_DEPTH; i=i+1)begin
                result_4[i] <= 0 ;
            end
        end
        else if(rle_done && rle_compressed) begin
            for(i = 0; i<index && i<DATA_DEPTH; i=i+1)begin
                 result_4[i] <= result_flat_4[i*8+:8];
            end
        end
        else if(rle_done && !rle_compressed) begin
            // 压缩无效: 每段 count=1
            for(i = 0; i<index && i<DATA_DEPTH; i=i+1)begin
                 result_4[i] <= 8'd1;
            end
        end
    end

    // rle_value_4 捕获: rle_done 时从 value_flat 或 raw_flat 解包
   always @(posedge clk)begin
        if(rst)begin
            for(i = 0; i<DATA_DEPTH; i=i+1)begin
                rle_value_4[i] <= 0;
            end
        end
        else if(rle_done && rle_compressed) begin
            for(i = 0; i<index && i<DATA_DEPTH; i=i+1)begin
                 rle_value_4[i] <= value_flat_4[i*8+:8];
            end
        end
        else if(rle_done && !rle_compressed) begin
            // 压缩无效: 取原始数据
            for(i = 0; i<index && i<DATA_DEPTH; i=i+1)begin
                 rle_value_4[i] <= rle_raw_flat[i*8+:8];
            end
        end
    end

    integer m;

    always @(posedge clk)
    begin
        if(rst)
        begin
            for(m=0;m<DATA_DEPTH;m=m+1)
                TX_DATA[m] <= 0;
        end
        else
        begin
            for(m=0;m<DATA_DEPTH;m=m+1)
            begin
                if(m<index)
                    TX_DATA[m] <= {buff_data[m],buff_time[m]};
                else
                    TX_DATA[m] <= 0;
            end
        end
    end

   // === 两阶段串口发送: Phase0=原始数据, Phase1=算法结果 ===

   // send_flag 控制
   always @(posedge clk)begin
        if(rst)begin
            send_flag <= 0;
        end
        else if(key_s4_pulse && index > 0)begin                // KEY3: 有数据才发送
            send_flag  <= 1;
        end
        else if(send_phase && result_byte_cnt >= result_total)begin
            send_flag <= 0;                                    // 全部发送完成
        end
   end

   // send_phase 切换: 原始数据最后一字节发出后 → Phase1
   always @(posedge clk)begin
        if(rst)begin
            send_phase <= 0;
        end
        else if(key_s4_pulse)begin
            send_phase <= 0;
        end
        else if(!send_phase && send_flag && !tx_busy && byte_cnt == 4'd7 && send_cnt == index - 1)begin
            send_phase <= 1;
        end
   end

   // send_cnt: Phase0 每 8 字节递增
   always @(posedge clk)begin
        if(rst)begin
            send_cnt <= 0;
        end
        else if(key_s4_pulse)begin
            send_cnt <= 0;
        end
        else if(!send_phase && send_flag && !tx_busy && byte_cnt == 4'd7)begin
            send_cnt <= send_cnt + 1;
        end
   end

   // byte_cnt: Phase0 字节内偏移
   always @(posedge clk)begin
        if(rst)begin
            byte_cnt <= 0;
        end
        else if(!send_phase && send_flag && !tx_busy)begin
            byte_cnt <= (byte_cnt == 4'd7) ? 0 : byte_cnt + 1;
        end
   end

   // result_byte_cnt + result_total 锁存
   always @(posedge clk)begin
        if(rst)begin
            result_byte_cnt <= 0;
            result_total    <= 0;
        end
        else if(key_s4_pulse)begin
            result_byte_cnt <= 0;
            result_total    <= 0;
        end
        else if(!send_phase && send_flag && !tx_busy && byte_cnt == 4'd7 && send_cnt == index - 1)begin
            result_byte_cnt <= 0;
            case(bits_1)                                         // 锁存结果总字节数
                4'd1: result_total <= 8'd2;                       // 极值: max_val, min_val (无rank)
                4'd2: result_total <= (index >= 3) ? (index - 2) : 8'd0;
                4'd3: result_total <= index;
                4'd4: result_total <= seg_num_r * 2;              // RLE: value+count 交替
                default: result_total <= 0;
            endcase
        end
        else if(send_phase && send_flag && !tx_busy)begin
            result_byte_cnt <= result_byte_cnt + 1;
        end
   end


  // pi_data + pi_flag: Phase0 发原始数据, Phase1 发算法结果
  always @(posedge clk)begin
      if(rst)begin
          pi_data <= 0;
          pi_flag <= 1'b0;
      end
      else if(send_flag && !tx_busy)begin
          pi_flag <= 1'b1;
          if(!send_phase) begin
              // === Phase 0: 原始采集数据 ===
              case(byte_cnt)
                  4'd0:  pi_data <=  TX_DATA[send_cnt][7:0];
                  4'd1:  pi_data <=  TX_DATA[send_cnt][15:8];
                  4'd2:  pi_data <=  TX_DATA[send_cnt][23:16];
                  4'd3:  pi_data <=  TX_DATA[send_cnt][31:24];
                  4'd4:  pi_data <=  TX_DATA[send_cnt][39:32];
                  4'd5:  pi_data <=  TX_DATA[send_cnt][47:40];
                  4'd6:  pi_data <=  TX_DATA[send_cnt][55:48];
                  4'd7:  pi_data <=  TX_DATA[send_cnt][63:56];
                  default: pi_data <= 0;
              endcase
          end
          else if(result_byte_cnt < result_total) begin
              // === Phase 1: 算法结果 ===
              case(bits_1)
                  4'd1: begin                                   // 极值统计 (无rank, 补0)
                      case(result_byte_cnt)
                          8'd0: pi_data <= max_val_r;
                          8'd1: pi_data <= min_val_r;
                          default: pi_data <= 0;
                      endcase
                  end
                  4'd2: pi_data <= result_flat_2[result_byte_cnt*8+:8];   // 滑动平均
                  4'd3: pi_data <= result_flat_3[result_byte_cnt*8+:8];   // 归一化
                  4'd4: begin                                   // RLE: value/count 交替
                      if(result_byte_cnt[0] == 0)
                          pi_data <= value_flat_4[(result_byte_cnt>>1)*8+:8];
                      else
                          pi_data <= result_flat_4[(result_byte_cnt>>1)*8+:8];
                  end
                  default: pi_data <= 0;
              endcase
          end
          else begin
              pi_flag <= 1'b0;                                   // 无数据可发
          end
      end
      else begin
          pi_flag <= 1'b0;
      end
  end

    // 算法循环: S2 切换 A1→A2→A3→A4→A1
    always @(posedge clk)begin
        if(rst)begin
            bits_1 <= 1;
        end
        else begin
            if(key_s2_pulse)begin
                if(bits_1 == 3'd4)begin
                    bits_1 <= 4'd1;
                end
                else begin
                    bits_1 <= bits_1 + 1;
                end
            end
        end
    end

    // 极值: KEY0 在 RESULT 下切换 MAX(1) / MIN(2)
    always @(posedge clk)begin
        if(rst)begin
             result_index_1 <= 1;
        end
        else if(state == RESULT && (bits_1 == 4'd1) && key_s1_pulse)begin
            result_index_1 <= (result_index_1 == 1) ? 2 : 1;
       end
    end


    // 滑动平均: KEY0 在 RESULT 下浏览 N-2 个结果
    always @(posedge clk)begin
        if(rst)begin
             result_index_2 <= 0;
        end
        else if(state == RESULT && (bits_1 == 4'd2) && key_s1_pulse)begin
            result_index_2 <= (index >= 3 && result_index_2 < index - 3) ? result_index_2 + 1 : 0;
       end
    end

    // 归一化: KEY0 在 RESULT 下浏览 N 个结果
    always @(posedge clk)begin
        if(rst)begin
             result_index_3 <= 0;
        end
        else if(state == RESULT && (bits_1 == 4'd3) && key_s1_pulse)begin
            result_index_3 <= (index > 0 && result_index_3 < index - 1) ? result_index_3 + 1 : 0;
       end
    end

    // RLE: KEY0 在 RESULT 下浏览 seg_num 个结果
    always @(posedge clk)begin
        if(rst)begin
             result_index_4 <= 0;
        end
        else if(state == RESULT && (bits_1 == 4'd4) && key_s1_pulse)begin
            result_index_4 <= (seg_num_r > 0 && result_index_4 < seg_num_r - 1) ? result_index_4 + 1 : 0;
       end
    end


    // result_value: 各算法当前浏览的结果值
    always @(posedge clk)begin
        if(rst)begin
            result_value <= 0;
        end
        else begin
            case(bits_1)
                4'd1:begin
                    if(result_index_1 == 1)begin
                        result_value <= max_val_r;
                    end
                    else begin
                        result_value <= min_val_r;
                    end
                end

                4'd2:begin
                        result_value <= result_2[result_index_2];
                end
               4'd3:begin
                        result_value <= result_3[result_index_3];
                end
                4'd4:begin
                        result_value <= rle_value_4[result_index_4];  // RLE: 显示 value
                end
             default: result_value <= 0;
             endcase
         end
      end






    // 数码管显示输出
    always @(posedge clk)begin
        if(rst)begin
            data_1<= 4'b0000;
            data_2<= 4'b0000;
            data_3<= 4'b0000;
            data_4<= 4'b1111;
            data_5<= 4'b0000;
            data_6<= 4'b0000;
            data_7<= 4'b0000;
            data_8<= 4'b0000;
       end
       else if(state == RECORD)begin
            data_1 <= adc_value_one;
            data_2 <= adc_value_ten;
            data_3 <= adc_value_hund;
            data_4 <= 4'b1111;
            data_5 <= adc_one;
            data_6 <= adc_ten;
            data_7 <= adc_hund;
            data_8 <= 4'b1100;
       end
       else begin
            data_1 <= rank_value_one;
            data_2 <= rank_value_ten;
            data_3<= 4'b1111;
            data_4 <= result_value_one;
            data_5 <= result_value_ten;
            data_6 <= result_value_hund;
            data_7<= bits_1;
            data_8<= 4'b1010;
          end
       end





bcd_3digit #(
    .WIDTH(8)
)
uut1(
    .clk(clk),
    .rst(rst),
    .bin(adc_r),
    .one(adc_one),
    .ten(adc_ten),
    .hund(adc_hund)
);

bcd_3digit #(
    .WIDTH(8)
)
uut2(
    .clk(clk),
    .rst(rst),
    .bin(adc_value),
    .one(adc_value_one),
    .ten(adc_value_ten),
    .hund(adc_value_hund)
);


 bcd_2digit #(
    .WIDTH(8)
)
uut3(
    .clk(clk),
    .rst(rst),
    .bin(rank_value),
    .one(rank_value_one),
    .ten(rank_value_ten)
);

bcd_3digit #(
    .WIDTH(8)
)
uut4(
    .clk(clk),
    .rst(rst),
    .bin(result_value),
    .one(result_value_one),
    .ten(result_value_ten),
    .hund(result_value_hund)
);

// ==================== 算法模块例化 ====================

// max_min: 极值统计 (DATA_WIDTH=8, 无rank输出)
max_min #(
    .DATA_WIDTH(8),
    .DATA_DEPTH(DATA_DEPTH)
)
max_min_list(
    .clk(clk),
    .rst(rst),
    .din_flat(din_flat_8bit),
    .valid_cnt(index),
    .max_val(max_val),
    .min_val(min_val)
);

// moving_average: 滑动平均 (DATA_WIDTH=8, 端口改名 dout_flat)
moving_average #(
    .DATA_WIDTH(8),
    .DATA_DEPTH(DATA_DEPTH),
    .WINDOW(3)
)
moving_average_list(
    .clk(clk),
    .rst(rst),
    .din_flat(din_flat_8bit),
    .valid_cnt(index),
    .dout_flat(result_flat_2)
);

// normalization: 归一化 (保持 DATA_WIDTH=32, 原接口不变)
normalization #(
    .DATA_WIDTH(DATA_WIDTH),
    .DATA_DEPTH(DATA_DEPTH)
)
normalization_list(
    .clk(clk),
    .rst(rst),
    .din_flat(din_flat_3),
    .valid_count(index),
    .result_val_flat(result_flat_3)
);

// rle_encode: RLE压缩 (DATA_WIDTH=8, 新时序接口)
rle_encode #(
    .DATA_WIDTH(8),
    .DATA_DEPTH(DATA_DEPTH),
    .CNT_WIDTH(8)
)
rle_encode_list(
    .clk(clk),
    .rst(rst),
    .din_flat(din_flat_8bit),
    .valid_cnt(index),
    .start(rle_start),
    .busy(rle_busy),
    .compressed(rle_compressed),
    .seg_num(seg_num),
    .value_flat(value_flat_4),
    .value_cnt_flat(result_flat_4),
    .raw_flat(rle_raw_flat),
    .done(rle_done)
);


endmodule
