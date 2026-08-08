# UART Transmitter

> A from-scratch UART TX module written in VHDL, targeting a 50 MHz FPGA clock at 115,200 baud (8N1).

![HDL](https://img.shields.io/badge/Language-VHDL-purple)
![Protocol](https://img.shields.io/badge/Protocol-UART%208N1-blue)
![Baud](https://img.shields.io/badge/Baud-115200-orange)

## Overview

A single-file, synthesizable UART transmitter. It takes an 8-bit parallel data bus, serializes it LSB-first through a PISO shift register, and frames it with standard start/stop bits per the RS-232 protocol.

I made this module as part of an ongoing effort to approach embedded/real-time systems from both ends of the computing stack: HDL on the hardware side, and bare-metal C/c++ on the software side, so that they meet in the middle.

## State Machine

The transmitter is driven by a four-state FSM, clocked by a baud-rate tick derived from the system clock (`50 MHz / 434 ≈ 115,207 baud`).

```
        i_go = '0'                       r_bit_index = 7
 IDLE ──────────► START_BIT ──► DATA_BIT ──────────────► STOP_BIT
  ▲               (o_data='0')   (PISO)     (o_data='1')     ▲
  │                                                          │
  └──────────────────────────────────────────────────────────┘
```

| State | Function |
|---|---|
| **IDLE** | Line held high (`'1'`). Waits for the active-low `i_go` signal, then latches `i_data` into the shift register. |
| **START_BIT** | Pulls the line low (`'0'`) for one baud period to wake the receiver. |
| **DATA_BIT** | Shifts the 8-bit register out LSB-first, replacing transmitted bits with zeros. |
| **STOP_BIT** | Raises the line back to `'1'` and asserts `o_done` for one baud period. |

## Port Map

| Port | Direction | Width | Description |
|---|---|---|---|
| `i_clk` | in | 1 | 50 MHz system clock |
| `i_reset` | in | 1 | Active-low asynchronous reset |
| `i_go` | in | 1 | Active-low transmission trigger |
| `i_data` | in | 8 | Parallel data to transmit |
| `o_data` | out | 1 | Serial TX line |
| `o_done` | out | 1 | Transmission complete flag |

## Simulation

Load `uart_tx.vhd` into any VHDL simulator (ModelSim, GHDL, Vivado) with a testbench that asserts `i_go` and provides an 8-bit stimulus on `i_data`. The full byte frame (start + 8 data + stop) should complete in `10 × 434 = 4,340` clock cycles.

---
*made with logic, coffee, and many sleepless nights*