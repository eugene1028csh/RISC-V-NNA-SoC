library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity toplvl is
  port (
    clk   : in std_logic;
    reset : in std_logic;

    input_write_en   : in std_logic;
    input_write_addr : in unsigned(1 downto 0);
    input_write_data : in signed(7 downto 0);

    weight_write_en   : in std_logic;
    weight_write_addr : in unsigned(3 downto 0);
    weight_write_data : in signed(7 downto 0);

    bias_write_en   : in std_logic;
    bias_write_addr : in unsigned(1 downto 0);
    bias_write_data : in signed(31 downto 0);

    start : in std_logic;
    done  : out std_logic;

    out0, out1, out2, out3 : out signed(31 downto 0)
  );
end entity;

architecture rtl of toplvl is
  type row8_t is array (0 to 3) of signed (7 downto 0);
  type matrix8_t is array (0 to 3) of row8_t;
  type row32_t is array (0 to 3) of signed(31 downto 0);

  signal x_buf    : row8_t;
  signal w_buf    : matrix8_t;
  signal bias_buf : row32_t;

  signal matvec_result : row32_t;
  signal bias_result   : row32_t;
  signal relu_result   : row32_t;

  signal matvec_start : std_logic;
  signal matvec_done  : std_logic;
  signal capture_en   : std_logic;

  type state_t is (S_IDLE, S_RUN, S_CAPTURE, S_DONE);
  signal current_state : state_t := S_IDLE;
  signal next_state    : state_t := S_IDLE;

begin
  input_buf_inst : entity work.input_buffer_4
    port map
    (
      clk        => clk,
      reset      => reset,
      write_en   => input_write_en,
      write_addr => input_write_addr,
      write_data => input_write_data,
      x0         => x_buf(0),
      x1         => x_buf(1),
      x2         => x_buf(2),
      x3         => x_buf(3)
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

  matvec_inst : entity work.matvec_engine_4x4
    port map
    (
      clk   => clk,
      reset => reset,
      start => matvec_start,

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
      w33 => w_buf(3)(3),

      x0 => x_buf(0),
      x1 => x_buf(1),
      x2 => x_buf(2),
      x3 => x_buf(3),

      y0 => matvec_result(0),
      y1 => matvec_result(1),
      y2 => matvec_result(2),
      y3 => matvec_result(3),

      done => matvec_done
    );

  bias01_inst : entity work.bias_add_2
    port map
    (
      data0 => matvec_result(0),
      data1 => matvec_result(1),

      bias0 => bias_buf(0),
      bias1 => bias_buf(1),

      out0 => bias_result(0),
      out1 => bias_result(1)
    );

  bias23_inst : entity work.bias_add_2
    port map
    (
      data0 => matvec_result(2),
      data1 => matvec_result(3),

      bias0 => bias_buf(2),
      bias1 => bias_buf(3),

      out0 => bias_result(2),
      out1 => bias_result(3)
    );

  relu01_inst : entity work.relu_2
    port map
    (
      data0 => bias_result(0),
      data1 => bias_result(1),

      out0 => relu_result(0),
      out1 => relu_result(1)
    );

  relu23_inst : entity work.relu_2
    port map
    (
      data0 => bias_result(2),
      data1 => bias_result(3),

      out0 => relu_result(2),
      out1 => relu_result(3)
    );

  output_buf_inst : entity work.output_buffer_4
    port map
    (
      clk        => clk,
      reset      => reset,
      capture_en => capture_en,

      data0 => relu_result(0),
      data1 => relu_result(1),
      data2 => relu_result(2),
      data3 => relu_result(3),

      out0 => out0,
      out1 => out1,
      out2 => out2,
      out3 => out3
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
        if matvec_done = '1' then
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
    matvec_start <= '0';
    capture_en   <= '0';
    done         <= '0';

    case current_state is

      when S_IDLE =>
        if start = '1' then
          matvec_start <= '1';
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