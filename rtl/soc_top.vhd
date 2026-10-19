library ieee;
use ieee.std_logic_1164.all;

entity soc_top is
    port(
        clk            : in  std_logic;
        reset          : in  std_logic;

        activity_led_n : out std_logic;
        pass_led_n     : out std_logic
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
    signal reset_i : std_logic; --internal active hig reest seignal

    

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
    reset_i <= not reset;

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
                                end if;

                            when x"400000C4" =>
                                if bus_read_data = x"0000000A" then
                                    out1_ok <= '1';
                                end if;

                            when x"400000C8" =>
                                if bus_read_data = x"00000073" then
                                    out2_ok <= '1';
                                end if;

                            when x"400000CC" =>
                                if bus_read_data = x"00000000" then
                                    out3_ok <= '1';
                                end if;

                            when others =>
                                null;

                        end case;

                    end if;

                end if;

            end if;
        end process;


        pass_led_n <= not (
            seen_done
            and out0_ok
            and out1_ok
            and out2_ok
            and out3_ok
        );

        activity_led_n <= not bus_hit;

end architecture;