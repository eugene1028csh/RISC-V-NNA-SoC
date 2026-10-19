library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity matvec_engine_4x4 is
  port (
    clk   : in std_logic;
    reset : in std_logic;
    start : in std_logic;

    w00, w01, w02, w03 : in signed(7 downto 0);
    w10, w11, w12, w13 : in signed(7 downto 0);
    w20, w21, w22, w23 : in signed(7 downto 0);
    w30, w31, w32, w33 : in signed(7 downto 0);

    x0, x1, x2, x3 : in signed(7 downto 0);

    y0, y1, y2, y3 : out signed(31 downto 0);

    done : out std_logic
  );
end entity;

architecture rtl of matvec_engine_4x4 is
  type row4_t is array (0 to 3) of signed(7 downto 0);
  type matrix4_t is array (0 to 3) of row4_t;

  signal w_reg : matrix4_t;
  signal x_reg : row4_t;

  type state_t is (S_IDLE, S_CLEAR, S_RUN, S_DONE);

  signal current_state : state_t := S_IDLE;
  signal next_state    : state_t := S_IDLE;

  signal cycle_count : integer range 0 to 7 := 0;

  signal array_a_in : row4_t;
  signal array_b_in : row4_t;

  signal array_reset  : std_logic;
  signal array_enable : std_logic;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then

        w_reg <= (others => (others => (others => '0')));
        x_reg <= (others => (others => '0'));

      elsif start = '1' and current_state = S_IDLE then

        w_reg <= (
          0 => (w00, w01, w02, w03),
          1 => (w10, w11, w12, w13),
          2 => (w20, w21, w22, w23),
          3 => (w30, w31, w32, w33)
          );

        x_reg <= (x0, x1, x2, x3);

      end if;
    end if;
  end process;

  array_inst : entity work.pe_array_4x4
    port map
    (
      clk    => clk,
      reset  => array_reset,
      enable => array_enable,

      a_row0_in => array_a_in(0),
      a_row1_in => array_a_in(1),
      a_row2_in => array_a_in(2),
      a_row3_in => array_a_in(3),

      b_col0_in => array_b_in(0),
      b_col1_in => array_b_in(1),
      b_col2_in => array_b_in(2),
      b_col3_in => array_b_in(3),

      a_row0_out => open,
      a_row1_out => open,
      a_row2_out => open,
      a_row3_out => open,

      b_col0_out => open,
      b_col1_out => open,
      b_col2_out => open,
      b_col3_out => open,

      result00 => y0,
      result01 => open,
      result02 => open,
      result03 => open,

      result10 => y1,
      result11 => open,
      result12 => open,
      result13 => open,

      result20 => y2,
      result21 => open,
      result22 => open,
      result23 => open,

      result30 => y3,
      result31 => open,
      result32 => open,
      result33 => open
    );

  --fsm state register and counter
  process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        current_state <= S_IDLE;
        cycle_count   <= 0;

      else
        current_state <= next_state;

        if current_state = S_CLEAR then
          cycle_count <= 1;

        elsif current_state = S_RUN then
          if cycle_count < 7 then
            cycle_count <= cycle_count + 1;
          end if;

        else
          cycle_count <= 0;
        end if;

      end if;
    end if;
  end process;

  --next state logic
  process (all)
  begin
    next_state <= current_state;

    case current_state is

      when S_IDLE =>
        if start = '1' then
          next_state <= S_CLEAR;
        end if;

      when S_CLEAR =>
        next_state <= S_RUN;

      when S_RUN =>
        if cycle_count = 7 then
          next_state <= S_DONE;
        end if;

      when S_DONE =>
        next_state <= S_IDLE;

    end case;
  end process;

  -- scheduler+ control
  process (all)
    variable weight_index : integer;
  begin
    array_a_in <= (others => (others => '0'));
    array_b_in <= (others => (others => '0'));

    array_reset  <= reset;
    array_enable <= '0';
    done         <= '0';

    case current_state is

      when S_IDLE =>
        null;

      when S_CLEAR =>
        array_reset <= '1';

      when S_RUN =>
        array_enable <= '1';

        -- skew weight rows
        for row in 0 to 3 loop
          weight_index := cycle_count - 1 - row;

          if weight_index >= 0 and weight_index <= 3 then
            array_a_in(row)                       <= w_reg(row)(weight_index);
          end if;
        end loop;

        -- Feed x vector down column 0
        if cycle_count >= 1 and cycle_count <= 4 then
          array_b_in(0)                       <= x_reg(cycle_count - 1);
        end if;

      when S_DONE =>
        done <= '1';

    end case;
  end process;

end architecture;