# Codemap: UART_TX

← [README](README.md)

> Generated from commit `d64d159` by `scripts/codemap.py`. Regenerate it from the workspace root with `python3 scripts/codemap.py UART_TX`; don't edit it by hand.

## Design

```mermaid
flowchart TB
    n_uart_tx["uart_tx · uart-tx.vhd"]
```

### `uart_tx` (`uart-tx.vhd`)

- **In:** `i_clk`, `i_reset`, `i_go`, `i_data`
- **Out:** `o_done`, `o_data`
- **Generics:** `MAX_COUNT`
