library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity nna_mmio_wrapper_tb is
end entity;

architecture sim of nna_mmio_wrapper_tb is

    signal clk : std_logic := '0';
    signal reset : std_logic := '0';

    signal bus_addr       : std_logic_vector(31 downto 0) := (others => '0');
    signal bus_write_data : std_logic_vector(31 downto 0) := (others => '0');
    signal bus_write_en   : std_logic := '0';

    signal bus_read_data  : std_logic_vector(31 downto 0);
    signal bus_hit        : std_logic;

    procedure mmio_write(
            signal clk_s        : in  std_logic;
            signal addr_s       : out std_logic_vector(31 downto 0);
            signal write_data_s : out std_logic_vector(31 downto 0);
            signal write_en_s   : out std_logic;
            constant addr       : in  std_logic_vector(31 downto 0);
            constant data       : in  std_logic_vector(31 downto 0)
        ) is
        begin
            addr_s <= addr;
            write_data_s <= data;

            write_en_s <= '1';
            wait until rising_edge(clk_s);
            write_en_s <= '0';

        end procedure;

begin

    clk <= not clk after 5 ns;

    dut : entity work.nna_mmio_wrapper
        port map (
            clk            => clk,
            reset          => reset,
            bus_addr       => bus_addr,
            bus_write_data => bus_write_data,
            bus_write_en   => bus_write_en,
            bus_read_data  => bus_read_data,
            bus_hit        => bus_hit
        );
    
        
    stimulus : process
    begin
        reset <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        reset <= '0';

        --inputs
        mmio_write(clk, bus_addr, bus_write_data, bus_write_en,
           x"40000010", x"00000001");

        mmio_write(clk, bus_addr, bus_write_data, bus_write_en,
                x"40000014", x"00000002");

        mmio_write(clk, bus_addr, bus_write_data, bus_write_en,
                x"40000018", x"00000003");

        mmio_write(clk, bus_addr, bus_write_data, bus_write_en,
                x"4000001C", x"00000004");

        for i in 0 to 15 loop
            mmio_write(
                clk,
                bus_addr,
                bus_write_data,
                bus_write_en,
                std_logic_vector(to_unsigned(16#40000040# + (i * 4), 32)), --vhdl syntax for the number 40000040, written in base 16.
                std_logic_vector(to_signed(i + 1, 32))
            );
        end loop;

        --bias
        mmio_write(clk, bus_addr, bus_write_data, bus_write_en,
           x"40000080", std_logic_vector(to_signed(-40, 32))); --BIAS0 = -40

        mmio_write(clk, bus_addr, bus_write_data, bus_write_en,
                x"40000084", std_logic_vector(to_signed(-60, 32))); --BIAS1 = -60

        mmio_write(clk, bus_addr, bus_write_data, bus_write_en,
                x"40000088", std_logic_vector(to_signed(5, 32))); 

        mmio_write(clk, bus_addr, bus_write_data, bus_write_en,
                x"4000008C", std_logic_vector(to_signed(-200, 32)));

        -- START NNA
        mmio_write(
            clk,
            bus_addr,
            bus_write_data,
            bus_write_en,
            x"40000000", --CONTROL register addr
            x"00000001" --START bit = 1, wrapper generates nna_start = 1
        );
        
        --poll status register
        --checking the same status register repeatedly until some condition becomes true
        loop
            bus_addr <= x"40000004";

            wait until rising_edge(clk);
            wait for 1 ns;

            exit when bus_read_data(0) = '1';
        end loop;

        -- Read OUT0
        bus_addr <= x"400000C0";
        wait for 1 ns;

        assert signed(bus_read_data) = to_signed(0, 32)
            report "OUT0 incorrect"
            severity error;


        -- Read OUT1
        bus_addr <= x"400000C4";
        wait for 1 ns;

        assert signed(bus_read_data) = to_signed(10, 32)
            report "OUT1 incorrect"
            severity error;


        -- Read OUT2
        bus_addr <= x"400000C8";
        wait for 1 ns;

        assert signed(bus_read_data) = to_signed(115, 32)
            report "OUT2 incorrect"
            severity error;


        -- Read OUT3
        bus_addr <= x"400000CC";
        wait for 1 ns;

        assert signed(bus_read_data) = to_signed(0, 32)
            report "OUT3 incorrect"
            severity error;


        report "PASS: NNA MMIO wrapper test"
            severity note;

        wait;
        wait;
    end process;

end architecture;