library ieee;
use ieee.std_logic_1164.all;

entity uart_tx is
	-- definitions
        generic (
        MAX_COUNT   :       natural := 434);		    -- make it count to 434 as the result of 50 million over 155,200

        Port (
        i_clk		:	    in      std_logic;			-- clock lmao
        i_reset		:       in      std_logic;			-- reset button
        i_go		:       in      std_logic;			-- go button
	    i_data		:	    in	std_logic_vector(7 downto 0);	-- 8 bit register containing the data to be shifted PISO style

        o_done		:       out     std_logic;			-- market indicating we're done
        o_data		:       out     std_logic);			-- bit containing the serial data that was shifted over
        --
end uart_tx;

architecture behavior of uart_tx is

        -- define the states
        type state_type is (
		IDLE,		    -- UART idling at '1', no connection. 
        START_BIT,      -- Wake up the receiver with a "0"
        DATA_BIT,       -- All the Parallel-In Serial-Out data
		STOP_BIT);	    -- Inform the receiver that we're donne

        signal	current_state	: state_type	        := IDLE;			        -- declares a current state and places its default value at IDLE.
        signal	baud_tick	    : std_logic		        := '0';				        -- tick at the predetermined ratio, 50m/115.2k
    	signal  r_shift_reg	    : std_logic_vector(7 downto 0) := (others => '0');	-- shifting data one by one, replacing it with zeros after it's shifted
    	signal  r_bit_index	    : integer range 0 to 7	:= 0;				        -- the current bit of to be outputted to o_data
        --

begin
	-- making the baud rate, it's only 1 after "wasting" 433 cycles per the standard.
        process (i_clk)
        variable count : natural range 0 to MAX_COUNT := 0;
        begin
                if rising_edge(i_clk) then
                        if count < (MAX_COUNT-1) then
                                count           := count + 1;
                                baud_tick	<= '0';
                        else
                                count           := 0;
                                baud_tick       <= '1';
                        end if;
                end if;

        end process;
        --

        process (i_clk, i_reset)
        begin
		-- state machine that goes through idling, beginning data sending, sending data, being done, back to idling.
                if (i_reset = '0') then
                        current_state   <= IDLE;
                        o_data          <= '1';

                elsif rising_edge(i_clk) then
                        if baud_tick = '1' then
                                case current_state is

                					-- data line is still 1 (no data), set done to 0 (not done). If go is pressed, load the entire data reg to the shift reg and set index to 0
                                        when IDLE =>
                						o_data	<= '1';
                						o_done	<= '0';
                						if i_go	= '0' then
                							r_shift_reg	<= i_data;
                							r_bit_index	<= 0;
                							current_state	<= START_BIT;
                                        end if;
                					--

                					-- begin prepping by putting data to 0; exclaiming there's transmission
                					when START_BIT =>
                						o_data		<= '0';
                						current_state	<= DATA_BIT;
                					--

                					-- shifting serial data to the output
                                    when DATA_BIT =>
                            			o_data		<= r_shift_reg(0);		            -- set the data output to the right-most index of the shift reg
                						r_shift_reg	<= '0' & r_shift_reg(7 downto 1);	-- then keep shoving data to the right most index by plugging in 0's
                
                						if r_bit_index	< 7 then
                							r_bit_index   <= r_bit_index + 1;		-- if this has been done 8 times, stop (since it's an 8 bit register)
                						else
                							current_state	<= STOP_BIT;
                						end if;
                                    --

                					-- once ordered to stop, just raise up the barriers by setting data back to 1, and exclaminig "DONE".	
                					when STOP_BIT =>
                						o_data		<= '1';
                						o_done		<= '1';
                						current_state	<= IDLE;
                                    --
					
                					-- edge case handling
                                    when others =>
                                        current_state	<= IDLE;
                					-- 
                                end case;
                        end if;
                end if;
                --
        end process;
end behavior;

