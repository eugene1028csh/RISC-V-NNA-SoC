
library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity soc_top_fault_tb is
end entity;

architecture sim of soc_top_fault_tb is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';
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
        reset <= '0';

        
        -- Wait for simulated CPU DFT tests
        wait until led_n(3) = '0' for 1 us;

        assert led_n(1) = '0' and
               led_n(2) = '0' and
               led_n(3) = '0'
            report "CPU DFT READY TIMEOUT"
            severity failure;

        report "PASS: CPU SELF-TESTS COMPLETE";

        -- Allow sufficient time for NNA BIST to finish
        wait for 2 us;

        -- Faulty NNA must not receive a PASS
        assert led_n(4) = '1'
            report "FAULTY NNA INCORRECTLY PASSED BIST"
            severity failure;

        -- Application must not report success
        assert led_n(5) = '1'
            report "APPLICATION INCORRECTLY REPORTED PASS"
            severity failure;

        -- Check again after additional clock cycles
        for i in 0 to 20 loop
            wait until rising_edge(clk);
        end loop;

        assert led_n(4) = '1'
            report "NNA BOOT PERMISSION INCORRECTLY ASSERTED"
            severity failure;

        report "PASS: NNA BIST DID NOT PASS";
        report "PASS: APPLICATION DID NOT REPORT SUCCESS";
        report "PASS: SOC NEGATIVE DFT TEST VERIFIED";

        stop;
        wait;
    end process;

end architecture;
