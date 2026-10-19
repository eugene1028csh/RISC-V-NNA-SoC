library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity input_buffer_4 is
  port (
    clk   : in std_logic;
    reset : in std_logic;

    write_en   : in std_logic;
    write_addr : in unsigned(1 downto 0); --2 bits becasuse we only have 4 locations: x0-x3
    write_data : in signed(7 downto 0);

    x0 : out signed(7 downto 0);
    x1 : out signed(7 downto 0);
    x2 : out signed(7 downto 0);
    x3 : out signed(7 downto 0)
  );
end entity;

architecture rtl of input_buffer_4 is
  type buffer_t is array (0 to 3) of signed (7 downto 0);
  signal buffer_reg : buffer_t;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        buffer_reg <= (others => (others => '0'));

      elsif write_en = '1' then
        buffer_reg(to_integer(write_addr)) <= write_data;
        --one write port can update any of the 4 stored inputs depending on the address.
      end if;
    end if;
  end process;

  x0 <= buffer_reg(0);
  x1 <= buffer_reg(1);
  x2 <= buffer_reg(2);
  x3 <= buffer_reg(3);

end architecture;