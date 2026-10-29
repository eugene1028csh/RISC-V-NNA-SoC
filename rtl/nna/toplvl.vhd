library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity toplvl is
  port (
    clk   : in std_logic;
    reset : in std_logic;

    input_write_en   : in std_logic;
    input_write_addr : in unsigned(3 downto 0);
    input_write_data : in signed(7 downto 0);

    weight_write_en   : in std_logic;
    weight_write_addr : in unsigned(3 downto 0);
    weight_write_data : in signed(7 downto 0);

    bias_write_en   : in std_logic;
    bias_write_addr : in unsigned(1 downto 0);
    bias_write_data : in signed(31 downto 0);

    start : in std_logic;
    done  : out std_logic;

    out0,  out1,  out2,  out3  : out signed(31 downto 0);
    out4,  out5,  out6,  out7  : out signed(31 downto 0);
    out8,  out9,  out10, out11 : out signed(31 downto 0);
    out12, out13, out14, out15 : out signed(31 downto 0)
  );
end entity;

architecture rtl of toplvl is
  type row8_t is array (0 to 3) of signed (7 downto 0);
  type matrix8_t is array (0 to 3) of row8_t;
  type row32_t    is array (0 to 3) of signed(31 downto 0);
  type matrix32_t is array (0 to 3) of row32_t;

  signal w_buf    : matrix8_t; -- Matrix A
  signal b_buf    : matrix8_t; -- Matrix B
  signal bias_buf : row32_t;

  signal matmul_result : matrix32_t;
  signal bias_result   : matrix32_t;
  signal relu_result   : matrix32_t;

  signal matmul_start : std_logic;
  signal matmul_done  : std_logic;
  signal capture_en   : std_logic;

  type state_t is (S_IDLE, S_RUN, S_CAPTURE, S_DONE);
  signal current_state : state_t := S_IDLE;
  signal next_state    : state_t := S_IDLE;

begin
  input_buf_inst : entity work.weight_buffer_16
    port map
    (
      clk   => clk,
      reset => reset,

      write_en   => input_write_en,
      write_addr => input_write_addr,
      write_data => input_write_data,

      w00 => b_buf(0)(0),
      w01 => b_buf(0)(1),
      w02 => b_buf(0)(2),
      w03 => b_buf(0)(3),

      w10 => b_buf(1)(0),
      w11 => b_buf(1)(1),
      w12 => b_buf(1)(2),
      w13 => b_buf(1)(3),

      w20 => b_buf(2)(0),
      w21 => b_buf(2)(1),
      w22 => b_buf(2)(2),
      w23 => b_buf(2)(3),

      w30 => b_buf(3)(0),
      w31 => b_buf(3)(1),
      w32 => b_buf(3)(2),
      w33 => b_buf(3)(3)
    );

  weight_buf_inst : entity work.weight_buffer_16
    port map
    (
      clk   => clk,
      reset => reset,

      write_en   => weight_write_en,
      write_addr => weight_write_addr,
      write_data => weight_write_data,

      w00 => w_buf(0)(0),
      w01 => w_buf(0)(1),
      w02 => w_buf(0)(2),
      w03 => w_buf(0)(3),

      w10 => w_buf(1)(0),
      w11 => w_buf(1)(1),
      w12 => w_buf(1)(2),
      w13 => w_buf(1)(3),

      w20 => w_buf(2)(0),
      w21 => w_buf(2)(1),
      w22 => w_buf(2)(2),
      w23 => w_buf(2)(3),

      w30 => w_buf(3)(0),
      w31 => w_buf(3)(1),
      w32 => w_buf(3)(2),
      w33 => w_buf(3)(3)
    );

  bias_buf_inst : entity work.bias_buffer_4
    port map
    (
      clk   => clk,
      reset => reset,

      write_en   => bias_write_en,
      write_addr => bias_write_addr,
      write_data => bias_write_data,

      bias0 => bias_buf(0),
      bias1 => bias_buf(1),
      bias2 => bias_buf(2),
      bias3 => bias_buf(3)
    );

  matmul_inst : entity work.matmul_engine_4x4
    port map
    (
      clk   => clk,
      reset => reset,
      start => matmul_start,

      a00 => w_buf(0)(0),
      a01 => w_buf(0)(1),
      a02 => w_buf(0)(2),
      a03 => w_buf(0)(3),

      a10 => w_buf(1)(0),
      a11 => w_buf(1)(1),
      a12 => w_buf(1)(2),
      a13 => w_buf(1)(3),

      a20 => w_buf(2)(0),
      a21 => w_buf(2)(1),
      a22 => w_buf(2)(2),
      a23 => w_buf(2)(3),

      a30 => w_buf(3)(0),
      a31 => w_buf(3)(1),
      a32 => w_buf(3)(2),
      a33 => w_buf(3)(3),

      b00 => b_buf(0)(0),
      b01 => b_buf(0)(1),
      b02 => b_buf(0)(2),
      b03 => b_buf(0)(3),

      b10 => b_buf(1)(0),
      b11 => b_buf(1)(1),
      b12 => b_buf(1)(2),
      b13 => b_buf(1)(3),

      b20 => b_buf(2)(0),
      b21 => b_buf(2)(1),
      b22 => b_buf(2)(2),
      b23 => b_buf(2)(3),

      b30 => b_buf(3)(0),
      b31 => b_buf(3)(1),
      b32 => b_buf(3)(2),
      b33 => b_buf(3)(3),

      c00 => matmul_result(0)(0),
      c01 => matmul_result(0)(1),
      c02 => matmul_result(0)(2),
      c03 => matmul_result(0)(3),

      c10 => matmul_result(1)(0),
      c11 => matmul_result(1)(1),
      c12 => matmul_result(1)(2),
      c13 => matmul_result(1)(3),

      c20 => matmul_result(2)(0),
      c21 => matmul_result(2)(1),
      c22 => matmul_result(2)(2),
      c23 => matmul_result(2)(3),

      c30 => matmul_result(3)(0),
      c31 => matmul_result(3)(1),
      c32 => matmul_result(3)(2),
      c33 => matmul_result(3)(3),

      done => matmul_done
    );

    -- Row 0 bias
  bias00_01_inst : entity work.bias_add_2
    port map (
      data0 => matmul_result(0)(0),
      data1 => matmul_result(0)(1),
      bias0 => bias_buf(0),
      bias1 => bias_buf(0),
      out0  => bias_result(0)(0),
      out1  => bias_result(0)(1)
    );

  bias02_03_inst : entity work.bias_add_2
    port map (
      data0 => matmul_result(0)(2),
      data1 => matmul_result(0)(3),
      bias0 => bias_buf(0),
      bias1 => bias_buf(0),
      out0  => bias_result(0)(2),
      out1  => bias_result(0)(3)
    );

  -- Row 1 bias
  bias10_11_inst : entity work.bias_add_2
    port map (
      data0 => matmul_result(1)(0),
      data1 => matmul_result(1)(1),
      bias0 => bias_buf(1),
      bias1 => bias_buf(1),
      out0  => bias_result(1)(0),
      out1  => bias_result(1)(1)
    );

  bias12_13_inst : entity work.bias_add_2
    port map (
      data0 => matmul_result(1)(2),
      data1 => matmul_result(1)(3),
      bias0 => bias_buf(1),
      bias1 => bias_buf(1),
      out0  => bias_result(1)(2),
      out1  => bias_result(1)(3)
    );

  -- Row 2 bias
  bias20_21_inst : entity work.bias_add_2
    port map (
      data0 => matmul_result(2)(0),
      data1 => matmul_result(2)(1),
      bias0 => bias_buf(2),
      bias1 => bias_buf(2),
      out0  => bias_result(2)(0),
      out1  => bias_result(2)(1)
    );

  bias22_23_inst : entity work.bias_add_2
    port map (
      data0 => matmul_result(2)(2),
      data1 => matmul_result(2)(3),
      bias0 => bias_buf(2),
      bias1 => bias_buf(2),
      out0  => bias_result(2)(2),
      out1  => bias_result(2)(3)
    );

  -- Row 3 bias
  bias30_31_inst : entity work.bias_add_2
    port map (
      data0 => matmul_result(3)(0),
      data1 => matmul_result(3)(1),
      bias0 => bias_buf(3),
      bias1 => bias_buf(3),
      out0  => bias_result(3)(0),
      out1  => bias_result(3)(1)
    );

  bias32_33_inst : entity work.bias_add_2
    port map (
      data0 => matmul_result(3)(2),
      data1 => matmul_result(3)(3),
      bias0 => bias_buf(3),
      bias1 => bias_buf(3),
      out0  => bias_result(3)(2),
      out1  => bias_result(3)(3)
    );

    relu00_01_inst : entity work.relu_2
    port map (
      data0 => bias_result(0)(0),
      data1 => bias_result(0)(1),
      out0  => relu_result(0)(0),
      out1  => relu_result(0)(1)
    );

  relu02_03_inst : entity work.relu_2
    port map (
      data0 => bias_result(0)(2),
      data1 => bias_result(0)(3),
      out0  => relu_result(0)(2),
      out1  => relu_result(0)(3)
    );

  relu10_11_inst : entity work.relu_2
    port map (
      data0 => bias_result(1)(0),
      data1 => bias_result(1)(1),
      out0  => relu_result(1)(0),
      out1  => relu_result(1)(1)
    );

  relu12_13_inst : entity work.relu_2
    port map (
      data0 => bias_result(1)(2),
      data1 => bias_result(1)(3),
      out0  => relu_result(1)(2),
      out1  => relu_result(1)(3)
    );

  relu20_21_inst : entity work.relu_2
    port map (
      data0 => bias_result(2)(0),
      data1 => bias_result(2)(1),
      out0  => relu_result(2)(0),
      out1  => relu_result(2)(1)
    );

  relu22_23_inst : entity work.relu_2
    port map (
      data0 => bias_result(2)(2),
      data1 => bias_result(2)(3),
      out0  => relu_result(2)(2),
      out1  => relu_result(2)(3)
    );

  relu30_31_inst : entity work.relu_2
    port map (
      data0 => bias_result(3)(0),
      data1 => bias_result(3)(1),
      out0  => relu_result(3)(0),
      out1  => relu_result(3)(1)
    );

  relu32_33_inst : entity work.relu_2
    port map (
      data0 => bias_result(3)(2),
      data1 => bias_result(3)(3),
      out0  => relu_result(3)(2),
      out1  => relu_result(3)(3)
    );
    output_buf_row0 : entity work.output_buffer_4
    port map (
      clk => clk,
      reset => reset,
      capture_en => capture_en,

      data0 => relu_result(0)(0),
      data1 => relu_result(0)(1),
      data2 => relu_result(0)(2),
      data3 => relu_result(0)(3),

      out0 => out0,
      out1 => out1,
      out2 => out2,
      out3 => out3
    );

  output_buf_row1 : entity work.output_buffer_4
    port map (
      clk => clk,
      reset => reset,
      capture_en => capture_en,

      data0 => relu_result(1)(0),
      data1 => relu_result(1)(1),
      data2 => relu_result(1)(2),
      data3 => relu_result(1)(3),

      out0 => out4,
      out1 => out5,
      out2 => out6,
      out3 => out7
    );

  output_buf_row2 : entity work.output_buffer_4
    port map (
      clk => clk,
      reset => reset,
      capture_en => capture_en,

      data0 => relu_result(2)(0),
      data1 => relu_result(2)(1),
      data2 => relu_result(2)(2),
      data3 => relu_result(2)(3),

      out0 => out8,
      out1 => out9,
      out2 => out10,
      out3 => out11
    );

  output_buf_row3 : entity work.output_buffer_4
    port map (
      clk => clk,
      reset => reset,
      capture_en => capture_en,

      data0 => relu_result(3)(0),
      data1 => relu_result(3)(1),
      data2 => relu_result(3)(2),
      data3 => relu_result(3)(3),

      out0 => out12,
      out1 => out13,
      out2 => out14,
      out3 => out15
    );

  --fsm state reg
  process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        current_state <= S_IDLE;
      else
        current_state <= next_state;
      end if;
    end if;
  end process;

  -- next state logic
  process (all)
  begin
    next_state <= current_state;

    case current_state is

      when S_IDLE =>
        if start = '1' then
          next_state <= S_RUN;
        end if;

      when S_RUN =>
        if matmul_done = '1' then
          next_state <= S_CAPTURE;
        end if;

      when S_CAPTURE =>
        next_state <= S_DONE;

      when S_DONE =>
        next_state <= S_IDLE;

    end case;
  end process;

  --fsm control ouptuts
  process (all)
  begin
    matmul_start <= '0';
    capture_en   <= '0';
    done         <= '0';

    case current_state is

      when S_IDLE =>
        if start = '1' then
          matmul_start <= '1';
        end if;

      when S_RUN =>
        null;

      when S_CAPTURE =>
        capture_en <= '1';

      when S_DONE =>
        done <= '1';
    end case;

  end process;
end architecture;