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
        type int_array16_t is array (0 to 15) of integer;

        -- Matrix A, row-major:
        -- [ 1  2  3  4 ]
        -- [ 5  6  7  8 ]
        -- [ 9 10 11 12 ]
        -- [13 14 15 16 ]
        constant A_DATA : int_array16_t :=
            (1, 2, 3, 4,
            5, 6, 7, 8,
            9, 10, 11, 12,
            13, 14, 15, 16);

        -- Matrix B, row-major:
        -- [16 15 14 13]
        -- [12 11 10  9]
        -- [ 8  7  6  5]
        -- [ 4  3  2  1]
        constant B_DATA : int_array16_t :=
            (16, 15, 14, 13,
            12, 11, 10, 9,
            8, 7, 6, 5,
            4, 3, 2, 1);

        -- Expected A × B:
        -- [ 80  70  60  50]
        -- [240 214 188 162]
        -- [400 358 316 274]
        -- [560 502 444 386]
        constant EXPECTED : int_array16_t :=
            (80, 70, 60, 50,
            240, 214, 188, 162,
            400, 358, 316, 274,
            560, 502, 444, 386);

    begin
        -- Reset
        reset <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        reset <= '0';

        ----------------------------------------------------------------
        -- Matrix B -> INPUT region 0x40000010 - 0x4000004C
        ----------------------------------------------------------------
        for i in 0 to 15 loop
            mmio_write(
                clk,
                bus_addr,
                bus_write_data,
                bus_write_en,
                std_logic_vector(
                    to_unsigned(16#40000010# + (i * 4), 32)
                ),
                std_logic_vector(to_signed(B_DATA(i), 32))
            );
        end loop;

        ----------------------------------------------------------------
        -- Matrix A -> WEIGHT region 0x40000050 - 0x4000008C
        ----------------------------------------------------------------
        for i in 0 to 15 loop
            mmio_write(
                clk,
                bus_addr,
                bus_write_data,
                bus_write_en,
                std_logic_vector(
                    to_unsigned(16#40000050# + (i * 4), 32)
                ),
                std_logic_vector(to_signed(A_DATA(i), 32))
            );
        end loop;

        ----------------------------------------------------------------
        -- Biases = 0
        ----------------------------------------------------------------
        for i in 0 to 3 loop
            mmio_write(
                clk,
                bus_addr,
                bus_write_data,
                bus_write_en,
                std_logic_vector(
                    to_unsigned(16#40000090# + (i * 4), 32)
                ),
                x"00000000"
            );
        end loop;

        ----------------------------------------------------------------
        -- START
        ----------------------------------------------------------------
        mmio_write(
            clk,
            bus_addr,
            bus_write_data,
            bus_write_en,
            x"40000000",
            x"00000001"
        );

        ----------------------------------------------------------------
        -- Poll STATUS
        ----------------------------------------------------------------
        loop
            bus_addr <= x"40000004";

            wait until rising_edge(clk);
            wait for 1 ns;

            exit when bus_read_data(0) = '1';
        end loop;

        ----------------------------------------------------------------
        -- Read + verify all 16 outputs
        -- 0xC0, C4 ... FC
        ----------------------------------------------------------------
        for i in 0 to 15 loop
            bus_addr <= std_logic_vector(
                to_unsigned(16#400000C0# + (i * 4), 32)
            );

            wait for 1 ns;

            assert signed(bus_read_data) = to_signed(EXPECTED(i), 32)
                report
                    "OUTPUT " & integer'image(i) &
                    " incorrect. Expected " &
                    integer'image(EXPECTED(i)) &
                    ", got " &
                    integer'image(to_integer(signed(bus_read_data)))
                severity error;
        end loop;

        report "PASS: 16-PE NNA MMIO matrix-matrix test"
            severity note;

        wait;
    end process;

end architecture;