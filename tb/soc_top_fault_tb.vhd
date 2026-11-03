
library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity soc_top_fault_tb is
end entity;

architecture sim of soc_top_fault_tb is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '0';
    signal led_n : std_logic_vector(5 downto 0);

begin

    clk <= not clk after 5 ns;

    dut : entity work.soc_top
        generic map (
            SIM_INJECT_NNA_FAULT => true
        )
        port map (
            clk   => clk,
            reset => reset,
            led_n => led_n
        );

    process
    begin
        -- External reset is active LOW
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        reset <= '1';

        -- Wait for simulated CPU self-tests
        wait until led_n(4) = '0' for 1 us;

        assert led_n(4) = '0'
            report "CPU DFT READY TIMEOUT"
            severity failure;

        report "PASS: CPU SELF-TEST STUB READY";

        -- Wait for NNA BIST failure to be latched
        wait until led_n(5) = '0' for 10 us;

        assert led_n(5) = '0'
            report "NNA FAULT WAS NOT LATCHED"
            severity failure;

        report "PASS: NNA BIST FAULT LATCHED";

        -- CPU must not reach its post-boot NNA read
        assert led_n(3) = '1'
            report "CPU ACCESSED NNA DESPITE BIST FAILURE"
            severity failure;

        -- Check again after additional clock cycles
        for i in 0 to 20 loop
            wait until rising_edge(clk);
        end loop;

        assert led_n(3) = '1'
            report "CPU WAS RELEASED AFTER NNA BIST FAILURE"
            severity failure;

        assert led_n(0) = '1'
            report "SYSTEM INCORRECTLY REPORTED PASS"
            severity failure;

        report "PASS: CPU BOOT BLOCKED AFTER NNA FAULT";
        report "PASS: SOC NEGATIVE BOOT TEST VERIFIED";

        stop;
        wait;
    end process;

end architecture;
