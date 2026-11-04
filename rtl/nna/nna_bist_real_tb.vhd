
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity nna_bist_real_tb is
end entity;

architecture sim of nna_bist_real_tb is

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';
    signal start : std_logic := '0';

    signal busy, done, pass, fail : std_logic;

    signal bus_addr       : std_logic_vector(31 downto 0);
    signal bus_write_data : std_logic_vector(31 downto 0);
    signal bus_write_en   : std_logic;
    signal bus_read_data  : std_logic_vector(31 downto 0);
    signal bus_hit        : std_logic;

    signal nna_read_data : std_logic_vector(31 downto 0);
    signal inject_fault  : std_logic := '0';

begin

    clk <= not clk after 5 ns;

    -- Corrupt NNA output 7 during fault-injection test
    bus_read_data <= nna_read_data xor x"00000001"
        when inject_fault = '1'
        and bus_addr = x"400000DC"
        else nna_read_data;

    -- NNA BIST controller: MMIO master
    bist_inst : entity work.nna_bist_ctrl
        port map (
            clk => clk,
            reset => reset,
            start => start,

            busy => busy,
            done => done,
            pass => pass,
            fail => fail,

            bus_addr => bus_addr,
            bus_write_data => bus_write_data,
            bus_write_en => bus_write_en,
            bus_read_data => bus_read_data,
            bus_hit => bus_hit
        );

    -- REAL NNA: MMIO slave
    nna_inst : entity work.nna_mmio_wrapper
        port map (
            clk => clk,
            reset => reset,

            bus_addr => bus_addr,
            bus_write_data => bus_write_data,
            bus_write_en => bus_write_en,

            bus_read_data => nna_read_data,
            bus_hit => bus_hit
        );

    process
    begin
        -- Reset both modules
        wait until falling_edge(clk);
        reset <= '0';

        -- Start BIST
        wait until falling_edge(clk);
        start <= '1';

        wait until falling_edge(clk);
        start <= '0';

        report "NNA BIST STARTED";

        -- Wait for completion, with timeout
        wait until done = '1' for 100 us;

        assert done = '1'
            report "FAIL: NNA BIST TIMEOUT"
            severity failure;

        assert pass = '1'
            report "FAIL: REAL NNA OUTPUT MISMATCH"
            severity failure;

        assert fail = '0'
            report "FAIL: NNA BIST ASSERTED FAIL"
            severity failure;

            
    report "PASS: REAL NNA BIST VERIFIED";

    -- Wait until S_FINISH returns to S_IDLE
    wait until done = '0';

    -- Enable fault injection for the second run
    wait until falling_edge(clk);
    inject_fault <= '1';
    start <= '1';

    wait until falling_edge(clk);
    start <= '0';

    report "FAULTY NNA BIST STARTED";

    -- Wait for the second BIST to complete
    wait until done = '1' for 100 us;

    assert done = '1'
        report "FAIL: FAULTY NNA BIST TIMEOUT"
        severity failure;

    assert fail = '1'
        report "FAIL: INJECTED NNA FAULT NOT DETECTED"
        severity failure;

    assert pass = '0'
        report "FAIL: FAULTY NNA INCORRECTLY PASSED"
        severity failure;

    report "PASS: REAL NNA OUTPUT FAULT DETECTED";
    report "PASS: HEALTHY AND FAULTY NNA TESTS VERIFIED";

    stop;
    wait;

    end process;

end architecture;
