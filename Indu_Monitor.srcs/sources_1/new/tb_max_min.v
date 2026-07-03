`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: max_min
// 验证极值统计模块 (8-bit, 16-depth, 树形比较器)
//////////////////////////////////////////////////////////////////////////////////

module tb_max_min();

    // ==================== 参数 ====================
    localparam DATA_WIDTH = 8;
    localparam DATA_DEPTH = 16;

    // ==================== 信号 ====================
    reg                              clk;
    reg                              rst;
    reg  [DATA_DEPTH*DATA_WIDTH-1:0] din_flat;
    reg  [4:0]                       valid_cnt;
    wire [DATA_WIDTH-1:0]            max_val;
    wire [DATA_WIDTH-1:0]            min_val;

    // ==================== DUT ====================
    max_min #(
        .DATA_WIDTH(DATA_WIDTH),
        .DATA_DEPTH(DATA_DEPTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .din_flat(din_flat),
        .valid_cnt(valid_cnt),
        .max_val(max_val),
        .min_val(min_val)
    );

    // ==================== 时钟 ====================
    always #10 clk = ~clk;   // 50MHz

    // ==================== 辅助函数 ====================
    // 将一组 8-bit 值打包到 din_flat
    task set_input(input [7:0] vals [0:DATA_DEPTH-1], input [4:0] cnt);
        integer j;
        begin
            valid_cnt = cnt;
            din_flat = 0;
            for (j = 0; j < DATA_DEPTH; j = j + 1)
                din_flat[j*8 +: 8] = vals[j];
        end
    endtask

    // ==================== 测试主流程 ====================
    initial begin
        clk = 0;
        rst = 1;
        valid_cnt = 0;
        din_flat = 0;

        // 复位释放
        #25 rst = 0;
        #20;

        // ---- Test 1: 5个数据, 基本极值 ----
        begin
            reg [7:0] t1 [0:DATA_DEPTH-1];
            t1[0]=10; t1[1]=50; t1[2]=30; t1[3]=80; t1[4]=20;
            t1[5]=0;  t1[6]=0;  t1[7]=0;  t1[8]=0;  t1[9]=0;
            t1[10]=0; t1[11]=0; t1[12]=0; t1[13]=0; t1[14]=0; t1[15]=0;

            set_input(t1, 5);
            #40; // 等2拍: din_flat_r 打拍 + max_val/min_val 输出打拍

            if (max_val == 80 && min_val == 10)
                $display("[PASS] Test1: 5值基本极值  max=%0d min=%0d", max_val, min_val);
            else
                $display("[FAIL] Test1: 期望 max=80 min=10, 实际 max=%0d min=%0d", max_val, min_val);
        end

        // ---- Test 2: 全部相同 ----
        begin
            reg [7:0] t2 [0:DATA_DEPTH-1];
            t2[0]=42; t2[1]=42; t2[2]=42; t2[3]=42; t2[4]=42;
            t2[5]=0;  t2[6]=0;  t2[7]=0;  t2[8]=0;  t2[9]=0;
            t2[10]=0; t2[11]=0; t2[12]=0; t2[13]=0; t2[14]=0; t2[15]=0;

            set_input(t2, 5);
            #40;

            if (max_val == 42 && min_val == 42)
                $display("[PASS] Test2: 全同值  max=%0d min=%0d", max_val, min_val);
            else
                $display("[FAIL] Test2: 期望 max=42 min=42, 实际 max=%0d min=%0d", max_val, min_val);
        end

        // ---- Test 3: 单值 ----
        begin
            reg [7:0] t3 [0:DATA_DEPTH-1];
            t3[0]=77; t3[1]=0; t3[2]=0; t3[3]=0; t3[4]=0;
            t3[5]=0;  t3[6]=0; t3[7]=0; t3[8]=0; t3[9]=0;
            t3[10]=0; t3[11]=0; t3[12]=0; t3[13]=0; t3[14]=0; t3[15]=0;

            set_input(t3, 1);
            #40;

            if (max_val == 77 && min_val == 77)
                $display("[PASS] Test3: 单值  max=%0d min=%0d", max_val, min_val);
            else
                $display("[FAIL] Test3: 期望 max=77 min=77, 实际 max=%0d min=%0d", max_val, min_val);
        end

        // ---- Test 4: 边界——max在第一个, min在最后一个 ----
        begin
            reg [7:0] t4 [0:DATA_DEPTH-1];
            t4[0]=99; t4[1]=50; t4[2]=60; t4[3]=70; t4[4]=10;
            t4[5]=0;  t4[6]=0;  t4[7]=0;  t4[8]=0;  t4[9]=0;
            t4[10]=0; t4[11]=0; t4[12]=0; t4[13]=0; t4[14]=0; t4[15]=0;

            set_input(t4, 5);
            #40;

            if (max_val == 99 && min_val == 10)
                $display("[PASS] Test4: max首/min尾  max=%0d min=%0d", max_val, min_val);
            else
                $display("[FAIL] Test4: 期望 max=99 min=10, 实际 max=%0d min=%0d", max_val, min_val);
        end

        // ---- Test 5: 满 16 个数据 ----
        begin
            reg [7:0] t5 [0:DATA_DEPTH-1];
            t5[0]=5;  t5[1]=15; t5[2]=127; t5[3]=0; t5[4]=100;
            t5[5]=66; t5[6]=33; t5[7]=99; t5[8]=1;  t5[9]=88;
            t5[10]=44; t5[11]=77; t5[12]=22; t5[13]=55; t5[14]=11; t5[15]=120;

            set_input(t5, 16);
            #40;

            if (max_val == 127 && min_val == 0)
                $display("[PASS] Test5: 满16值  max=%0d min=%0d", max_val, min_val);
            else
                $display("[FAIL] Test5: 期望 max=127 min=0, 实际 max=%0d min=%0d", max_val, min_val);
        end

        // ---- Test 6: valid_cnt=0 边界 ----
        begin
            reg [7:0] t6 [0:DATA_DEPTH-1];
            t6[0]=55; t6[1]=66; t6[2]=77; t6[3]=88; t6[4]=99;
            t6[5]=0;  t6[6]=0;  t6[7]=0;  t6[8]=0;  t6[9]=0;
            t6[10]=0; t6[11]=0; t6[12]=0; t6[13]=0; t6[14]=0; t6[15]=0;

            set_input(t6, 0);
            #40;

            // valid_cnt=0: 所有位置 pad 为 0 (max) 和 0xFF (min)
            if (max_val == 0 && min_val == 255)
                $display("[PASS] Test6: valid_cnt=0  max=%0d min=%0d", max_val, min_val);
            else
                $display("[FAIL] Test6: 期望 max=0 min=255, 实际 max=%0d min=%0d", max_val, min_val);
        end

        // ---- Test 7: 动态改变 valid_cnt ----
        begin
            reg [7:0] t7 [0:DATA_DEPTH-1];
            t7[0]=100; t7[1]=90; t7[2]=80; t7[3]=70; t7[4]=60;
            t7[5]=50;  t7[6]=0;  t7[7]=0;  t7[8]=0;  t7[9]=0;
            t7[10]=0; t7[11]=0; t7[12]=0; t7[13]=0; t7[14]=0; t7[15]=0;

            // 先设 valid_cnt=6
            set_input(t7, 6);
            #40;
            if (max_val == 100 && min_val == 50)
                $display("[PASS] Test7a: valid_cnt=6  max=%0d min=%0d", max_val, min_val);
            else
                $display("[FAIL] Test7a: 期望 max=100 min=50, 实际 max=%0d min=%0d", max_val, min_val);

            // 缩小到 valid_cnt=2
            set_input(t7, 2);
            #40;
            if (max_val == 100 && min_val == 90)
                $display("[PASS] Test7b: valid_cnt缩小到2  max=%0d min=%0d", max_val, min_val);
            else
                $display("[FAIL] Test7b: 期望 max=100 min=90, 实际 max=%0d min=%0d", max_val, min_val);
        end

        $display("===== 测试结束 =====");
        $finish;
    end

endmodule
