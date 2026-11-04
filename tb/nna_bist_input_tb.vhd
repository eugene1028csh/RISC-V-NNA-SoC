
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity nna_bist_input_tb is
end entity;

architecture sim of nna_bist_input_tb is
    signal clk, reset, start : std_logic := '0';
    signal busy, done, pass, fail : std_logic;
    signal bus_addr, bus_write_data, bus_read_data :
        std_logic_vector(31 downto 0);
    signal bus_write_en : std_logic;
    signal mock_nna_done : std_logic := '0';
    signal inject_mock_fault : std_logic := '0';
begin
    clk <= not clk after 5 ns;

    dut : entity work.nna_bist_ctrl
        port map (
            clk => clk, reset => reset, start => start,
            busy => busy, done => done,
            pass => pass, fail => fail,
            bus_addr => bus_addr,
            bus_write_data => bus_write_data,
            bus_write_en => bus_write_en,
            bus_read_data => bus_read_data,
            bus_hit => '1'
        );

            
    -- Mock NNA status and output registers
    process(all)
        variable output_index : integer;
    begin
        bus_read_data <= (others => '0');

        if bus_addr = x"40000004" and mock_nna_done = '1' then

            bus_read_data <= x"00000001";

        elsif bus_addr(31 downto 8) = x"400000"
        and unsigned(bus_addr(7 downto 0)) >= to_unsigned(16#C0#, 8)
        and unsigned(bus_addr(7 downto 0)) <= to_unsigned(16#FC#, 8)
        and bus_addr(1 downto 0) = "00" then

            output_index :=
                (to_integer(unsigned(bus_addr(7 downto 0)))
                - 16#C0#) / 4;

            -- Mock output values: 1, 2, ... 16
            if inject_mock_fault = '1' and output_index = 7 then
                -- Expected output = 8, injected faulty output = 9
                bus_read_data <= x"00000009";
            else
                bus_read_data <= std_logic_vector(
                    to_unsigned(output_index + 1, 32)
                );
            end if;

        end if;
    end process;

    process
    begin
        reset <= '1';
        wait until falling_edge(clk);
        reset <= '0';
        start <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';

        for i in 0 to 15 loop
            assert bus_write_en = '1'
                report "Write enable missing" severity failure;

            assert bus_addr = std_logic_vector(
                to_unsigned(16#40000010# + i * 4, 32))
                report "Incorrect MMIO address" severity failure;

            if (i / 4) = (i mod 4) then
                assert bus_write_data = x"00000001"
                    report "Incorrect diagonal value" severity failure;
            else
                assert bus_write_data = x"00000000"
                    report "Incorrect zero value" severity failure;
            end if;

            wait until rising_edge(clk);
            wait for 1 ns;
        end loop;

        report "PASS: ALL 16 INPUT WRITES VERIFIED";

        -- Verify all 16 weight writes
        for i in 0 to 15 loop

            assert bus_write_en = '1'
                report "Weight write enable missing"
                severity failure;

            assert bus_addr = std_logic_vector(
                to_unsigned(16#40000050# + i * 4, 32))
                report "Incorrect weight MMIO address"
                severity failure;

            assert bus_write_data = std_logic_vector(
                to_unsigned(i + 1, 32))
                report "Incorrect weight value"
                severity failure;

            wait until rising_edge(clk);
            wait for 1 ns;

        end loop;

        report "PASS: ALL 16 WEIGHT WRITES VERIFIED";

        -- Verify all 4 bias writes
        for i in 0 to 3 loop

            assert bus_write_en = '1'
                report "Bias write enable missing"
                severity failure;

            assert bus_addr = std_logic_vector(
                to_unsigned(16#40000090# + i * 4, 32))
                report "Incorrect bias MMIO address"
                severity failure;

            assert bus_write_data = x"00000000"
                report "Incorrect bias value"
                severity failure;

            wait until rising_edge(clk);
            wait for 1 ns;

        end loop;

        report "PASS: ALL 4 BIAS WRITES VERIFIED";

                
        -- Verify the one-cycle START command
        assert bus_addr = x"40000000"
            report "Incorrect NNA START address"
            severity failure;

        assert bus_write_en = '1'
            report "NNA START write enable missing"
            severity failure;

        assert bus_write_data = x"00000001"
            report "Incorrect NNA START value"
            severity failure;

        report "PASS: NNA START COMMAND VERIFIED";

        wait until rising_edge(clk);
        wait for 1 ns;

        -- Simulate NNA still processing for five clock cycles
        for i in 0 to 4 loop
            assert bus_addr = x"40000004"
                report "Incorrect NNA STATUS address"
                severity failure;

            assert bus_write_en = '0'
                report "STATUS polling must not write"
                severity failure;

            assert busy = '1' and done = '0'
                report "BIST should still be waiting"
                severity failure;

            wait until rising_edge(clk);
            wait for 1 ns;
        end loop;

        report "PASS: NNA WAIT/DONE POLLING VERIFIED";

        -- Mock the accelerator finishing its operation
        mock_nna_done <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        -- Controller should now move to the first output register
        assert bus_addr = x"400000C0"
            report "BIST did not enter output-reading phase"
            severity failure;

        assert bus_write_en = '0'
            report "Output reading must not write"
            severity failure;

        report "PASS: NNA DONE DETECTED";
       
        -- Verify all 16 output reads
        for i in 0 to 15 loop

            assert bus_addr = std_logic_vector(
                to_unsigned(16#400000C0# + i * 4, 32)
            )
                report "Incorrect NNA output address"
                severity failure;

            assert bus_write_en = '0'
                report "Output reading must not write"
                severity failure;

            assert bus_read_data = std_logic_vector(
                to_unsigned(i + 1, 32)
            )
                report "Incorrect mock NNA output"
                severity failure;

            wait until rising_edge(clk);
            wait for 1 ns;

        end loop;

        report "PASS: ALL 16 OUTPUT REGISTERS READ";

        -- Check BIST completion
        assert done = '1'
            report "BIST completion signal missing"
            severity failure;

        assert pass = '1'
            report "BIST failed despite correct outputs"
            severity failure;

        assert fail = '0'
            report "Unexpected BIST failure"
            severity failure;

        
        report "PASS: NNA BIST OUTPUT CHECK COMPLETED";
        report "PASS: HEALTHY NNA TEST PASSED";

        -- Allow S_FINISH to return to S_IDLE
        wait until rising_edge(clk);
        wait for 1 ns;

        -- Prepare a second test with an injected fault
        mock_nna_done <= '0';
        inject_mock_fault <= '1';

        -- Restart the BIST controller
        wait until falling_edge(clk);
        start <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;
        start <= '0';

        -- Wait for the controller to finish writing test vectors
        -- and reach the NNA status polling register
        for cycle in 0 to 45 loop
            exit when bus_addr = x"40000004";

            wait until rising_edge(clk);
            wait for 1 ns;
        end loop;

        assert bus_addr = x"40000004"
            report "Second BIST did not reach STATUS polling"
            severity failure;

        -- Simulate NNA completion
        mock_nna_done <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        assert bus_addr = x"400000C0"
            report "Second BIST did not begin output checking"
            severity failure;

        -- Allow controller to inspect all 16 outputs
        for i in 0 to 15 loop
            wait until rising_edge(clk);
            wait for 1 ns;
        end loop;

        -- Faulty output 7 should cause BIST failure
        assert done = '1'
            report "Faulty BIST did not finish"
            severity failure;

        assert fail = '1'
            report "INJECTED FAULT WAS NOT DETECTED"
            severity failure;

        assert pass = '0'
            report "Faulty NNA incorrectly passed BIST"
            severity failure;

        report "PASS: INJECTED NNA OUTPUT FAULT DETECTED";
        report "PASS: BOTH HEALTHY AND FAULTY BIST CASES VERIFIED";

        stop;
        wait;


    end process;
end architecture;
