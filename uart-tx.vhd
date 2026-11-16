library ieee;
use ieee.std_logic_1164.all;

entity uart_tx is
	-- definitions
        generic (
        MAX_COUNT   :       natural := 434);		    -- make it count to 434 as the result of 50 million over 115,200

        Port (
        i_clk		:	    in      std_logic;			-- clock lmao
        i_reset		:       in      std_logic;			-- reset button
        i_go		:       in      std_logic;			-- go button
	    i_data		:	    in	std_logic_vector(7 downto 0);	-- 8 bit register containing the data to be shifted PISO style

        o_done		:       out     std_logic;			-- one clock pulse: the stop bit has finished
        o_data		:       out     std_logic);			-- bit containing the serial data that was shifted over
        --
end uart_tx;

architecture behavior of uart_tx is

        -- define the states
        type state_type is (
		IDLE,		    -- UART idling at '1', no connection.
        START_BIT,      -- Wake up the receiver with a "0"
        DATA_BIT,       -- All the Parallel-In Serial-Out data
		STOP_BIT);	    -- Inform the receiver that we're done

        signal	current_state	: state_type	        := IDLE;			        -- declares a current state and places its default value at IDLE.
        signal  r_count         : natural range 0 to MAX_COUNT-1 := 0;           -- clocks spent in the current bit
        signal	baud_tick	    : std_logic		        := '0';				        -- '1' on the last clock of every bit period
    	signal  r_shift_reg	    : std_logic_vector(7 downto 0) := (others => '0');	-- shifting data one by one, replacing it with zeros after it's shifted
    	signal  r_bit_index	    : integer range 0 to 7	:= 0;				        -- the current bit of to be outputted to o_data
        signal  r_done          : std_logic             := '0';                 -- o_done, readable here (VHDL-93 can't read an out port)
        --

begin
	-- making the baud rate: every bit lasts exactly MAX_COUNT clocks (434 at 50 MHz / 115,200).
	-- the divider sits at 0 while IDLE and starts counting the moment a frame starts, so the
	-- start bit is a full bit long no matter when i_go arrived.
        process (i_clk, i_reset)
        begin
                if (i_reset = '0') then
                        r_count         <= 0;

                elsif rising_edge(i_clk) then
                        if (current_state = IDLE) or (r_count = MAX_COUNT-1) then
                                r_count         <= 0;
                        else
                                r_count         <= r_count + 1;
                        end if;
                end if;

        end process;

        baud_tick <= '1' when (r_count = MAX_COUNT-1) else '0';
        --

        process (i_clk, i_reset)
        begin
		-- state machine that goes through idling, beginning data sending, sending data, being done, back to idling.
                if (i_reset = '0') then
                        current_state   <= IDLE;
                        o_data          <= '1';
                        r_done          <= '0';
                        r_shift_reg     <= (others => '0');
                        r_bit_index     <= 0;

                elsif rising_edge(i_clk) then
                        r_done  <= '0';     -- a one clock pulse, raised only by STOP_BIT below

                        case current_state is

                				-- checked on every clock, not just on baud ticks, so even a one clock
                				-- i_go pulse is caught. load the data and start the start bit right away.
                				-- not on the clock right after o_done, though: that is the clock a client
                				-- reacting to o_done puts its next byte on i_data, so waiting one clock
                				-- means it's the NEW byte that gets latched. holding i_go low streams.
                                when IDLE =>
                					o_data	<= '1';
                					if (i_go = '0') and (r_done = '0') then
                						r_shift_reg	<= i_data;
                						r_bit_index	<= 0;
                						o_data		<= '0';             -- the start bit begins now
                						current_state	<= START_BIT;
                                    end if;
                				--

                				-- the start bit has been on the line for a full bit; put out bit 0
                				when START_BIT =>
                					if baud_tick = '1' then
                						o_data		<= r_shift_reg(0);		            -- the right-most index of the shift reg goes first (LSB first)
                						r_shift_reg	<= '0' & r_shift_reg(7 downto 1);	-- then keep shoving data to the right most index by plugging in 0's
                						current_state	<= DATA_BIT;
                					end if;
                				--

                				-- shifting serial data to the output, one bit per baud tick
                                when DATA_BIT =>
                					if baud_tick = '1' then
                						if r_bit_index	< 7 then
                							o_data		<= r_shift_reg(0);
                							r_shift_reg	<= '0' & r_shift_reg(7 downto 1);
                							r_bit_index   <= r_bit_index + 1;		-- if this has been done 8 times, stop (since it's an 8 bit register)
                						else
                							o_data		<= '1';                 -- bit 7 is done: raise the line for the stop bit
                							current_state	<= STOP_BIT;
                						end if;
                					end if;
                                --

                				-- once the stop bit has been held for a full bit, say we're done and go back to idling.
                				when STOP_BIT =>
                					if baud_tick = '1' then
                						r_done		<= '1';
                						current_state	<= IDLE;
                					end if;
                                --

                				-- edge case handling
                                when others =>
                                    current_state	<= IDLE;
                				--
                        end case;
                end if;
                --
        end process;
        o_done <= r_done;
end behavior;
