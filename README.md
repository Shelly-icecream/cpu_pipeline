# RV32I 三级流水线 CPU

一个使用 Verilog 实现的教学型 32 位 RISC-V 处理器核，采用 **IF、ID+EX、MEM+WB** 三级流水线结构，支持行为仿真、自检 Testbench，以及在 **Digilent Nexys4 DDR** FPGA 开发板上的手动单步和低速自动运行。

> 本项目实现的是 RV32I 的一个功能子集，并非完整的 RV32I 处理器。

## 项目特点

- 三级流水线：`IF | ID + EX | MEM + WB`
- 32 个 32 位通用寄存器，`x0` 恒为 0
- Register File 采用同步写、异步读结构
- 指令 ROM 使用 Vivado Distributed Memory Generator IP
- 通过 `instruction.coe` 初始化 256 × 32 bit 指令存储器
- 数据存储器按字节寻址、小端序组织，默认容量为 1024 Byte
- 支持字和字节访存，`LB` 自动进行符号扩展
- 使用 `valid`、`enable` 和 `flush` 控制流水线状态
- 无数据前递；RAW 数据相关通过暂停和插入气泡解决
- `BNE` 和 `JAL` 在 ID+EX 级完成重定向，并冲刷错误路径指令
- 支持 FPGA 手动单步、低速自动运行、寄存器查看和状态 LED 显示
- 提供处理器核和板级顶层两套自检 Testbench

## 流水线结构

```text
                         ┌───────────────────────────┐
                         │        Next PC MUX        │
                         │  PC+4 / redirect_target   │
                         └─────────────┬─────────────┘
                                       │
┌─────────────── IF ───────────────────▼──────────────────┐
│  PC Register ──► Instruction ROM                       │
│       │                                                 │
│       └────────► PC + 4                                 │
└───────────────────────┬─────────────────────────────────┘
                        │ PC + instruction + valid
                 ┌──────▼──────┐
                 │ IF/ID Reg   │
                 └──────┬──────┘
                        │
┌──────────── ID + EX ──▼─────────────────────────────────┐
│ Decode / Control / Register File / ImmGen / ALU         │
│ Hazard detection / BNE & JAL resolution                 │
└───────────────────────┬─────────────────────────────────┘
                        │ result + rd + control + valid
                 ┌──────▼──────┐
                 │ EX/WB Reg   │
                 └──────┬──────┘
                        │
┌──────────── MEM + WB ─▼─────────────────────────────────┐
│ Data Memory ──► Write-back MUX ──► Register File        │
└─────────────────────────────────────────────────────────┘
```

### 数据冒险处理

本设计没有实现 forwarding。HazardUnit 检测 IF/ID 中消费者指令的 `rs1/rs2` 是否依赖当前 EX/WB 指令的 `rd`。检测到 RAW 冒险时：

1. 冻结 PC；
2. 冻结 IF/ID 流水寄存器；
3. 清空 EX/WB 的新输入，在流水线中插入一个 bubble；
4. 前一条指令仍可在该时钟沿完成写回；
5. 冒险解除后，消费者从异步读端口获得新寄存器值并继续执行。

### 控制冒险处理

`BNE` 和 `JAL` 在 ID+EX 级计算跳转目标地址。当分支成立或执行 `JAL` 时，`redirect_valid` 使下一 PC 选择 `redirect_target`，同时冲刷 IF/ID 中已经顺序取出的错误路径指令。若分支源操作数存在 RAW 相关，重定向会等待数据冒险解除后再执行。

## 已实现指令

| 类型 | 指令 | 功能 |
|---|---|---|
| R 型 | `ADD` | 寄存器加法 |
| R 型 | `SUB` | 寄存器减法 |
| I 型 | `ADDI` | 寄存器与立即数加法 |
| Load | `LB` | 读取有符号字节 |
| Load | `LW` | 读取 32 位字 |
| Store | `SB` | 写入低 8 位 |
| Store | `SW` | 写入 32 位字 |
| Branch | `BNE` | 不相等时分支 |
| Jump | `JAL` | 跳转并将 `PC+4` 写入 `rd` |

ALU 模块内部还实现了 `AND`、`OR`、`XOR` 和 `SLT` 运算，但当前主控制器尚未将这些指令作为完整端到端指令开放。如需使用，需要扩展 `Control.v` 的 R 型译码条件。

## 目录结构

```text
cpu_pipeline/
├── sources_1/
│   ├── imports/
│   │   ├── rtl/                    # CPU 核 RTL
│   │   │   ├── ThreeStageCPU.v     # 处理器核顶层
│   │   │   ├── PC.v
│   │   │   ├── IF_ID_Reg.v
│   │   │   ├── EX_WB_Reg.v
│   │   │   ├── RegisterFile.v
│   │   │   ├── Control.v
│   │   │   ├── ALUControl.v
│   │   │   ├── ALU.v
│   │   │   ├── ImmGen.v
│   │   │   ├── HazardUnit.v
│   │   │   ├── DataMemory.v
│   │   │   ├── cpu_defs.vh
│   │   │   └── instruction.coe     # 示例程序机器码
│   │   └── rtl_add/                # FPGA 板级支持逻辑
│   │       ├── CPUBoardTop.v
│   │       ├── CpuRunControl.v
│   │       ├── ButtonDebounceOnePulse.v
│   │       └── SevenSegmentDisplay.v
│   └── ip/InstructionROM/          # Vivado 指令 ROM IP
├── sim_1/imports/tb/
│   ├── tb_ThreeStageCPU_CE.v       # CPU 核自检
│   └── tb_CPUBoardTop.v            # 板级顶层自检
└── constrs_1/imports/constraints/
    └── Nexys4DDR_CPUBoardTop.xdc   # Nexys4 DDR Rev. C 管脚约束
```

## 开发环境

- AMD/Xilinx Vivado
- Verilog HDL
- 目标器件：Artix-7 `XC7A100T-1CSG324C`
- 目标开发板：Digilent Nexys4 DDR Rev. C
- 系统时钟：100 MHz

仓库中的 `InstructionROM.xci` 由 Vivado 2018.3 生成。使用较新版本 Vivado 打开时，工具可能提示升级 IP，按提示执行 **Upgrade IP** 并重新生成 Output Products 即可。

> 仓库保存的是 RTL、IP、仿真和约束文件，不包含可直接打开的 `.xpr` 工程文件，需要在 Vivado 中新建工程并添加这些文件。

## 快速开始

### 1. 获取代码

```bash
git clone https://github.com/Shelly-icecream/cpu_pipeline.git
cd cpu_pipeline
```

### 2. 创建 Vivado 工程

1. 新建 RTL Project，器件选择与 Nexys4 DDR 对应的 `xc7a100tcsg324-1`；
2. 将 `sources_1/imports/rtl/` 下的 `.v`、`.vh` 文件加入 Design Sources；
3. 上板时，再加入 `sources_1/imports/rtl_add/` 下的板级模块；
4. 将 `sources_1/ip/InstructionROM/InstructionROM.xci` 加入 IP Sources；
5. 右键 `InstructionROM`，选择 **Generate Output Products**；
6. 将 `sim_1/imports/tb/` 下需要使用的 Testbench 加入 Simulation Sources；
7. 上板时加入 `Nexys4DDR_CPUBoardTop.xdc`。

建议确认 `sources_1/imports/rtl/` 位于 Verilog Include Directories 中，使 `` `include "cpu_defs.vh" `` 能够被正确解析。

## 行为仿真

### CPU 核自检

将以下模块设置为仿真顶层：

```text
tb_ThreeStageCPU_CE
```

运行 Behavioral Simulation。测试平台会：

- 产生 100 MHz 时钟；
- 通过 `clock_enable` 单周期推进 CPU；
- 在仿真中设置 `mem[0]=0x05`、`mem[8]=0x80`；
- 检查 `x1`、`x2`、`x7`、`x9` 和 `x10` 的最终值。

成功时控制台输出：

```text
ALL CORE CLOCK-ENABLE TESTS PASSED
```

关键预期结果：

| 状态 | 预期值 | 验证内容 |
|---|---:|---|
| `x1` | `0x00000005` | `LW` 读取 |
| `x2` | `0x00000008` | RAW 冒险后的运算 |
| `x7` | `0x00000028` | `JAL` 写回 `PC+4` |
| `x9` | `0xFFFFFF80` | `LB` 符号扩展 |
| `x10` | `0xFFFFFF81` | 字节访存及后续运算 |

### 板级顶层自检

将以下模块设置为仿真顶层：

```text
tb_CPUBoardTop
```

该测试会检查：

- 手动按键每次只产生一个 CPU enable 脉冲；
- 自动运行模式；
- 示例程序关键寄存器结果；
- PC、指令、寄存器编号和寄存器数据的显示选择优先级。

成功时控制台输出：

```text
ALL BOARD-TOP TESTS PASSED
```

## 修改指令程序

指令 ROM 深度为 256 个 32 位字，CPU 使用 `PC[9:2]` 作为 ROM 地址，因此可容纳 1 KiB 指令空间。程序机器码保存在：

```text
sources_1/imports/rtl/instruction.coe
```

COE 文件格式示例：

```text
memory_initialization_radix=16;
memory_initialization_vector=
00002083,
00308113,
00000013;
```

修改程序后，需要在 Vivado 中重新生成 `InstructionROM` 的 Output Products，并重新运行仿真或生成 bitstream。ROM 未显式初始化的位置默认填充 RISC-V NOP：

```text
00000013    # addi x0, x0, 0
```

## FPGA 上板

### 综合与下载

1. 将 `CPUBoardTop` 设置为 Design Top；
2. 加入 `Nexys4DDR_CPUBoardTop.xdc`；
3. 生成 `InstructionROM` Output Products；
4. 依次运行 Synthesis、Implementation 和 Generate Bitstream；
5. 通过 Hardware Manager 下载到 Nexys4 DDR。

### 按键与开关

| 输入 | 功能 |
|---|---|
| `CPU_RESETN` | 板载低有效硬复位 |
| `BTNU` | 消抖后的软复位 |
| `BTNC` | 手动模式下推进一个完整 CPU 周期 |
| `SW[15]` | `0`：手动单步；`1`：自动低速运行 |
| `SW[14]` | 数码管显示当前 ID 级指令 |
| `SW[13]` | 数码管显示当前查看的寄存器编号（十进制） |
| `SW[12]` | 数码管显示当前查看的寄存器内容（十六进制） |
| `SW[11]` | `0`：查看 `SW[4:0]` 指定寄存器；`1`：查看最近写回的寄存器 |
| `SW[4:0]` | 手动选择 `x0`～`x31` |

数码管显示优先级为：

```text
SW14（指令） > SW13（寄存器编号） > SW12（寄存器数据） > PC
```

验证时建议一次只打开一个显示选择开关。

默认参数 `AUTO_DIVISOR=50_000_000`，在 100 MHz 系统时钟下约产生每秒 2 个 CPU 周期。

### LED 状态

| LED | 含义 |
|---|---|
| `LED[4:0]` | 当前查看的寄存器编号 |
| `LED[5]` | 曾经发生过 stall，复位后清零 |
| `LED[6]` | 曾经发生过 flush，复位后清零 |
| `LED[7]` | 当前 `IF/ID valid` |
| `LED[8]` | 当前 `EX/WB valid` |
| `LED[9]` | 已记录过非零目标寄存器写回 |
| `LED[10]` | CPU 推进心跳，每个有效 CPU 周期翻转 |
| `LED[11]` | 自动运行模式指示 |
| `LED[15:12]` | 保留，固定为 0 |

## 数据存储器初值说明

`DataMemory.v` 默认在初始化时将全部字节清零。仿真 Testbench 中使用以下形式的层次化赋值设置测试数据：

```verilog
dut.u_dmem.mem[0] = 8'h05;
dut.u_dmem.mem[8] = 8'h80;
```

这种赋值仅存在于仿真环境，不会自动写入 FPGA bitstream。因此，默认上板时数据存储器初值为全零。若需要让 FPGA 与 Testbench 使用相同初值，应在 `DataMemory.v` 中加入可综合初始化，或改用适合目标器件的 RAM 初始化文件。

此外，DataMemory 没有复位端口。按下 CPU 复位键会清空 PC、流水线和寄存器堆，但不会恢复运行期间已经写入的数据存储器内容；重新配置 FPGA 才会重新应用其初始化值。

## 当前限制

- 仅实现 RV32I 指令子集，不支持完整 RV32I；
- 不支持 `JALR`、其他条件分支、CSR、异常、中断和特权级；
- 不支持乘除法、原子操作、浮点和向量扩展；
- 没有数据前递，RAW 相关会引入一个停顿周期；
- 没有缓存、总线接口和外部数据存储器控制器；
- 非法指令被标记为无效，不会进入后级，但目前没有异常处理机制；
- 指令 ROM 为 Vivado IP，脱离 Vivado 使用时需要替换为等效 ROM 模块。

## 可扩展方向

- 完成其余 RV32I 指令译码；
- 增加 EX/WB 到 ID/EX 的数据前递；
- 增加更多分支指令和分支预测；
- 将数据存储器替换为 Block RAM 或总线接口；
- 增加 CSR、异常和中断支持；
- 增加 UART、GPIO 等存储器映射外设；
- 添加自动化仿真脚本和持续集成测试。

## 许可证

当前仓库未包含 `LICENSE` 文件。如需复制、修改或分发本项目，请先与仓库作者确认授权，或为项目补充明确的开源许可证。
