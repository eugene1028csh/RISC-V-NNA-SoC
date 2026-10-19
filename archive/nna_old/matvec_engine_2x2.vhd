library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity matvec_engine_2x2 is
  port (
    clk   : in std_logic;
    reset : in std_logic;
    start : in std_logic;

    --weights
    w00 : in signed(7 downto 0);
    w01 : in signed(7 downto 0);
    w10 : in signed(7 downto 0);
    w11 : in signed(7 downto 0);

    --input vector
    x0 : in signed(7 downto 0);
    x1 : in signed(7 downto 0);

    --output vector
    y0 : out signed(31 downto 0);
    y1 : out signed(31 downto 0);

    --status
    done : out std_logic

  );
end entity matvec_engine_2x2;

architecture rtl of matvec_engine_2x2 is
  --internal storage, captured data from external inputs
  signal w00_reg : signed(7 downto 0) := (others => '0');
  signal w01_reg : signed(7 downto 0) := (others => '0');
  signal w10_reg : signed(7 downto 0) := (others => '0');
  signal w11_reg : signed(7 downto 0) := (others => '0');
  signal x0_reg  : signed(7 downto 0) := (others => '0');
  signal x1_reg  : signed(7 downto 0) := (others => '0');

  --scheduler signals, intenrla wires/controls
  signal array_a_row0 : signed(7 downto 0) := (others => '0');
  signal array_a_row1 : signed(7 downto 0) := (others => '0');
  signal array_b_col0 : signed(7 downto 0) := (others => '0');
  signal array_b_col1 : signed(7 downto 0) := (others => '0');

  signal array_enable : std_logic := '0';
  signal array_reset  : std_logic := '0';

  signal array_result00 : signed(31 downto 0);
  signal array_result10 : signed(31 downto 0);

  type state_type is (
    S_IDLE,
    S_CLEAR,
    S_CYCLE1,
    S_CYCLE2,
    S_CYCLE3,
    S_DONE
  );

  signal current_state : state_type := S_IDLE;
  signal next_state    : state_type := S_IDLE;

begin
  matvec_units : entity work.pe_array_2x2
    --The ports of pe_array_2x2 are connected to signals inside matvec_engine_2x2
    port map
    (
      clk    => clk,
      reset  => array_reset,
      enable => array_enable,

      a_row0_in => array_a_row0,
      a_row1_in => array_a_row1,

      b_col0_in => array_b_col0,
      b_col1_in => array_b_col1,

      a_row0_out => open,
      a_row1_out => open,
      b_col0_out => open,
      b_col1_out => open,

      result00 => array_result00,
      result01 => open,
      result10 => array_result10,
      result11 => open
    );

  state_register : process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        current_state <= S_IDLE;
        w00_reg       <= (others => '0');
        w01_reg       <= (others => '0');
        w10_reg       <= (others => '0');
        w11_reg       <= (others => '0');
        x0_reg        <= (others => '0');
        x1_reg        <= (others => '0');

      else
        current_state <= next_state;

        if current_state = S_IDLE and start = '1' then
          w00_reg <= w00;
          w01_reg <= w01;
          w10_reg <= w10;
          w11_reg <= w11;

          x0_reg <= x0;
          x1_reg <= x1;

        end if;

      end if;

    end if;
  end process;

  next_state_logic : process (all)
  begin
    next_state <= current_state;
    case current_state is
      when S_IDLE =>
        if start = '1' then
          next_state <= S_CLEAR;
        end if;

      when S_ClEAR =>
        next_state <= S_CYCLE1;

      when S_CYCLE1 =>
        next_state <= S_CYCLE2;

      when S_CYCLE2 =>
        next_state <= S_CYCLE3;

      when S_CYCLE3 =>
        next_state <= S_DONE;

      when S_DONE =>
        next_state <= S_IDLE;

    end case;
  end process;

scheduler_logic : process(all)
begin
  array_reset  <= '0';
  array_enable <= '0';

  array_a_row0 <= (others => '0');
  array_a_row1 <= (others => '0');
  array_b_col0 <= (others => '0');
  array_b_col1 <= (others => '0');

  done <= '0';

    case current_state is
    when S_IDLE =>
      null;

    when S_CLEAR =>
      array_reset <= '1';

    when S_CYCLE1 =>
      array_enable <= '1';
      array_a_row0 <= w00_reg;
      array_a_row1 <= (others =>'0');
      array_b_col0 <= x0_reg;
      array_b_col1 <= (others =>'0');

    when S_CYCLE2 =>
      array_enable <= '1';
      array_a_row0 <= w01_reg;
      array_a_row1 <= w10_reg;
      array_b_col0 <= x1_reg;
      array_b_col1 <= (others =>'0');

    when S_CYCLE3 =>
      array_enable <= '1';
      array_a_row0 <= (others =>'0');
      array_a_row1 <= w11_reg;
      array_b_col0 <= (others =>'0');
      array_b_col1 <= (others =>'0');

    when S_DONE =>
      done <= '1';
  end case;

end process;

y0 <= array_result00;
y1 <= array_result10;

end architecture;