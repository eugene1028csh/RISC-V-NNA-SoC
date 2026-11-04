library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity soc_top_boot_tb is
end entity;

architecture sim of soc_top_boot_tb is
    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';
    signal led_n : std_logic_vector(5 downto 0);
begin

    clk <= not clk after 5 ns;

    dut : entity work.soc_top
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

        
        -- Wait for simulated CPU DFT tests to complete
        wait until led_n(3) = '0' for 1 us;

        assert led_n(1) = '0' and
               led_n(2) = '0' and
               led_n(3) = '0'
            report "CPU SELF-TESTS DID NOT PASS"
            severity failure;

        -- NNA BIST should still be pending
        assert led_n(4) = '1'
            report "NNA BIST PASSED TOO EARLY"
            severity failure;

        report "PASS: CPU SELF-TESTS COMPLETE";

        -- Wait for NNA BIST to pass
        wait until led_n(4) = '0' for 10 us;

        assert led_n(4) = '0'
            report "NNA BIST DID NOT PASS"
            severity failure;

        report "PASS: NNA BIST COMPLETED";
        report "PASS: NNA BOOT PERMISSION ASSERTED";

        -- Allow registered status and CPU boot release to settle
        for i in 0 to 2 loop
            wait until rising_edge(clk);
        end loop;

        -- Keep simulation running to show stable final DFT status
        wait for 100 ns;
        stop;
        wait;
    end process;

end architecture;
