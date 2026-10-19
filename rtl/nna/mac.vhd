library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mac is
  port (
    clk  : in std_logic;
    reset  : in std_logic;
    enable : in std_logic;

    a : in signed(7 downto 0);
    b : in signed(7 downto 0);

    result : out signed(31 downto 0)
  );
end entity mac;

architecture rtl of mac is

  signal accumulator : signed (31 downto 0);

begin
  process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        accumulator <= (others => '0');
      elsif enable = '1' then
        accumulator <= accumulator + resize(a*b, 32);
      end if;

    end if;

  end process;

  result <= accumulator;

end architecture;
