library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity soc_top is
    port(
        clk            : in  std_logic;
        reset          : in  std_logic;

        led_n : out std_logic_vector(5 downto 0)
    );
end entity;

architecture rtl of soc_top is

    signal bus_addr       : std_logic_vector(31 downto 0);
    signal bus_write_data : std_logic_vector(31 downto 0);
    signal bus_write_en   : std_logic;

    signal bus_read_data  : std_logic_vector(31 downto 0);
    signal bus_hit        : std_logic;

    signal seen_done : std_logic := '0';

    signal out0_ok : std_logic := '0';
    signal out1_ok : std_logic := '0';
    signal out2_ok : std_logic := '0';
    signal out3_ok : std_logic := '0';
    signal reset_i : std_logic; --internal active high reest seignal

    signal heartbeat_counter : unsigned(23 downto 0) := (others => '0');
    --24 bits because, when divided the clk frequency 27Hz, each bit flashes at 27/2^24 = 1.61 Hz, which is visible
    signal mmio_counter : unsigned(21 downto 0) := (others => '0');
    signal system_pass : std_logic;
    signal error_latched : std_logic := '0';


    component rv32i_core is
        port(
            clk            : in  std_logic;
            reset          : in  std_logic;

            bus_addr       : out std_logic_vector(31 downto 0);
            bus_write_data : out std_logic_vector(31 downto 0);
            bus_write_en   : out std_logic;

            bus_read_data  : in  std_logic_vector(31 downto 0);
            bus_hit        : in  std_logic
        );
    end component;

begin
    reset_i <= reset;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset_i = '1' then
                error_latched <= '0';
            end if;
        end if;
    end process;

    cpu_inst : rv32i_core
        port map(
            clk            => clk,
            reset          => reset_i,

            bus_addr       => bus_addr,
            bus_write_data => bus_write_data,
            bus_write_en   => bus_write_en,

            bus_read_data  => bus_read_data,
            bus_hit        => bus_hit
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

        process(clk)
        begin
            if rising_edge(clk) then

                if reset_i = '1' then

                    seen_done <= '0';

                    out0_ok <= '0';
                    out1_ok <= '0';
                    out2_ok <= '0';
                    out3_ok <= '0';

                else

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
                                if bus_read_data = x"00000000" then
                                    out0_ok <= '1';
                                else
                                    error_latched <= '1';
                                end if;

                            when x"400000C4" =>
                                if bus_read_data = x"0000000A" then
                                    out1_ok <= '1';
                                else
                                    error_latched <= '1';
                                end if;

                            when x"400000C8" =>
                                if bus_read_data = x"00000073" then
                                    out2_ok <= '1';
                                else
                                    error_latched <= '1';
                                end if;

                            when x"400000CC" =>
                                if bus_read_data = x"00000000" then
                                    out3_ok <= '1';
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

        system_pass <= (
            seen_done
            and out0_ok
            and out1_ok
            and out2_ok
            and out3_ok
        );               
        
        led_n(0) <= not system_pass;
        led_n(1) <= not heartbeat_counter(23);
        led_n(2) <= '0' when mmio_counter /= 0 else '1';
        led_n(3) <= not seen_done;
        led_n(4) <= '1';  -- MBIST not implemented yet
        led_n(5) <= not error_latched;


end architecture;