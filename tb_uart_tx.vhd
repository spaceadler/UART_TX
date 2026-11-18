-- tb_uart_tx.vhd - testbench for uart_tx
--
-- Sends four bytes, each with a one-clock i_go pulse, and checks every frame:
--   * the start bit, the 8 data bits LSB first and the stop bit, each sampled
--     in the middle of its bit period
--   * o_done is high for exactly one clock, 10 bit periods after the edge that saw i_go
--
-- MAX_COUNT is 8 here instead of 434 so the waveform stays short; the timing
-- rules are the same for any MAX_COUNT.
--
--   ghdl -a --std=08 uart-tx.vhd tb_uart_tx.vhd
--   ghdl -e --std=08 tb_uart_tx
--   ghdl -r --std=08 tb_uart_tx --vcd=tb_uart_tx.vcd

library ieee;
use ieee.std_logic_1164.all;

entity tb_uart_tx is
end entity tb_uart_tx;

architecture sim of tb_uart_tx is

    constant M      : natural := 8;         -- clocks per bit
    constant T_CLK  : time    := 20 ns;     -- 50 MHz

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '0';     -- active low
    signal go       : std_logic := '1';     -- active low
    signal data     : std_logic_vector(7 downto 0) := (others => '0');
    signal done     : std_logic;
    signal tx       : std_logic;
    signal running  : boolean := true;

begin

    clk <= not clk after T_CLK / 2 when running;

    dut : entity work.uart_tx
        generic map (MAX_COUNT => M)
        port map (
            i_clk   => clk,
            i_reset => rst,
            i_go    => go,
            i_data  => data,
            o_done  => done,
            o_data  => tx);

    stim : process
        variable errors : natural := 0;

        procedure send_and_check (b : std_logic_vector(7 downto 0)) is
            variable frame : std_logic_vector(0 to 9);
        begin
            frame := '0' & b(0) & b(1) & b(2) & b(3) & b(4) & b(5) & b(6) & b(7) & '1';

            -- one-clock i_go pulse; the rising edge in the middle of it starts the frame
            wait until falling_edge(clk);
            data <= b;
            go   <= '0';
            wait until falling_edge(clk);
            go   <= '1';

            -- n counts falling edges since that rising edge
            for n in 1 to 10 * M + 1 loop
                wait until falling_edge(clk);

                if (n mod M = M / 2) and (n / M <= 9) then
                    if tx /= frame(n / M) then
                        report "byte " & to_hstring(b) & ": bit " & integer'image(n / M)
                             & " is " & std_logic'image(tx) & ", expected "
                             & std_logic'image(frame(n / M)) severity error;
                        errors := errors + 1;
                    end if;
                end if;

                if (n = 10 * M) and (done /= '1') then
                    report "byte " & to_hstring(b) & ": o_done missing after 10 bits" severity error;
                    errors := errors + 1;
                elsif (n /= 10 * M) and (done /= '0') then
                    report "byte " & to_hstring(b) & ": o_done high at clock " & integer'image(n)
                         severity error;
                    errors := errors + 1;
                end if;
            end loop;

            if tx /= '1' then
                report "byte " & to_hstring(b) & ": line not idle high after the frame" severity error;
                errors := errors + 1;
            end if;
        end procedure;

    begin
        -- hold reset for a few clocks; the line must idle high
        for i in 1 to 4 loop
            wait until falling_edge(clk);
        end loop;
        rst <= '1';
        wait until falling_edge(clk);
        if tx /= '1' then
            report "line not idle high after reset" severity error;
            errors := errors + 1;
        end if;

        send_and_check(x"A5");
        send_and_check(x"3C");
        send_and_check(x"00");
        send_and_check(x"FF");

        if errors = 0 then
            report "PASS: 4 frames, start/data/stop bits and o_done timing all correct" severity note;
        else
            report "FAIL: " & integer'image(errors) & " error(s)" severity failure;
        end if;

        running <= false;
        wait;
    end process;

end architecture sim;
