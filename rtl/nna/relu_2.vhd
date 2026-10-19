library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity relu_2 is
  port (
    data0, data1 : in signed(31 downto 0);
    out0, out1   : out signed(31 downto 0)
  );
end entity relu_2;

architecture rtl of relu_2 is
begin
  out0 <= (others => '0') when data0(31) = '1' else
    data0;
  out1 <= (others => '0') when data1(31) = '1' else
    data1;
--data0/1(31) is the MSB, when its 0, its +ve, when 1 its -ve
-- what we want is, if -ve, output 0, if +ve, output its value
--RelU means, max(0,x)
end architecture;
