library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity requantize_2_configurable is
  port (
    data0, data1 : in signed(31 downto 0);
    multiplier   : in signed(15 downto 0);
    shift_amount : in unsigned(5 downto 0); --Why 6? 6 bits → 0...63, plenty for us to use
    out0, out1   : out signed(7 downto 0)
  );
end entity requantize_2_configurable;

architecture rtl of requantize_2_configurable is
begin
  process (all)
    variable product0 : signed(47 downto 0);
    variable product1 : signed(47 downto 0);
    variable scaled0  : signed(47 downto 0);
    variable scaled1  : signed(47 downto 0);
    variable round_offset : signed(47 downto 0);
    variable shift_int : integer;
    --shift_int is exactly the integer representation of how many bit positions we want to shift:
  begin
    shift_int := to_integer(shift_amount);
    round_offset := (others => '0');

    if shift_int >0 then
        round_offset := shift_left(to_signed(1, 48), shift_int - 1);
        --round_offset = 2^(shift−1)
    end if;

    product0 := data0 * multiplier;
    product1 := data1 * multiplier;

    scaled0 := shift_right(product0 + round_offset, shift_int);
    scaled1 := shift_right(product1 + round_offset, shift_int);
    --scaled =     (product + round_offset)     >> shift_in  
    --shifting changes the numerical value; resizing changes the bit-width.

    if scaled0 > to_signed(127, 48) then
      out0 <= to_signed(127, 8);
    elsif scaled0 < to_signed(-128, 48) then
      out0 <= to_signed(-128, 8);
    else
      out0 <= resize(scaled0, 8);
    end if;
    if scaled1 > to_signed(127, 48) then
      out1 <= to_signed(127, 8);
    elsif scaled1 < to_signed(-128, 48) then
      out1 <= to_signed(-128, 8);
    else
      out1 <= resize(scaled1, 8);
    end if;
  end process;
end architecture;