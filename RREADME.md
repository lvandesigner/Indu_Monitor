# Indu_Monitor — 工业信号监测与数据处理 FPGA 系统

> **Indu**strial Signal **Monitor**ing & Processing System on FPGA

[![Target FPGA](https://img.shields.io/badge/FPGA-Xilinx%20Spartan--7%20xc7s6ftgb196--1-blue)](https://www.xilinx.com/products/silicon-devices/fpga/spartan-7.html)
[![Tool](https://img.shields.io/badge/Tool-Vivado%202023.2-green)](https://www.xilinx.com/products/design-tools/vivado.html)
[![Language](https://img.shields.io/badge/Language-Verilog%20HDL-orange)](#)
[![Design](https://img.shields.io/badge/Design-Pure%20RTL-brightgreen)](#)

---

## 目录

- [1. 项目概览](#1-项目概览)
- [2. 系统架构](#2-系统架构)
- [3. 模块层次](#3-模块层次)
- [4. 模块详解](#4-模块详解)
  - [4.1 顶层模块 `top`](#41-顶层模块-top)
  - [4.2 核心状态机 `fsm`](#42-核心状态机-fsm)
  - [4.3 ADC 采集链路](#43-adc-采集链路)
  - [4.4 算法处理单元](#44-算法处理单元)
  - [4.5 人机交互接口](#45-人机交互接口)
  - [4.6 通信与时钟接口](#46-通信与时钟接口)
- [5. 引脚约束](#5-引脚约束)
- [6. 数据流与用户操作](#6-数据流与用户操作)
- [7. 算法详解](#7-算法详解)
- [8. 仿真与验证](#8-仿真与验证)
- [9. 构建流程](#9-构建流程)
- [10. 设计要点与注意事项](#10-设计要点与注意事项)
- [11. 文件清单](#11-文件清单)
- [12. 版本历史](#12-版本历史)

---

## 1. 项目概览

### 1.1 项目简介

**Indu_Monitor** 是一个基于 **Xilinx Spartan-7** FPGA 的工业信号监测与数据处理系统。系统通过 I2C 接口的 ADC 采集模拟电压信号，利用 DS1302 实时时钟为每帧数据打上时间戳，在片内完成 4 种可选信号处理算法的计算，并通过 8 位数码管和 UART 串口将结果输出。

### 1.2 技术参数

| 项目         | 参数                                |
| ------------ | ----------------------------------- |
| **目标芯片** | Xilinx Spartan-7 `xc7s6ftgb196-1`   |
| **开发环境** | Vivado 2023.2                       |
| **设计方式** | 纯 RTL（无 IP 核、无 Block Design） |
| **系统时钟** | 50 MHz                              |
| **编程语言** | Verilog HDL                         |
| **源文件数** | 16 个 RTL 模块                      |
| **约束文件** | 1 个 XDC                            |
| **仿真测试** | 2 个 Testbench                      |

### 1.3 核心功能

```
┌─────────────────────────────────────────────────────────────┐
│                    Indu_Monitor 系统                        │
│                                                             │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐  │
│  │ I2C ADC  │   │ DS1302   │   │  4 按键  │   │ 数码管    │  │
│  │ 模拟采集 │   │ 时钟戳   │   │ 用户输入 │   │ 8位显示     │  │
│  └────┬─────┘   └────┬─────┘   └────┬─────┘   └────┬─────┘  │
│       │              │              │              │        │
│       ▼              ▼              ▼              ▼        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                   FSM 核心状态机                      │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌────────┐   │   │
│  │  │  A1     │  │  A2     │  │  A3     │  │  A4    │   │   │
│  │  │ 最大/最 │  │ 滑动窗  │  │ 归一化  │  │ 游程     │   │   │
│  │  │ 小值    │  │ 口平均  │  │ [0,100] │  │ 编码    │   │   │
│  │  └─────────┘  └─────────┘  └─────────┘  └────────┘   │   │
│  └──────────────────────────────────────────────────────┘   │
│       │                                                     │
│       ▼                                                     │
│  ┌──────────────────────────┐                               │
│  │    UART TX (115200bps)   │                               │
│  │    原始数据 + 算法结果    │                               │
│  └──────────────────────────┘                               │
└─────────────────────────────────────────────────────────────┘
```

- **ADC 采集**: 通过 I2C 连续读取外部 ADC 的 8 位转换值
- **时间戳**: 按下 S1 键时从 DS1302 RTC 获取当前时间（时:分:秒），与 ADC 值绑定存储
- **数据缓冲**: 最多存储 16 条 `{ADC值, 时间}` 记录
- **算法处理**: 对缓冲区内数据执行 4 种可选算法
- **本地显示**: 8 位 7 段数码管动态扫描显示，实时刷新 ADC 值和算法结果
- **串口上传**: 通过 UART 将原始数据和算法结果发送至上位机

---

## 2. 系统架构

### 2.1 整体框图

```
                   ┌────────────────────────────────────────────┐
                   │              FPGA (Spartan-7)              │
                   │                                            │
  50MHz ──────────►│ clk                                        │
  RST_n ──────────►│ rst                                        │
                   │                                            │
  KEY[3:0] ───────►│ s1~s4 ──► key_debounce(x4) ──► FSM         │
                   │                                            │
  I2C_SDA ◄───────►│ iic_sda ──► iic_drive ──► ad_ctrl ──► FSM  │
  I2C_SCL ────────►│ iic_scl                                    │
                   │                                            │
  DS1302_CE ──────►│ ds1302_ce ──┐                              │
  DS1302_SCLK ────►│ ds1302_sclk─┤                              │
  DS1302_DATA ◄───►│ ds1302_data─┘                              │
                   │    ds1302_wr_drive ──► ds1302_io_convert   │
                   │         │                    │             │
                   │         │              spi_master          │
                   │         │                    │             │
                   │         ▼                    ▼             │
                   │       FSM ◄──── time[23:0]                 │
                   │                                            │
  SEG[7:0] ───────►│ seven_segment ◄── FSM (display_data)       │
  SEL[7:0] ───────►│                                            │
                   │                                            │
  UART_TX ────────►│ uart_tx ◄── FSM (uart_send)                │
                   │                                            │
                   │  ┌─────────────────────────────────────┐   │
                   │  │  FSM 内部算法引擎 (max_min /        │    │
                   │  │  moving_average / normalization /   │   │
                   │  │  rle_encode)                        │   │
                   │  └─────────────────────────────────────┘   │
                   └────────────────────────────────────────────┘
```

### 2.2 时钟域

整个设计运行在 **单一时钟域** 上（50 MHz 系统时钟），所有子模块均使用此时钟：

| 模块        | 时钟       | 分频方式         |
| ----------- | ---------- | ---------------- |
| 系统逻辑    | 50 MHz     | 直连             |
| I2C SCL     | 125 kHz    | 50 MHz / 400     |
| SPI SCLK    | 100 kHz    | 50 MHz / 500     |
| 按键消抖    | 10 ms      | 50 MHz / 500,000 |
| 数码管刷新  | ~100 Hz    | 50 MHz / 500,000 |
| UART 波特率 | 115200 bps | 50 MHz / 434     |

---

## 3. 模块层次

```
top (top.v)                                  — 顶层集成
├── key_debounce × 4 (key_debounce.v)        — 按键消抖
├── ad_ctrl (ad_ctrl.v)                      — ADC 控制器
│   └── iic_drive (iic_drive.v)              — I2C 主机
├── fsm (fsm.v)                              — 核心状态机 + 算法调度
│   ├── bcd_3digit × 2 (bcd_3digit.v)        — 二进制→3位BCD
│   ├── bcd_2digit (bcd_2digit.v)            — 二进制→2位BCD
│   ├── max_min (max_min.v)                  — 算法A1: 最大/最小值
│   ├── moving_average (moving_average.v)    — 算法A2: 滑动窗口平均
│   ├── normalization (normalization.v)      — 算法A3: 归一化
│   └── rle_encode (rle_encode.v)            — 算法A4: 游程编码
├── seven_segment (seven_segment.v)          — 7段数码管驱动
├── ds1302_wr_drive (ds1302_wr_drive.v)      — DS1302 RTC 控制器
│   └── ds1302_io_convert (ds1302_io_convert.v) — DS1302 3线协议转换
│       └── spi_master (spi_master.v)        — SPI 主机
└── uart_tx (uart_tx.v)                      — UART 发送器
```

---

## 4. 模块详解

### 4.1 顶层模块 `top`

**文件:** [`Indu_Monitor.srcs/sources_1/new/top.v`](Indu_Monitor.srcs/sources_1/new/top.v)

顶层集成模块，负责例化所有子模块并完成互联。主要参数配置：

| 参数              | 值            | 说明               |
| ----------------- | ------------- | ------------------ |
| `P_SYS_CLK`       | 50,000,000    | 系统时钟 50 MHz    |
| `P_IIC_SCL`       | 125,000       | I2C 时钟 125 kHz   |
| `P_DEVICE_ADDR`   | `7'b101_0100` | I2C 设备地址 0x54  |
| `P_ADDR_BYTE_NUM` | 1             | 寄存器地址字节数   |
| `P_DATA_BYTE_NUM` | 2             | I2C 读取数据字节数 |
| `COUNT_10MS`      | 500,000       | 10 ms 消抖计数     |
| `DATA_WIDTH`      | 32            | 数据位宽           |
| `DATA_DEPTH`      | 16            | 数据缓冲深度       |
| `UART_BPS`        | 115,200       | UART 波特率        |

**关键连接关系:**

- `adc_start` 硬连线为 `1`，ADC 持续轮询采集
- `ds1302_wr_drive` 配置为只读模式（`write_time_req = 0`）
- DS1302 读取由 `key_s1_pulse` 触发（按下 S1 键时锁存时间戳）

---

### 4.2 核心状态机 `fsm`

**文件:** [`Indu_Monitor.srcs/sources_1/new/fsm.v`](Indu_Monitor.srcs/sources_1/new/fsm.v)

这是整个系统的"大脑"，实现了完整的用户交互流程、数据缓冲管理、算法调度和 UART 传输逻辑。

#### 4.2.1 顶层状态

```
        ┌──────────┐  S2(切换算法)   ┌──────────┐
        │  RECORD  │ ─────────────► │  RESULT  │
        │ 数据记录  │ ◄───────────── │ 结果浏览  │
        └──────────┘  S3(清空缓冲)   └──────────┘
```

| 状态       | 说明                                           |
| ---------- | ---------------------------------------------- |
| **RECORD** | 默认状态，实时显示 ADC 读数，S1 记录采样       |
| **RESULT** | 算法结果浏览状态，S2 切换算法，S1 切换结果序号 |

#### 4.2.2 按键功能

| 按键          | RECORD 模式                            | RESULT 模式                   |
| ------------- | -------------------------------------- | ----------------------------- |
| **S1** (KEY0) | 采样：将当前 ADC 值 + 时间戳存入缓冲区 | 浏览：切换显示第 N 个结果     |
| **S2** (KEY1) | 切换到 RESULT 模式，显示 A1 结果       | 循环切换算法 (A1→A2→A3→A4→A1) |
| **S3** (KEY2) | 清空缓冲区                             | 清空缓冲区并返回 RECORD       |
| **S4** (KEY3) | 触发 UART 传输                         | 触发 UART 传输                |

#### 4.2.3 UART 两阶段传输

- **Phase 0（原始数据）**: 逐条发送缓冲区中所有有效数据，每条 8 字节
- **Phase 1（算法结果）**: 发送当前选中算法的计算结果

#### 4.2.4 数码管显示

| 模式   | 显示内容                     | 格式                                   |
| ------ | ---------------------------- | -------------------------------------- |
| RECORD | 实时 ADC 值 + 已缓存条数     | `xxx` (ADC) + `Cxx` (计数)             |
| RESULT | 算法序号 + 结果序号 + 结果值 | `Ax` (算法) + `xx` (序号) + `xxx` (值) |

---

### 4.3 ADC 采集链路

#### 4.3.1 `ad_ctrl` — ADC 控制器

**文件:** [`Indu_Monitor.srcs/sources_1/new/ad_ctrl.v`](Indu_Monitor.srcs/sources_1/new/ad_ctrl.v)

`iic_drive` 的轻量级封装。从 I2C 设备地址 `0x54` 的寄存器 `0x00` 连续读取 2 字节，取 `[11:4]` 位作为 8 位 ADC 结果输出。

#### 4.3.2 `iic_drive` — I2C 主机控制器

**文件:** [`Indu_Monitor.srcs/sources_1/new/iic_drive.v`](Indu_Monitor.srcs/sources_1/new/iic_drive.v)

完整功能的 I2C Master，支持可变长度的地址/数据读写。

**特性:**

- 125 kHz SCL (50 MHz / 400)
- One-hot 编码状态机，清晰无毛刺
- 支持 Repeated START（读操作时先写寄存器地址再读数据）
- SDA 三态双向控制
- ACK 错误检测

**状态转移链:**

```
IDLE → START_DEVICE_ADDR → W_WORD_ADDR → R_START_DEVICE_ADDR → R_DATA → STOP
                              (写入) ↘
                              W_DATA → STOP
```

---

### 4.4 算法处理单元

全部算法模块均例化在 `fsm` 内部，由 FSM 统一调度。

#### 4.4.1 `max_min` — 算法 A1: 最大/最小值查找

**文件:** [`Indu_Monitor.srcs/sources_1/new/max_min.v`](Indu_Monitor.srcs/sources_1/new/max_min.v)

采用**并行比较树**结构，通过 `generate` 构建 3 级流水线（16→8→4→2→1），在单个周期内完成所有比较。

- 输入: 16 个 8-bit 数据
- 输出: `max[7:0]`, `min[7:0]`
- 无效数据位（超过 `valid_cnt`）用中性值填充：max 用 `0x00`，min 用 `0xFF`

#### 4.4.2 `moving_average` — 算法 A2: 滑动窗口平均

**文件:** [`Indu_Monitor.srcs/sources_1/new/moving_average.v`](Indu_Monitor.srcs/sources_1/new/moving_average.v)

窗口大小 = 3，逐元素顺序计算（非并行除法器），输出 `valid_cnt - (WINDOW-1)` 个有效结果。

```
输入: [a₀, a₁, a₂, a₃, a₄, ...]
输出: [avg(a₀,a₁,a₂), avg(a₁,a₂,a₃), avg(a₂,a₃,a₄), ...]
```

要求至少 3 个有效输入。

#### 4.4.3 `normalization` — 算法 A3: 归一化 [0,100]

**文件:** [`Indu_Monitor.srcs/sources_1/new/normalization.v`](Indu_Monitor.srcs/sources_1/new/normalization.v)

归一化公式: `result = (value - min) × 100 / (max - min)`

**4 状态状态机:**

```
S_FIND   → 查找 min/max
S_COMPUTE → 乘法 + 启动除法
S_DIV    → 15 周期移位减除法
S_FLAT   → 输出展平
```

> **2026-07-04 修订**: 将原有的单周期 CARRY4 组合除法器替换为 15 周期的移位减法除法器，解决了 ~130 级组合逻辑路径导致的关键路径超过 10 ns 的时序问题。

#### 4.4.4 `rle_encode` — 算法 A4: 游程编码

**文件:** [`Indu_Monitor.srcs/sources_1/new/rle_encode.v`](Indu_Monitor.srcs/sources_1/new/rle_encode.v)

对最多 16 个 8-bit 输入进行游程编码。4 状态 FSM:

```
IDLE → PROCESS (扫描合并) → FINALIZE (写入最后段) → OUTPUT (压缩率检查)
```

当 `2 × seg_cnt < valid_cnt` 时认定压缩有效（编码后体积 < 原始体积）。

---

### 4.5 人机交互接口

#### 4.5.1 `key_debounce` — 按键消抖

**文件:** [`Indu_Monitor.srcs/sources_1/new/key_debounce.v`](Indu_Monitor.srcs/sources_1/new/key_debounce.v)

10 ms 消抖，上升沿检测产生单周期 `key_flag` 脉冲。每按键一个实例。

#### 4.5.2 `seven_segment` — 7 段数码管驱动

**文件:** [`Indu_Monitor.srcs/sources_1/new/seven_segment.v`](Indu_Monitor.srcs/sources_1/new/seven_segment.v)

8 位共阳极数码管动态扫描驱动。每位点亮约 10 ms（约 100 Hz 刷新率）。

**字符映射:**

| 字符 | 段码 (hex) | 字符 | 段码 (hex) |
| ---- | ---------- | ---- | ---------- |
| 0~9  | 标准 BCD   | `A`  | 0x88       |
| `b`  | 0x83       | `C`  | 0xC6       |
| `d`  | 0xA1       | `E`  | 0x86       |
| `F`  | 0x8E       | `-`  | 0xBF       |

#### 4.5.3 `bcd_3digit` / `bcd_2digit` — 二进制→BCD 转换

**文件:**

- [`Indu_Monitor.srcs/sources_1/new/bcd_3digit.v`](Indu_Monitor.srcs/sources_1/new/bcd_3digit.v)
- [`Indu_Monitor.srcs/sources_1/new/bcd_2digit.v`](Indu_Monitor.srcs/sources_1/new/bcd_2digit.v)

采用标准 Double-Dabble（移位加3）算法，8-bit 输入转换为 2 或 3 位 BCD 码。

---

### 4.6 通信与时钟接口

#### 4.6.1 `uart_tx` — UART 发送器

**文件:** [`Indu_Monitor.srcs/sources_1/new/uart_tx.v`](Indu_Monitor.srcs/sources_1/new/uart_tx.v)

- 格式: 1 起始位 + 8 数据位 + 1 停止位
- 波特率: 115200 bps (50 MHz / 434)
- 接口: `work_en` / `tx_busy` 握手

#### 4.6.2 `ds1302_wr_drive` — DS1302 RTC 控制器

**文件:** [`Indu_Monitor.srcs/sources_1/new/ds1302_wr_drive.v`](Indu_Monitor.srcs/sources_1/new/ds1302_wr_drive.v)

Maxim DS1302 实时时钟的顶层控制器。状态机顺序:

1. 写保护寄存器（使能写入）
2. 读/写全部 7 个时间寄存器（年、星期、月、日、时、分、秒）

在本设计中配置为**只读**模式（所有写端口悬空，`write_time_req=0`）。

#### 4.6.3 `ds1302_io_convert` — DS1302 3 线协议转换

**文件:** [`Indu_Monitor.srcs/sources_1/new/ds1302_io_convert.v`](Indu_Monitor.srcs/sources_1/new/ds1302_io_convert.v)

桥接标准 SPI Master 与 DS1302 非标准 3 线协议，完成三项转换:

| 转换         | SPI 标准         | DS1302                 |
| ------------ | ---------------- | ---------------------- |
| **位序**     | MSB-first        | LSB-first（位反转）    |
| **数据线**   | MOSI + MISO 分列 | 单线双向 `ds1302_data` |
| **片选极性** | CS 低有效        | CE 高有效              |

#### 4.6.4 `spi_master` — SPI 主机

**文件:** [`Indu_Monitor.srcs/sources_1/new/spi_master.v`](Indu_Monitor.srcs/sources_1/new/spi_master.v)

通用 SPI Master（CPOL=0, CPHA=0, MSB-first），100 kHz SCLK。单字节传输，`wr_en`/`wr_ack` 握手机制。

---

## 5. 引脚约束

**文件:** [`Indu_Monitor.srcs/constrs_1/new/top.xdc`](Indu_Monitor.srcs/constrs_1/new/top.xdc)

### 5.1 I/O 引脚分配

| 信号               | 引脚    | I/O 标准 | 说明            |
| ------------------ | ------- | -------- | --------------- |
| `clk`              | **G11** | LVCMOS33 | 50 MHz 系统时钟 |
| `rst`              | **B6**  | LVCMOS33 | 系统复位        |
| `s1` (KEY0)        | **M5**  | LVCMOS33 | 按键 1          |
| `s2` (KEY1)        | **M4**  | LVCMOS33 | 按键 2          |
| `s3` (KEY2)        | **P5**  | LVCMOS33 | 按键 3          |
| `s4` (KEY3)        | **N4**  | LVCMOS33 | 按键 4          |
| `seven_segment[0]` | A5      | LVCMOS33 | 段选 a          |
| `seven_segment[1]` | B5      | LVCMOS33 | 段选 b          |
| `seven_segment[2]` | A4      | LVCMOS33 | 段选 c          |
| `seven_segment[3]` | A3      | LVCMOS33 | 段选 d          |
| `seven_segment[4]` | B3      | LVCMOS33 | 段选 e          |
| `seven_segment[5]` | A2      | LVCMOS33 | 段选 f          |
| `seven_segment[6]` | C3      | LVCMOS33 | 段选 g          |
| `seven_segment[7]` | D3      | LVCMOS33 | 段选 dp         |
| `sel[0]`           | B2      | LVCMOS33 | 位选 0          |
| `sel[1]`           | B1      | LVCMOS33 | 位选 1          |
| `sel[2]`           | C5      | LVCMOS33 | 位选 2          |
| `sel[3]`           | C4      | LVCMOS33 | 位选 3          |
| `sel[4]`           | E4      | LVCMOS33 | 位选 4          |
| `sel[5]`           | D4      | LVCMOS33 | 位选 5          |
| `sel[6]`           | F3      | LVCMOS33 | 位选 6          |
| `sel[7]`           | F2      | LVCMOS33 | 位选 7          |
| `iic_scl`          | **E11** | LVCMOS33 | I2C 时钟        |
| `iic_sda`          | **M10** | LVCMOS33 | I2C 数据        |
| `tx`               | **F12** | LVCMOS33 | UART 发送       |
| `ds1302_ce`        | **A12** | LVCMOS33 | DS1302 片选     |
| `ds1302_data`      | **A13** | LVCMOS33 | DS1302 数据     |
| `ds1302_sclk`      | **A10** | LVCMOS33 | DS1302 时钟     |

### 5.2 配置约束

- **配置模式**: SPI x4
- **CCLK 速率**: 50 MHz
- **VCCO**: 3.3V

---

## 6. 数据流与用户操作

### 6.1 典型操作流程

```
┌──────────────────────────────────────────────────────────────┐
│  步骤 1          步骤 2          步骤 3          步骤 4      │
│  ────────        ────────        ────────        ────────    │
│  上电启动    →   多次采样    →   查看结果    →   串口上传    │
│                                                              │
│  显示 ADC       按 S1 记录      按 S2 切换      按 S4 触发   │
│  实时数据       当前 ADC 值     算法/浏览        UART 传输    │
│                 + 时间戳        各算法结果                     │
│                                                              │
│  随时可按 S3 清空缓冲区重新开始                              │
└──────────────────────────────────────────────────────────────┘
```

### 6.2 数据格式

**缓冲区存储格式 (32-bit):**

```
┌──────────────────────────────────────────────────────────────┐
│  [31:24]         [23:16]        [15:8]         [7:0]        │
│  ─────────────── ─────────────── ─────────────── ─────────── │
│  ADC值 (8-bit)   时 (8-bit)     分 (8-bit)     秒 (8-bit)   │
└──────────────────────────────────────────────────────────────┘
```

**UART 传输格式:**

- Phase 0 (原始数据): 每条 8 字节 → `{ADC[15:0], Padding[15:0], time[23:0], Padding[7:0]}`
- Phase 1 (算法结果): 由具体算法决定

---

## 7. 算法详解

### A1 — 最大/最小值查找 (`max_min`)

| 属性   | 值                         |
| ------ | -------------------------- |
| 方法   | 并行比较树 (generate 递归) |
| 延迟   | 3 个时钟周期               |
| 输出   | `max[7:0]`, `min[7:0]`     |
| 复杂度 | O(log₂N) 关键路径          |

### A2 — 滑动窗口平均 (`moving_average`)

| 属性     | 值              |
| -------- | --------------- |
| 窗口大小 | 3               |
| 方法     | 顺序逐元素计算  |
| 最小输入 | 3 个有效数据    |
| 输出数量 | `valid_cnt - 2` |

### A3 — 归一化到 [0,100] (`normalization`)

```
               (value - min) × 100
result = floor(────────────────────)
                   (max - min)
```

| 属性     | 值             |
| -------- | -------------- |
| 方法     | 移位减法除法器 |
| 延迟     | ~20 个时钟周期 |
| 取值范围 | 0 ~ 100        |

### A4 — 游程编码 (`rle_encode`)

| 属性     | 值                        |
| -------- | ------------------------- |
| 编码格式 | `{value, count}` 对       |
| 压缩判定 | `2 × seg_cnt < valid_cnt` |
| 最坏情况 | 无压缩（全不同值）        |

---

## 8. 仿真与验证

### 8.1 `tb_fsm` — FSM 功能仿真

**文件:** [`Indu_Monitor.srcs/sim_1/new/tb_fsm.v`](Indu_Monitor.srcs/sim_1/new/tb_fsm.v)

- **范围**: `fsm` 模块独立仿真
- **仿真器**: XSim (Vivado 内置)
- **运行时长**: 50 ms
- **测试序列**:
  1. 复位释放
  2. 记录 3 个 ADC 样本 (30, 50, 50)
  3. S4 触发 UART 发送
  4. 3 次 S3 清空缓冲区

### 8.2 `tb_max_min` — 算法 A1 单元测试

**文件:** [`Indu_Monitor.srcs/sources_1/new/tb_max_min.v`](Indu_Monitor.srcs/sources_1/new/tb_max_min.v)

自检式测试平台，覆盖 7 种场景:

| #   | 测试场景      | 说明                              |
| --- | ------------- | --------------------------------- |
| 1   | 基本 min/max  | 5 个值: 10, 50, 30, 80, 20        |
| 2   | 全相等        | 16 个相同值: 42                   |
| 3   | 单值          | 1 个输入: 77                      |
| 4   | 边界          | 最大值在前，最小值在后            |
| 5   | 满 16 个      | 全缓冲测试 (0~127)                |
| 6   | `valid_cnt=0` | 空缓冲边界（期望 max=0, min=255） |
| 7   | 动态切换      | `valid_cnt` 从 6 变到 2           |

---

## 9. 构建流程

### 9.1 环境要求

- **Vivado** ≥ 2023.2
- **目标板卡**: 搭载 Spartan-7 xc7s6ftgb196-1 的开发板

### 9.2 构建步骤

```bash
# 1. 打开 Vivado 工程
vivado Indu_Monitor.xpr

# 2. 运行综合 (Synthesis)
#    在 Vivado GUI: Flow Navigator → Synthesis → Run Synthesis
#    或 TCL: source Indu_Monitor.runs/synth_1/top.tcl

# 3. 运行实现 (Implementation)
#    在 Vivado GUI: Flow Navigator → Implementation → Run Implementation
#    或 TCL: source Indu_Monitor.runs/impl_1/top.tcl

# 4. 生成比特流 (Generate Bitstream)
#    在 Vivado GUI: Flow Navigator → Program and Debug → Generate Bitstream

# 5. 烧录到 FPGA
#    在 Vivado GUI: Flow Navigator → Program and Debug → Open Hardware Manager
```

### 9.3 自动生成脚本

| 脚本                                                                                           | 用途                                                                   |
| ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| [`Indu_Monitor.runs/synth_1/top.tcl`](Indu_Monitor.runs/synth_1/top.tcl)                       | 综合脚本：读取 16 个 .v 源文件和 top.xdc，运行 `synth_design -top top` |
| [`Indu_Monitor.runs/impl_1/top.tcl`](Indu_Monitor.runs/impl_1/top.tcl)                         | 实现脚本：opt → place → phys_opt → route → write_bitstream             |
| [`Indu_Monitor.sim/sim_1/behav/xsim/tb_fsm.tcl`](Indu_Monitor.sim/sim_1/behav/xsim/tb_fsm.tcl) | 仿真脚本：添加波形，运行 50ms XSim 仿真                                |

实现启动选项: `-jobs 12`（12 线程并行）

---

## 10. 设计要点与注意事项

### 10.1 已知设计决策

1. **综合警告抑制**: `.xpr` 工程文件中设置了消息抑制规则 `[Synth 8-524]` 作用于 `fsm.v:229`。该警告涉及 `din_flat_3` 超出范围的 part-select 索引——这是 `generate` 循环展开的已知边界效应，不影响功能。

2. **DS1302 只读使用**: `top.v` 中 DS1302 的所有写端口悬空且 `write_time_req` 接 0。RTC 仅被读取，时间初始值由外部设定。

3. **ADC 连续轮询**: `adc_start` 硬连线为高电平，I2C Master 持续读取 ADC——无空闲状态。

4. **算法数据宽度不一致**: A1/A2/A4 使用缓冲数据的低 8 位（ADC 值），而 A3 使用完整的 32 位 `DATA_WIDTH` 独立 `din_flat_3` 信号。

5. **归一化模块时序优化** (2026-07-04): 将组合除法器替换为多周期移位减法除法器，将关键路径从 ~130 级 CARRY4 降至 10 ns 以内。

### 10.2 注意事项

- **无 IP 核**: 所有功能均为自定义 Verilog RTL 实现，不依赖任何 Xilinx IP 目录中的 IP 核
- **无 Block Design**: 纯 RTL 设计流，无 `.bd` 文件，所有连线均为显式 Verilog 端口连接
- **单时钟域**: 所有模块共享 50 MHz 时钟，跨时钟域问题不在本设计范围内
- **上电初始化**: DS1302 的初始时间需要在系统上电前通过外部方式设置

---

## 11. 文件清单

### 11.1 RTL 设计源文件

| #   | 文件                  | 说明                    |
| --- | --------------------- | ----------------------- |
| 1   | `top.v`               | 顶层集成                |
| 2   | `fsm.v`               | 核心状态机与算法调度    |
| 3   | `ad_ctrl.v`           | ADC 控制器封装          |
| 4   | `iic_drive.v`         | I2C 主机控制器          |
| 5   | `key_debounce.v`      | 按键消抖                |
| 6   | `seven_segment.v`     | 7 段数码管驱动          |
| 7   | `bcd_3digit.v`        | 二进制→3 位 BCD         |
| 8   | `bcd_2digit.v`        | 二进制→2 位 BCD         |
| 9   | `max_min.v`           | 算法 A1: 最大/最小值    |
| 10  | `moving_average.v`    | 算法 A2: 滑动窗口平均   |
| 11  | `normalization.v`     | 算法 A3: 归一化 [0,100] |
| 12  | `rle_encode.v`        | 算法 A4: 游程编码       |
| 13  | `uart_tx.v`           | UART 发送器             |
| 14  | `ds1302_wr_drive.v`   | DS1302 RTC 控制器       |
| 15  | `ds1302_io_convert.v` | DS1302 3 线协议转换     |
| 16  | `spi_master.v`        | SPI 主机                |

> 以上文件均位于 `Indu_Monitor.srcs/sources_1/new/`

### 11.2 约束与仿真文件

| #   | 文件           | 说明                 |
| --- | -------------- | -------------------- |
| 17  | `top.xdc`      | 引脚约束与时序约束   |
| 18  | `tb_fsm.v`     | FSM 仿真测试平台     |
| 19  | `tb_max_min.v` | max_min 算法单元测试 |

### 11.3 工程文件

| #   | 文件/目录             | 说明              |
| --- | --------------------- | ----------------- |
| 20  | `Indu_Monitor.xpr`    | Vivado 工程文件   |
| 21  | `Indu_Monitor.runs/`  | 综合/实现运行产物 |
| 22  | `Indu_Monitor.sim/`   | 仿真输出          |
| 23  | `Indu_Monitor.cache/` | 工程缓存          |
| 24  | `Indu_Monitor.hw/`    | 硬件管理器数据    |

---

## 12. 版本历史

| 日期       | 版本 | 说明                                                            |
| ---------- | ---- | --------------------------------------------------------------- |
| 2026-07-04 | v1.0 | 初始版本。完成 16 个模块的 RTL 设计、综合、实现。               |
| 2026-07-04 | v1.1 | `normalization` 模块时序优化：组合除法器→多周期移位减法除法器。 |
| 2026-07-04 | —    | 添加工程详细文档 `README.md`。                                  |

---

> **作者**: smith lvan && yszaygr2138
> **Git 分支**: `main`
> **最近提交**: `a0d4eea` — fix:第一次提交
