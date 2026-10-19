library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bias_buffer_4 is
  port (
    clk   : in std_logic;
    reset : in std_logic;

    write_en   : in std_logic;
    write_addr : in unsigned(1 downto 0);
    write_data : in signed(31 downto 0);

    bias0 : out signed(31 downto 0);
    bias1 : out signed(31 downto 0);
    bias2 : out signed(31 downto 0);
    bias3 : out signed(31 downto 0)
  );
end entity;

architecture rtl of bias_buffer_4 is
    type buffer_t is array (0 to 3) of signed (31 downto 0);
    --buffer_t = 4 storage locations, each location stores one 32-bit signed value
    signal buffer_reg : buffer_t;
    --creates an actual storage unit using that type 
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                buffer_reg <= (others =>(others => '0'));
                -- if reset active,clear the whole buffer
            elsif write_en = '1' then
                -- if we not resetting, and write_en is active then store 1 value
                buffer_reg(to_integer(write_addr)) <= write_data;
                --to_integer turns binary addr to intgers, eg. 11 to 3, then data is written to it
                -- buffer_reg(to_integer(011)) <= write_data becomes buffer_reg(3) <= 500
            end if;
        end if;
    end process;
    bias0 <= buffer_reg(0);
    bias1 <= buffer_reg(1);
    bias2 <= buffer_reg(2);
    bias3 <= buffer_reg(3);
end architecture;