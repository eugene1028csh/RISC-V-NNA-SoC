library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pe is
  port (
    clk : in std_logic;
    reset : in std_logic;
    enable : in std_logic;

    a_in : in signed(7 downto 0);
    b_in : in signed(7 downto 0);

    a_out : out signed(7 downto 0);
    b_out : out signed(7 downto 0);

    result : out signed(31 downto 0)
  );
end entity pe;

architecture rtl of pe is
  signal a_reg : signed (7 downto 0);
  signal b_reg : signed (7 downto 0);
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        a_reg <= (others => '0');
        b_reg <= (others => '0');
      elsif enable = '1' then
        a_reg <= a_in;
        b_reg <= b_in;

      end if;
    end if;

  end process;

  mac_unit : entity work.mac
    port map
    (
      clk => clk,
      reset => reset,
      enable => enable,
      a => a_in,
      b => b_in,
      result => result
    );
  a_out <= a_reg;
  b_out <= b_reg;

end architecture;