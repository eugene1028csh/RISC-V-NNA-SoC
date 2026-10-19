library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity requantize_2 is
  port (
    data0, data1 : in signed(31 downto 0);
    out0, out1   : out signed(7 downto 0)
  );
end entity;

architecture rtl of requantize_2 is
begin
  process (all)
    variable product0 : signed(47 downto 0);
    variable product1 : signed(47 downto 0);
    variable scaled0  : signed(31 downto 0);
    variable scaled1  : signed(31 downto 0);
  begin
    --Fixed point approx and add half of 2^16 for rounding
    --frequant multiplier 414/2^16
    --integer multiplier≈fractional scale ratio×216
    
    --Weight quantization: int_weight + weight_scale → represents a real weight  
    --Requantization: integer_multiplier + fixed shift → represents a fractional scale ratio
    product0 := data0 * to_signed(414, 16) + to_signed(32768, 48);
    product1 := data1 * to_signed(414, 16) + to_signed(32768, 48);

    --Divide by 2^16
    scaled0 := resize(SHIFT_RIGHT(product0, 16), 32);
    scaled1 := resize(SHIFT_RIGHT(product1, 16), 32);

    if scaled0 > to_signed(127, 32) then
      out0 <= to_signed(127, 8);
    elsif scaled0 < to_signed(-128, 32) then
      out0 <= to_signed(-128, 8);
    else
      out0 <= resize(scaled0, 8);
    end if;
    if scaled1 > to_signed(127, 32) then
      out1 <= to_signed(127, 8);
    elsif scaled1 < to_signed(-128, 32) then
      out1 <= to_signed(-128, 8);
    else
      out1 <= resize(scaled1, 8);
    end if;

  end process;

end architecture;