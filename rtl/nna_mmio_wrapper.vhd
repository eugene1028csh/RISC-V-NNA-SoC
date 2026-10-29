library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity nna_mmio_wrapper is
    port(
        clk : in std_logic;
        reset : in std_logic;

        bus_addr : in std_logic_vector (31 downto 0);
        bus_write_data : in std_logic_vector (31 downto 0);
        bus_write_en : in std_logic;

        bus_read_data : out std_logic_vector (31 downto 0);
        bus_hit : out std_logic

    );
end entity;

architecture rtl of nna_mmio_wrapper is
    signal input_write_en   : std_logic;
    signal input_write_addr : unsigned(3 downto 0);
    signal input_write_data : signed(7 downto 0);

    signal weight_write_en   : std_logic;
    signal weight_write_addr : unsigned(3 downto 0);
    signal weight_write_data : signed(7 downto 0);

    signal bias_write_en   : std_logic;
    signal bias_write_addr : unsigned(1 downto 0);
    signal bias_write_data : signed(31 downto 0);

    signal nna_start : std_logic;
    signal nna_done  : std_logic;

    signal done_sticky : std_logic := '0';

    signal out0,  out1,  out2,  out3  : signed(31 downto 0);
    signal out4,  out5,  out6,  out7  : signed(31 downto 0);
    signal out8,  out9,  out10, out11 : signed(31 downto 0);
    signal out12, out13, out14, out15 : signed(31 downto 0);
begin

    bus_hit <= '1'
        when bus_addr(31 downto 8) = x"400000" -- x"400000" translates from hex to 0100 0000 0000 0000 0000 0000 in binary
        else '0';
--if full 32 bit is 0x40000010
--bus_addr(31 downto 8) = 0x400000
--bus_addr(7 downto 0)  = 0x10 
    input_write_en <= '1'
    when bus_write_en = '1'
    and bus_addr(31 downto 8) = x"400000"
    and unsigned(bus_addr(7 downto 0)) >= to_unsigned(16#10#, 8)
    and unsigned(bus_addr(7 downto 0)) <= to_unsigned(16#4C#, 8)
    and bus_addr(1 downto 0) = "00"
    else '0';

    input_write_addr <=
        resize(
            unsigned(bus_addr(7 downto 2)) - to_unsigned(4, 6),
            4
        );

    input_write_data <= signed(bus_write_data(7 downto 0));

    weight_write_en <= '1'
    when bus_write_en = '1'
    and bus_addr(31 downto 8) = x"400000"
    and unsigned(bus_addr(7 downto 0)) >= to_unsigned(16#50#, 8)
    and unsigned(bus_addr(7 downto 0)) <= to_unsigned(16#8C#, 8)
    and bus_addr(1 downto 0) = "00"
    else '0';

    weight_write_addr <=
        resize(
            unsigned(bus_addr(7 downto 2)) - to_unsigned(20, 6),
            4
        );

    weight_write_data <= signed(bus_write_data(7 downto 0));

    bias_write_en <= '1'
    when bus_write_en = '1'
    and bus_addr(31 downto 8) = x"400000"
    and unsigned(bus_addr(7 downto 0)) >= to_unsigned(16#90#, 8)
    and unsigned(bus_addr(7 downto 0)) <= to_unsigned(16#9C#, 8)
    and bus_addr(1 downto 0) = "00"
    else '0';

    bias_write_addr <=
        resize(
            unsigned(bus_addr(7 downto 2)) - to_unsigned(36, 6),
            2
        );

    bias_write_data <= signed(bus_write_data);

    nna_start <= '1'
        when bus_write_en = '1'
        and bus_addr = x"40000000"
        and bus_write_data(0) = '1'
        else '0';

    process (clk) begin
        if rising_edge(clk) then
            if reset = '1' then --reset = '1' forces done_sticky <= '0'.
                done_sticky <= '0';
            elsif nna_start = '1' then
                done_sticky <= '0';
                --nna_start = '1' also forces done_sticky <= '0' because a new job is starting, so any previous “done” status is no longer relevant.
            elsif nna_done = '1' then --nna_done = '1' sets done_sticky <= '1'
                done_sticky <= '1';
            end if;
        end if;
    end process;
    --nna_done  => one-cycle pulse from NNA
    --done_sticky => wrapper's remembered "finished" flag

    process(all)
    begin
        bus_read_data <= (others => '0'); --if the CPU reads some unmapped NNA address, it gets 0

        case bus_addr is
            when x"40000004" =>
                bus_read_data(0) <= done_sticky;

            when x"400000C0" => bus_read_data <= std_logic_vector(out0);
            when x"400000C4" => bus_read_data <= std_logic_vector(out1);
            when x"400000C8" => bus_read_data <= std_logic_vector(out2);
            when x"400000CC" => bus_read_data <= std_logic_vector(out3);

            when x"400000D0" => bus_read_data <= std_logic_vector(out4);
            when x"400000D4" => bus_read_data <= std_logic_vector(out5);
            when x"400000D8" => bus_read_data <= std_logic_vector(out6);
            when x"400000DC" => bus_read_data <= std_logic_vector(out7);

            when x"400000E0" => bus_read_data <= std_logic_vector(out8);
            when x"400000E4" => bus_read_data <= std_logic_vector(out9);
            when x"400000E8" => bus_read_data <= std_logic_vector(out10);
            when x"400000EC" => bus_read_data <= std_logic_vector(out11);

            when x"400000F0" => bus_read_data <= std_logic_vector(out12);
            when x"400000F4" => bus_read_data <= std_logic_vector(out13);
            when x"400000F8" => bus_read_data <= std_logic_vector(out14);
            when x"400000FC" => bus_read_data <= std_logic_vector(out15);

            when others =>
                null;

        end case;
    end process;

    nna_inst : entity work.toplvl
    port map (
        clk   => clk,
        reset => reset,

        input_write_en   => input_write_en,
        input_write_addr => input_write_addr,
        input_write_data => input_write_data,

        weight_write_en   => weight_write_en,
        weight_write_addr => weight_write_addr,
        weight_write_data => weight_write_data,

        bias_write_en   => bias_write_en,
        bias_write_addr => bias_write_addr,
        bias_write_data => bias_write_data,

        start => nna_start,
        done  => nna_done,

        out0  => out0,
        out1  => out1,
        out2  => out2,
        out3  => out3,

        out4  => out4,
        out5  => out5,
        out6  => out6,
        out7  => out7,

        out8  => out8,
        out9  => out9,
        out10 => out10,
        out11 => out11,

        out12 => out12,
        out13 => out13,
        out14 => out14,
        out15 => out15
    );



end architecture;
