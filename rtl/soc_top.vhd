library ieee;
use ieee.std_logic_1164.all;

entity soc_top is
    port(
        clk           : in  std_logic;
        reset         : in  std_logic;
        mmio_activity : out std_logic
    );
end entity;

architecture rtl of soc_top is

    signal bus_addr       : std_logic_vector(31 downto 0);
    signal bus_write_data : std_logic_vector(31 downto 0);
    signal bus_write_en   : std_logic;

    signal bus_read_data  : std_logic_vector(31 downto 0);
    signal bus_hit        : std_logic;

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

    cpu_inst : rv32i_core
        port map(
            clk            => clk,
            reset          => reset,

            bus_addr       => bus_addr,
            bus_write_data => bus_write_data,
            bus_write_en   => bus_write_en,

            bus_read_data  => bus_read_data,
            bus_hit        => bus_hit
        );

    nna_inst : entity work.nna_mmio_wrapper
        port map(
            clk            => clk,
            reset          => reset,

            bus_addr       => bus_addr,
            bus_write_data => bus_write_data,
            bus_write_en   => bus_write_en,

            bus_read_data  => bus_read_data,
            bus_hit        => bus_hit
        );

    mmio_activity <= bus_hit;

end architecture;