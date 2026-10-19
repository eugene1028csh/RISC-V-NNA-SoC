# RISC-V + INT8 Neural Network Accelerator SoC

A custom FPGA SoC integrating a **32-bit RISC-V processor**, a **custom XiCRC instruction accelerator**, and a **4×4 INT8 neural-network accelerator**.

The complete system is implemented on a **Sipeed Tang Nano 20K** using a mixed **SystemVerilog / Verilog / VHDL** RTL flow.

## System Architecture

```text
                    +------------------------+
                    |      RISC-V CPU        |
                    |                        |
                    |  Single-cycle core     |
                    |  + XiCRC extension     |
                    +-----------+------------+
                                |
                         Memory-Mapped I/O
                                |
                    0x40000000 - 0x400000FF
                                |
                    +-----------v------------+
                    |    NNA MMIO Wrapper    |
                    |                        |
                    |  START / DONE          |
                    |  Input / Weight /      |
                    |  Bias / Output regs    |
                    +-----------+------------+
                                |
                    +-----------v------------+
                    |     4×4 INT8 NNA       |
                    |                        |
                    |  INT8 multiply         |
                    |  INT32 accumulate      |
                    |  Bias addition         |
                    |  ReLU                  |
                    +------------------------+
```

The RISC-V processor communicates with the neural-network accelerator using ordinary `LW` and `SW` instructions through a memory-mapped peripheral interface.

---

## Features

### RISC-V CPU

A modular single-cycle 32-bit RISC-V processor implemented in SystemVerilog.

Implemented functionality includes:

- Integer ALU operations
- Immediate arithmetic and logical operations
- Load/store
- Conditional branches
- `JAL`
- `JALR`
- `LUI`
- `AUIPC`
- 32 × 32-bit register file
- Instruction memory
- Data memory
- Memory-mapped peripheral interface
- Custom XiCRC instruction extension

Major CPU modules include:

```text
rv32i_core
├── rv32i_pc
├── rv32i_imem
├── rv32i_decoder
├── rv32i_regfile
├── rv32i_imme_gnrtr
├── rv32i_alu
├── rv32i_branch_unit
├── rv32i_dmem
├── rv32i_next_pc
└── xicrc_accelerator_unit
```

---

## XiCRC Custom Instruction Extension

The CPU contains a custom CRC accelerator integrated directly into the processor's decode, execution, and writeback paths.

The extension supports multiple CRC operand widths through custom R-type encodings.

The FPGA boot program performs a XiCRC self-test before allowing execution to continue to the NNA test.

Test vector:

```text
Data        = 0x0D
Initial CRC = 0x0000
CRC result  = 0xD1AD
```

The program computes the CRC and compares it with the expected result.

If the comparison fails, the processor enters a fail loop and the NNA test is not executed.

This makes the XiCRC accelerator part of the actual FPGA hardware-validation path rather than an unused standalone module.

---

## INT8 Neural Network Accelerator

The neural-network accelerator is implemented in VHDL.

The active 4×4 accelerator datapath contains:

- 4-element INT8 input buffer
- 16-element INT8 weight buffer
- 4-element INT32 bias buffer
- 4×4 processing-element array
- INT8 × INT8 multiplication
- INT32 accumulation
- Bias addition
- ReLU activation
- Output buffering
- Start/done control FSM

Active hierarchy:

```text
toplvl
├── input_buffer_4
├── weight_buffer_16
├── bias_buffer_4
├── matvec_engine_4x4
│   └── pe_array_4x4
│       └── pe
│           └── mac
├── bias_add_2
├── relu_2
└── output_buffer_4
```

The accelerator was developed and verified independently before being integrated into the RISC-V SoC.

---

## Memory-Mapped NNA Interface

The NNA is exposed to the CPU through a memory-mapped interface.

The assigned address region is:

```text
0x40000000 - 0x400000FF
```

### Memory Map

| Address | Register | Description |
|---|---|---|
| `0x40000000` | CONTROL | Bit 0 = START |
| `0x40000004` | STATUS | Bit 0 = DONE |
| `0x40000010` | INPUT0 | Input element 0 |
| `0x40000014` | INPUT1 | Input element 1 |
| `0x40000018` | INPUT2 | Input element 2 |
| `0x4000001C` | INPUT3 | Input element 3 |
| `0x40000040` | WEIGHT0 | Weight element 0 |
| `...` | `...` | `...` |
| `0x4000007C` | WEIGHT15 | Weight element 15 |
| `0x40000080` | BIAS0 | Bias element 0 |
| `0x40000084` | BIAS1 | Bias element 1 |
| `0x40000088` | BIAS2 | Bias element 2 |
| `0x4000008C` | BIAS3 | Bias element 3 |
| `0x400000C0` | OUT0 | Output element 0 |
| `0x400000C4` | OUT1 | Output element 1 |
| `0x400000C8` | OUT2 | Output element 2 |
| `0x400000CC` | OUT3 | Output element 3 |

The processor therefore accesses the accelerator using ordinary RISC-V instructions such as:

```asm
sw x5, 0x10(x10)
lw x6, 0x04(x10)
```

where `x10` contains the base address:

```text
0x40000000
```

### Sticky DONE Flag

The NNA produces a short completion pulse.

To prevent software from missing this pulse, the MMIO wrapper stores completion in a sticky status register.

```text
NNA done pulse
      ↓
done_sticky = 1
      ↓
CPU polls STATUS
      ↓
CPU observes completion reliably
```

The sticky flag is cleared when a new accelerator operation begins or when the system is reset.

---

## CPU Memory Routing

The CPU distinguishes between normal data-memory accesses and NNA MMIO accesses using the `bus_hit` signal.

```text
CPU address
    |
    +---- normal address ------> DMEM
    |
    +---- 0x400000xx ----------> NNA MMIO
```

For stores:

```text
bus_hit = 0 → write DMEM
bus_hit = 1 → write NNA peripheral
```

For loads:

```text
bus_hit = 0 → read DMEM
bus_hit = 1 → read NNA peripheral
```

This allows the accelerator to behave like a normal memory-mapped hardware peripheral.

---

## FPGA Hardware Self-Test

The FPGA instruction ROM contains a small boot program that validates the complete integrated system.

After reset is released, the CPU performs the following sequence:

1. Execute the XiCRC self-test.
2. Compare the result against `0xD1AD`.
3. Load the NNA input vector.
4. Load the NNA weight matrix.
5. Load the NNA biases.
6. Start the accelerator.
7. Poll the STATUS register until DONE is asserted.
8. Read all four output registers.
9. Validate the results.
10. Assert the hardware PASS indicator.

### NNA Test Data

Input vector:

```text
[1, 2, 3, 4]
```

Weights:

```text
1, 2, 3, 4,
5, 6, 7, 8,
9, 10, 11, 12,
13, 14, 15, 16
```

Biases:

```text
[-40, -60, 5, -200]
```

Expected output:

```text
OUT0 = 0
OUT1 = 10
OUT2 = 115
OUT3 = 0
```

The PASS output is only asserted after the CPU has observed all four expected results.

Therefore the onboard PASS LED validates the complete path:

```text
Instruction ROM
      ↓
RISC-V CPU
      ↓
XiCRC custom instruction
      ↓
MMIO writes
      ↓
NNA configuration
      ↓
NNA execution
      ↓
DONE polling
      ↓
MMIO reads
      ↓
Output validation
      ↓
PASS LED
```

Pressing the onboard S1 button resets the SoC and clears the PASS indication.

Releasing S1 restarts the complete self-test.

---

## FPGA Target

```text
Board:        Sipeed Tang Nano 20K
FPGA family:  Gowin GW2AR
Device:       GW2AR-18
Clock:        27 MHz
Toolchain:    Gowin EDA
```

The project uses:

- VHDL-2008
- SystemVerilog-2017
- Gowin synthesis
- Gowin place and route
- Static timing analysis
- SRAM FPGA programming

---

## FPGA Implementation Results

Current implementation resource usage is approximately:

```text
LUTs:       1157
Registers:  625
DSPs:       4
SSRAM:      160
```

The design was successfully:

```text
Synthesized       PASS
Placed & Routed   PASS
Timing Checked    PASS
Programmed        PASS
Hardware Tested   PASS
```

The implemented design meets timing at the 27 MHz board clock.

---

## Verification

The project was verified incrementally rather than only at final integration.

```text
RISC-V CPU simulation               PASS
XiCRC standalone simulation         PASS
XiCRC full-core integration         PASS
CPU MMIO routing simulation         PASS
NNA standalone simulation           PASS
NNA MMIO wrapper simulation         PASS
Mixed-language Gowin elaboration    PASS
FPGA synthesis                      PASS
Place and route                     PASS
Timing closure @ 27 MHz             PASS
Tang Nano 20K hardware self-test    PASS
```

---

## NNA MMIO Wrapper Simulation

The NNA MMIO wrapper can be tested independently using GHDL.

From the repository root:

```powershell
ghdl -i --std=08 (Get-ChildItem rtl\nna\*.vhd).FullName rtl\nna_mmio_wrapper.vhd tb\nna_mmio_wrapper_tb.vhd
ghdl -m --std=08 nna_mmio_wrapper_tb
ghdl -r --std=08 nna_mmio_wrapper_tb --assert-level=error --stop-time=10us
```

Expected output:

```text
PASS: NNA MMIO wrapper test
```

The testbench verifies:

- Input MMIO writes
- Weight MMIO writes
- Bias MMIO writes
- START control
- Sticky DONE behavior
- Output MMIO reads
- Expected NNA result `[0, 10, 115, 0]`

---

## Languages

| Language | Usage |
|---|---|
| SystemVerilog | RISC-V CPU |
| Verilog | XiCRC accelerator |
| VHDL | INT8 NNA |
| VHDL | NNA MMIO wrapper |
| VHDL | SoC top-level integration |

The project therefore also demonstrates mixed-language FPGA integration.

---

## Repository Structure

```text
RISC-V-NNA-SoC/
│
├── README.md
├── .gitignore
│
├── rtl/
│   ├── soc_top.vhd
│   ├── nna_mmio_wrapper.vhd
│   │
│   ├── cpu/
│   │   ├── rv32i_alu.sv
│   │   ├── rv32i_branch_unit.sv
│   │   ├── rv32i_core.sv
│   │   ├── rv32i_decoder.sv
│   │   ├── rv32i_dmem.sv
│   │   ├── rv32i_imem.sv
│   │   ├── rv32i_imme_gnrtr.sv
│   │   ├── rv32i_next_pc.sv
│   │   ├── rv32i_pc.sv
│   │   ├── rv32i_regfile.sv
│   │   ├── rv32i_types.sv
│   │   ├── xicrc_accelerator_unit.v
│   │   └── xicrc_exec.v
│   │
│   └── nna/
│       ├── bias_add_2.vhd
│       ├── bias_buffer_4.vhd
│       ├── input_buffer_4.vhd
│       ├── mac.vhd
│       ├── matvec_engine_4x4.vhd
│       ├── output_buffer_4.vhd
│       ├── pe.vhd
│       ├── pe_array_4x4.vhd
│       ├── relu_2.vhd
│       ├── toplvl.vhd
│       └── weight_buffer_16.vhd
│
├── tb/
│   └── nna_mmio_wrapper_tb.vhd
│
└── constraints/
    ├── tangnano20k.cst
    └── tangnano20k.sdc
```

---

## Project Separation

This repository focuses specifically on **SoC integration and FPGA deployment**.

The CPU and neural-network accelerator were developed independently before integration.

The project is therefore separated conceptually into:

```text
RISC-V Processor project
        ↓
CPU + XiCRC development

INT8 NNA project
        ↓
Accelerator development

RISC-V-NNA-SoC
        ↓
CPU + accelerator integration
MMIO
FPGA deployment
Hardware validation
```

---

## Current Status

### v0.1 — FPGA MVP Complete

The complete integrated execution path has been demonstrated successfully on physical hardware:

```text
RISC-V CPU
    ↓
XiCRC custom instruction
    ↓
Memory-Mapped I/O
    ↓
INT8 Neural Network Accelerator
    ↓
Output Validation
    ↓
Hardware PASS
```

The design successfully synthesizes, meets timing, programs onto the Tang Nano 20K, and repeatedly passes the onboard hardware self-test after reset.