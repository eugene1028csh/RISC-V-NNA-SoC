library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity weight_buffer_16 is
  port (
    clk   : in std_logic;
    reset : in std_logic;

    write_en   : in std_logic;
    write_addr : in unsigned(3 downto 0);
    write_data : in signed(7 downto 0);

    w00, w01, w02, w03 : out signed(7 downto 0);
    w10, w11, w12, w13 : out signed(7 downto 0);
    w20, w21, w22, w23 : out signed(7 downto 0);
    w30, w31, w32, w33 : out signed(7 downto 0)
  );
end entity;

architecture rtl of weight_buffer_16 is
  type buffer_t is array (0 to 15) of signed(7 downto 0);
  signal buffer_reg : buffer_t;
begin
  process(clk) 
  begin
  if rising_edge(clk) then
    if reset = '1' then
      buffer_reg <= (others => (others => '0'));
    elsif write_en = '1' then
      buffer_reg(to_integer(write_addr)) <= write_data;
    end if;
  end if;
end process;

w00 <= buffer_reg(0);
w01 <= buffer_reg(1);
w02 <= buffer_reg(2);
w03 <= buffer_reg(3);

w10 <= buffer_reg(4);
w11 <= buffer_reg(5);
w12 <= buffer_reg(6);
w13 <= buffer_reg(7);

w20 <= buffer_reg(8);
w21 <= buffer_reg(9);
w22 <= buffer_reg(10);
w23 <= buffer_reg(11);

w30 <= buffer_reg(12);
w31 <= buffer_reg(13);
w32 <= buffer_reg(14);
w33 <= buffer_reg(15);
end architecture;