library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity nna_bist_ctrl is
    port (
        clk   : in std_logic;
        reset : in std_logic;
        start : in std_logic;

        busy  : out std_logic;
        done  : out std_logic;
        pass  : out std_logic;
        fail  : out std_logic;

        -- MMIO master interface
        bus_addr       : out std_logic_vector(31 downto 0);
        bus_write_data : out std_logic_vector(31 downto 0);
        bus_write_en   : out std_logic;

        bus_read_data  : in std_logic_vector(31 downto 0);
        bus_hit        : in std_logic
    );
end entity;

architecture rtl of nna_bist_ctrl is

    type state_t is (
        S_IDLE,
        S_WRITE_INPUT,
        S_WRITE_WEIGHT,
        S_WRITE_BIAS,
        S_START,
        S_WAIT_DONE,
        S_READ_OUTPUT,
        S_FINISH
    );

    signal state : state_t := S_IDLE;
    signal index : integer range 0 to 15 := 0;
    signal mismatch_seen : std_logic := '0';

begin

    -- Sequential FSM: advances one element per clock
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= S_IDLE;
                index <= 0;
                mismatch_seen <= '0';
            else
                case state is
                    when S_IDLE =>
                        if start = '1' then
                            index <= 0;
                            state <= S_WRITE_INPUT;
                            mismatch_seen <= '0';
                        end if;

                    when S_WRITE_INPUT =>
                        if index = 15 then
                            index <= 0;
                            state <= S_WRITE_WEIGHT;
                        else
                            index <= index + 1;
                        end if;
                    when S_WRITE_WEIGHT =>
                        if index = 15 then
                            index <= 0;
                            state <= S_WRITE_BIAS;
                        else
                            index <= index + 1;
                        end if;
                    when S_WRITE_BIAS =>
                        if index = 3 then
                            index <= 0;
                            state <= S_START;
                        else
                            index <= index + 1;
                        end if;

                    when S_START =>
                        state <= S_WAIT_DONE;

                    when S_WAIT_DONE =>
                        if bus_hit = '1' and bus_read_data(0) = '1' then
                            index <= 0;
                            state <= S_READ_OUTPUT;
                        end if;
                                        
                    when S_READ_OUTPUT =>
                        if bus_hit = '1' then

                            -- Compare actual NNA output with expected value
                            if bus_read_data /= std_logic_vector(
                                to_unsigned(index + 1, 32)
                            ) then
                                mismatch_seen <= '1';
                            end if;

                            -- Advance through all 16 output registers
                            if index = 15 then
                                index <= 0;
                                state <= S_FINISH;
                            else
                                index <= index + 1;
                            end if;

                        end if;

                    when S_FINISH =>
                        state <= S_IDLE;

                    when others =>
                        null; -- Other states not implemented yet
                end case;
            end if;
        end if;
    end process;

    -- Combinational MMIO output logic
    process(all)
    begin
        bus_addr       <= (others => '0');
        bus_write_data <= (others => '0');
        bus_write_en   <= '0';

        busy <= '0';
        done <= '0';
        pass <= '0';
        fail <= '0';

        if state /= S_IDLE then
            busy <= '1';
        end if;

        if state = S_WRITE_INPUT then
            bus_write_en <= '1';

            bus_addr <= std_logic_vector(
                to_unsigned(16#40000010# + index * 4, 32)
            );

            -- Row-major 4x4 identity matrix
            if (index / 4) = (index mod 4) then
                bus_write_data <= x"00000001";
            end if;
            elsif state = S_WRITE_WEIGHT then
                bus_write_en <= '1';

                bus_addr <= std_logic_vector(
                    to_unsigned(16#40000050# + index * 4, 32)
                );

                bus_write_data <= std_logic_vector(
                    to_unsigned(index + 1, 32)
                );
            elsif state = S_WRITE_BIAS then
                bus_write_en <= '1';

                bus_addr <= std_logic_vector(
                    to_unsigned(16#40000090# + index * 4, 32)
                );

                bus_write_data <= x"00000000";
                elsif state = S_START then
                    bus_addr       <= x"40000000";
                    bus_write_data <= x"00000001";
                    bus_write_en   <= '1';

                elsif state = S_WAIT_DONE then
                    bus_addr <= x"40000004";

                elsif state = S_READ_OUTPUT then
                    bus_addr <= std_logic_vector(
                        to_unsigned(16#400000C0# + index * 4, 32)
                    );
                
        end if;
        if state = S_FINISH then
            busy <= '0';
            done <= '1';

            if mismatch_seen = '0' then
                pass <= '1';
            else
                fail <= '1';
            end if;
        end if;
    end process;


end architecture;
