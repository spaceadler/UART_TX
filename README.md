# UART Transmitter

> A from-scratch UART TX module in VHDL: 50 MHz clock in, 115,200 baud 8N1 out.

![HDL](https://img.shields.io/badge/Language-VHDL-purple)
![Protocol](https://img.shields.io/badge/Protocol-UART%208N1-blue)
![Baud](https://img.shields.io/badge/Baud-115200-orange)

## Overview

One synthesizable file, `uart-tx.vhd`. It latches an 8-bit bus, shifts it out LSB-first through a PISO register, and frames it with start and stop bits. It's the hardware half of meeting bare-metal C in the middle.

## Architecture

```mermaid
flowchart TB
    clk["i_clk 50 MHz"] --> div["baud divider<br/>÷434"]
    div -->|"baud_tick"| fsm["4-state FSM"]
    go["i_go (active low)"] --> fsm
    data["i_data[7:0]"] --> sh["PISO shift reg"]
    fsm <--> sh
    fsm --> tx["o_data (TX line)"]
    fsm --> done["o_done"]
```

`50,000,000 / 434 ≈ 115,207 baud` (+0.006 %). The divider rests at 0 while idle and restarts with every frame, so each bit lasts exactly 434 clocks.

## State Machine

```mermaid
stateDiagram-v2
    [*] --> IDLE
    IDLE --> START_BIT: i_go low, latch i_data, line low
    START_BIT --> DATA_BIT: tick, bit 0 out
    DATA_BIT --> DATA_BIT: tick, bits 1 to 7 out
    DATA_BIT --> STOP_BIT: tick after bit 7, line high
    STOP_BIT --> IDLE: tick, o_done pulse
```

## Frame

```
 i_go ‾‾‾‾\_/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
 o_data‾‾‾‾\_____/ b0 X b1 X b2 X b3 X b4 X b5 X b6 X b7 /‾‾‾‾‾‾
           │start│◄──────── 8 × 434 clocks ─────────►│stop│
 o_done ____________________________________________________/\_
           └──────────── 10 × 434 = 4,340 clocks ──────────┘
```

## Port Map

| Port | Dir | Width | Description |
|---|---|---|---|
| `i_clk` | in | 1 | 50 MHz system clock |
| `i_reset` | in | 1 | Active-low asynchronous reset |
| `i_go` | in | 1 | Active-low start. Seen on any clock, so a 1-clock pulse works; ignored mid-frame and on the clock right after `o_done`. Hold it low to stream back-to-back bytes |
| `i_data` | in | 8 | Byte to send, latched the clock `i_go` is seen. When streaming, put the next byte on it in response to `o_done` |
| `o_data` | out | 1 | Serial TX line, idles high |
| `o_done` | out | 1 | One-clock pulse when the stop bit ends |

## Simulation

```bash
ghdl -a --std=08 uart-tx.vhd tb_uart_tx.vhd
ghdl -e --std=08 tb_uart_tx
ghdl -r --std=08 tb_uart_tx --vcd=tb_uart_tx.vcd   # prints PASS or the failing bit
```

`tb_uart_tx.vhd` sends four bytes (`A5`, `3C`, `00`, `FF`), each with a one-clock `i_go` pulse. It samples every bit in the middle of its period and checks that `o_done` is high for exactly one clock, 10 bit periods after the edge that saw `i_go`. It sets `MAX_COUNT` to 8 so the waveform stays short; at 434, `o_done` comes 4,340 clocks after that edge, and streamed frames start 4,342 clocks apart.

**Codemap:** [CODEMAP.md](CODEMAP.md), the entities, ports and processes, generated from the code.

---
*powered by logic, coffee, and many sleepless nights*
