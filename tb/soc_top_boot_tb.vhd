library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity soc_top_boot_tb is
end entity;

architecture sim of soc_top_boot_tb is
    signal clk   : std_logic := '0';
    signal reset : std_logic := '0';
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
        reset <= '1';

        -- Verify simulated CPU self-tests finished
        wait until led_n(4) = '0' for 1 us;

        assert led_n(4) = '0'
            report "MBIST status never passed"
            severity failure;

        assert led_n(3) = '1'
            report "CPU accessed NNA before BIST finished"
            severity failure;

        report "PASS: CPU HELD DURING NNA BIST";

        -- Wait for NNA BIST to finish and CPU-side
        -- MMIO STATUS polling to become visible.
        wait until led_n(3) = '0' for 10 us;

        assert led_n(3) = '0'
            report "CPU WAS NOT RELEASED AFTER NNA BIST"
            severity failure;

        assert led_n(5) = '1'
            report "Unexpected SoC fault"
            severity failure;

        report "PASS: NNA BIST COMPLETED";
        report "PASS: CPU RELEASED AFTER NNA BIST";
        report "PASS: SOC BOOT HANDSHAKE VERIFIED";

        stop;
        wait;
    end process;

end architecture;
