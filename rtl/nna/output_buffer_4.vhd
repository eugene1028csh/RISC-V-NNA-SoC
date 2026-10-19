library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity output_buffer_4 is
  port (
    clk   : in std_logic;
    reset : in std_logic;

    capture_en : in std_logic; --On the next rising edge, save all four accelerator outputs.

    data0, data1, data2, data3 : in signed(31 downto 0);

    out0, out1, out2, out3 : out signed(31 downto 0)
  );
end entity;

architecture rtl of output_buffer_4 is
  type buffer_t is array (0 to 3) of signed (31 downto 0);
  signal buffer_reg : buffer_t;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        buffer_reg       <= (others => (others => '0'));
      elsif capture_en = '1' then
        buffer_reg(0)    <= data0;
        buffer_reg(1)    <= data1;
        buffer_reg(2)    <= data2;
        buffer_reg(3)    <= data3;
      end if;
    end if;

  end process;
  out0 <= buffer_reg(0);
  out1 <= buffer_reg(1);
  out2 <= buffer_reg(2);
  out3 <= buffer_reg(3);
end architecture;