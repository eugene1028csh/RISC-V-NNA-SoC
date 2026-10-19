library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dense_layer_2x2 is
  port (
    clk   : in std_logic;
    reset : in std_logic;
    start : in std_logic;

    w00, w01 : in signed(7 downto 0);
    w10, w11 : in signed(7 downto 0);

    x0, x1 : in signed(7 downto 0);

    bias0, bias1 : in signed(31 downto 0);

    y0, y1 : out signed(31 downto 0);

    done : out std_logic

  );
end entity;

architecture rtl of dense_layer_2x2 is
  signal matvec_result0 : signed(31 downto 0) := (others => '0');
  signal matvec_result1 : signed(31 downto 0) := (others => '0');
  signal bias_result0   : signed(31 downto 0) := (others => '0');
  signal bias_result1   : signed(31 downto 0) := (others => '0');
  --internal signals that connect MatVec → Bias → ReLU
  --y=ReLU(Wx+b)
begin
  matvec_unit : entity work.matvec_engine_2x2
    port map
    (
      clk   => clk,
      reset => reset,
      start => start,

      w00 => w00,
      w01 => w01,
      w10 => w10,
      w11 => w11,
      x0  => x0,
      x1  => x1,
      y0  => matvec_result0,
      y1  => matvec_result1,

      done => done
    );

    bias_unit : entity work.bias_add_2
    port map(
        data0 => matvec_result0,
        data1 => matvec_result1,
        bias0 => bias0,
        bias1 => bias1,
        out0 => bias_result0,
        out1 => bias_result1
    );

    relu_unit : entity work.relu_2
    port map(
    data0 => bias_result0,
    data1 => bias_result1,
    out0 => y0,
    out1 => y1
    );
end architecture;