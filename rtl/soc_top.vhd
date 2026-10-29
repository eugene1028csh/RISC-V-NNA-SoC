library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity soc_top is
    port(
        clk            : in  std_logic;
        reset          : in  std_logic;

        led_n : out std_logic_vector(5 downto 0) --_n means active low
    );
end entity;

architecture rtl of soc_top is

    signal bus_addr       : std_logic_vector(31 downto 0);
    signal bus_write_data : std_logic_vector(31 downto 0);
    signal bus_write_en   : std_logic;

    signal bus_read_data  : std_logic_vector(31 downto 0);
    signal bus_hit        : std_logic;

    signal seen_done : std_logic := '0';
    signal out_ok : std_logic_vector(15 downto 0) := (others => '0');
    signal reset_i : std_logic; --internal active high reest seignal

    signal heartbeat_counter : unsigned(23 downto 0) := (others => '0');
    -- 24-bit counter: bit 23 toggles at  abt 1.61 Hz from the 27 MHz clock
    signal mmio_counter : unsigned(21 downto 0) := (others => '0');
    signal system_pass : std_logic;
    signal error_latched : std_logic := '0';

    signal mbist_pass : std_logic;
    signal mbist_fail : std_logic;

    signal debug_value : std_logic_vector(31 downto 0) := (others => '0');


    component rv32i_core is
        port(
            clk            : in  std_logic;
            reset          : in  std_logic;

            bus_addr       : out std_logic_vector(31 downto 0);
            bus_write_data : out std_logic_vector(31 downto 0);
            bus_write_en   : out std_logic;

            bus_read_data  : in  std_logic_vector(31 downto 0);
            bus_hit        : in  std_logic;

            mbist_pass_o   : out std_logic;
            mbist_fail_o   : out std_logic
        );
    end component;

begin
    reset_i <= not reset;

    cpu_inst : rv32i_core
        port map(
            clk            => clk,
            reset          => reset_i,

            bus_addr       => bus_addr,
            bus_write_data => bus_write_data,
            bus_write_en   => bus_write_en,

            bus_read_data  => bus_read_data,
            bus_hit        => bus_hit,

            mbist_pass_o   => mbist_pass,
            mbist_fail_o   => mbist_fail
        );

    nna_inst : entity work.nna_mmio_wrapper
        port map(
            clk            => clk,
            reset          => reset_i,

            bus_addr       => bus_addr,
            bus_write_data => bus_write_data,
            bus_write_en   => bus_write_en,

            bus_read_data  => bus_read_data,
            bus_hit        => bus_hit
        );

        --heartbeat counter
        process(clk)
        begin
            if rising_edge(clk) then
                if reset_i = '1' then
                    heartbeat_counter <= (others => '0');
                else
                    heartbeat_counter <= heartbeat_counter + 1;
                end if;
            end if;
        end process;

        --mmio counter with pulse stretching
        --duration of blink lasts about 100ms 2700000/27000000 = 0.1s, 
        -- 1st elsif loads 2700000 and then 2nd elsif eventually follows, counting down to 0, at that point the LED turns off
        process(clk)
        begin
            if rising_edge(clk) then
                if reset_i = '1' then
                    mmio_counter <= (others => '0');
                elsif bus_hit = '1' then
                    mmio_counter <= to_unsigned(2700000, mmio_counter'length);
                    --pulse stretched, load counter with 2700000 in binary accoridng to mmio_counter bit length
                elsif mmio_counter /= 0 then
                    --  /= means not equal to
                    mmio_counter <= mmio_counter -1;
                    --one decrement per 27 MHz
                end if;
            end if;
        end process;

        process(clk)
        begin
            if rising_edge(clk) then

                if reset_i = '1' then

                    seen_done <= '0';

                    out_ok <= (others => '0');

                    error_latched <= '0';

                else

                    if bus_hit = '1'
                    and bus_write_en = '0'
                    and bus_addr = x"400000EC" then
                        debug_value <= bus_read_data;
                    end if;

                    -- CPU read STATUS = DONE
                    if bus_hit = '1'
                    and bus_write_en = '0'
                    and bus_addr = x"40000004"
                    and bus_read_data(0) = '1' then

                        seen_done <= '1';

                    end if;


                    -- Only accept outputs after NNA has completed
                    if seen_done = '1'
                    and bus_hit = '1'
                    and bus_write_en = '0' then

                       case bus_addr is
                            when x"400000C0" =>
                                if bus_read_data = x"00000050" then -- 80
                                    out_ok(0) <= '1';
                                else
                                    error_latched <= '1';
                                end if;

                            when x"400000C4" =>
                                if bus_read_data = x"00000046" then -- 70
                                    out_ok(1) <= '1';
                                else
                                    error_latched <= '1';
                                end if;

                            when x"400000C8" =>
                                if bus_read_data = x"0000003C" then -- 60
                                    out_ok(2) <= '1';
                                else
                                    error_latched <= '1';
                                end if;

                            when x"400000CC" =>
                                if bus_read_data = x"00000032" then -- 50
                                    out_ok(3) <= '1';
                                else
                                    error_latched <= '1';
                                end if;


                            when x"400000D0" =>
                                if bus_read_data = x"000000F0" then -- 240
                                    out_ok(4) <= '1';
                                else
                                    error_latched <= '1';
                                end if;

                            when x"400000D4" =>
                                if bus_read_data = x"000000D6" then -- 214
                                    out_ok(5) <= '1';
                                else
                                    error_latched <= '1';
                                end if;

                            when x"400000D8" =>
                                if bus_read_data = x"000000BC" then -- 188
                                    out_ok(6) <= '1';
                                else
                                    error_latched <= '1';
                                end if;

                            when x"400000DC" =>
                                if bus_read_data = x"000000A2" then -- 162
                                    out_ok(7) <= '1';
                                else
                                    error_latched <= '1';
                                end if;


                            when x"400000E0" =>
                                if bus_read_data = x"00000190" then -- 400
                                    out_ok(8) <= '1';
                                else
                                    error_latched <= '1';
                                end if;

                            when x"400000E4" =>
                                if bus_read_data = x"00000166" then -- 358
                                    out_ok(9) <= '1';
                                else
                                    error_latched <= '1';
                                end if;

                            when x"400000E8" =>
                                if bus_read_data = x"0000013C" then -- 316
                                    out_ok(10) <= '1';
                                else
                                    error_latched <= '1';
                                end if;

                            when x"400000EC" =>
                                if bus_read_data = x"00000112" then -- 274
                                    out_ok(11) <= '1';
                                else
                                    error_latched <= '1';
                                end if;


                            when x"400000F0" =>
                                if bus_read_data = x"00000230" then -- 560
                                    out_ok(12) <= '1';
                                else
                                    error_latched <= '1';
                                end if;

                            when x"400000F4" =>
                                if bus_read_data = x"000001F6" then -- 502
                                    out_ok(13) <= '1';
                                else
                                    error_latched <= '1';
                                end if;

                            when x"400000F8" =>
                                if bus_read_data = x"000001BC" then -- 444
                                    out_ok(14) <= '1';
                                else
                                    error_latched <= '1';
                                end if;

                            when x"400000FC" =>
                                if bus_read_data = x"00000182" then -- 386
                                    out_ok(15) <= '1';
                                else
                                    error_latched <= '1';
                                end if;

                            when others =>
                                null;

                        end case;
                    end if;

                end if;

            end if;
        end process;

       system_pass <= '1'
            when mbist_pass = '1'
            and seen_done = '1'
            and out_ok = x"FFFF"
            and error_latched = '0'
            and mbist_fail = '0'
            else '0';
        
        led_n(0) <= not debug_value(6);
        led_n(1) <= not debug_value(7);
        led_n(2) <= not debug_value(8);
        led_n(3) <= not debug_value(9);
        led_n(4) <= not debug_value(10);
        led_n(5) <= not debug_value(11);


end architecture;