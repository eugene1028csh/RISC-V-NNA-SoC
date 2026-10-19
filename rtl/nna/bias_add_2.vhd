library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bias_add_2 is
  port (
    data0 : in signed(31 downto 0);
    data1 : in signed(31 downto 0);

    bias0 : in signed(31 downto 0);
    bias1 : in signed(31 downto 0);

    out0 : out signed(31 downto 0);
    out1 : out signed(31 downto 0)
  );
end entity bias_add_2;

architecture rtl of bias_add_2 is
begin
    
  out0 <= data0 + bias0;
  out1 <= data1 + bias1;

end architecture;