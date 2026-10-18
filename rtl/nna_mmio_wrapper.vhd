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
    signal input_write_addr : unsigned(1 downto 0);
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

    signal out0 : signed(31 downto 0);
    signal out1 : signed(31 downto 0);
    signal out2 : signed(31 downto 0);
    signal out3 : signed(31 downto 0);
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
        and bus_addr(7 downto 4) = x"1"
        and bus_addr(1 downto 0) = "00"
        else '0';
    input_write_addr <= unsigned(bus_addr(3 downto 2));
    input_write_data <= signed(bus_write_data(7 downto 0));



end architecture;
