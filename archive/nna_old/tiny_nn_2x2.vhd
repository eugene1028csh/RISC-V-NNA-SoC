library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tiny_nn_2x2 is
  port (
    --control
    clk   : in std_logic;
    reset : in std_logic;
    start : in std_logic;
    done  : out std_logic;

    --input
    x0, x1 : in signed(7 downto 0);

    --layer 1
    w1_00, w1_01 : in signed(7 downto 0);
    w1_10, w1_11 : in signed(7 downto 0);
    b1_0, b1_1   : in signed(31 downto 0);

    --layer 2
    w2_00, w2_01 : in signed(7 downto 0);
    w2_10, w2_11 : in signed(7 downto 0);
    b2_0, b2_1   : in signed(31 downto 0);

    --output
    y0, y1 : out signed(31 downto 0)

  );
end entity;

architecture rtl of tiny_nn_2x2 is
  signal l1_out0   : signed(31 downto 0) := (others => '0');
  signal l1_out1   : signed(31 downto 0) := (others => '0');
  signal hidden_q0 : signed(7 downto 0)  := (others => '0');
  signal hidden_q1 : signed(7 downto 0)  := (others => '0');
  signal l1_start  : std_logic           := '0';
  signal l1_done   : std_logic           := '0';
  signal l2_start  : std_logic           := '0';
  signal l2_done   : std_logic           := '0';

  type state_type is(
  S_IDLE,
  S_START_L1,
  S_WAIT_L1,
  S_START_L2,
  S_WAIT_L2,
  S_DONE
  );

  signal current_state : state_type := S_IDLE;
  signal next_state    : state_type := S_IDLE;
begin
  l1 : entity work.dense_layer_2x2
    port map
    (
      clk   => clk,
      reset => reset,
      start => l1_start,

      w00 => w1_00,
      w01 => w1_01,
      w10 => w1_10,
      w11 => w1_11,

      x0 => x0,
      x1 => x1,

      bias0 => b1_0,
      bias1 => b1_1,

      y0 => l1_out0,
      y1 => l1_out1,

      done => l1_done
    );

  requant : entity work.requantize_2
    port map
    (
      data0 => l1_out0,
      data1 => l1_out1,
      out0  => hidden_q0,
      out1  => hidden_q1
    );

  l2 : entity work.dense_layer_2x2
    port map
    (
      clk   => clk,
      reset => reset,
      start => l2_start,

      w00 => w2_00,
      w01 => w2_01,
      w10 => w2_10,
      w11 => w2_11,

      x0 => hidden_q0,
      x1 => hidden_q1,

      bias0 => b2_0,
      bias1 => b2_1,

      y0 => y0,
      y1 => y1,

      done => l2_done
    );

  state_register : process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        current_state <= S_IDLE;
      else
        current_state <= next_state;
      end if;
    end if;
  end process;

  next_state_logic : process (all)
  begin
    next_state <= current_state;
    case current_state is
      when S_IDLE =>
        if start = '1' then
          next_state <= S_START_L1;
        end if;

      when S_START_L1 =>
        next_state <= S_WAIT_L1;

      when S_WAIT_L1 =>
        if l1_done = '1' then
          next_state <= S_START_L2;
        end if;

      when S_START_L2 =>
        next_state <= S_WAIT_L2;

      when S_WAIT_L2 =>
        if l2_done = '1' then
            next_state <= S_DONE;
        end if;
      when S_DONE =>
        next_state <= S_IDLE;
    end case;
  end process;

  controller_logic : process(all)
  begin
    l1_start <= '0';
    l2_start <= '0';
    done <= '0';

    case current_state is
        when S_START_L1 =>
        l1_start <= '1';
        
        when S_START_L2 =>
        l2_start <= '1';

        when S_DONE =>
        done <= '1';
        
        when others =>
        null;
    
    end case;
  end process;
end architecture;