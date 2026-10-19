library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity matmul_engine_2x2 is
  port (
    clk   : in std_logic;
    reset : in std_logic;
    start : in std_logic;

    --Matrix A
    a00 : in signed(7 downto 0);
    a01 : in signed(7 downto 0);
    a10 : in signed(7 downto 0);
    a11 : in signed(7 downto 0);

    --Matrix B
    b00 : in signed(7 downto 0);
    b01 : in signed(7 downto 0);
    b10 : in signed(7 downto 0);
    b11 : in signed(7 downto 0);

    --Matrix C
    c00 : out signed(31 downto 0);
    c01 : out signed(31 downto 0);
    c10 : out signed(31 downto 0);
    c11 : out signed(31 downto 0);

    done : out std_logic
  );
end entity matmul_engine_2x2;

architecture rtl of matmul_engine_2x2 is
  signal a00_reg, a01_reg : signed(7 downto 0) := (others => '0');
  signal a10_reg, a11_reg : signed(7 downto 0) := (others => '0');

  signal b00_reg, b01_reg : signed(7 downto 0) := (others => '0');
  signal b10_reg, b11_reg : signed(7 downto 0) := (others => '0');

  signal array_a_row0 : signed(7 downto 0) := (others => '0');
  signal array_a_row1 : signed(7 downto 0) := (others => '0');

  signal array_b_col0 : signed(7 downto 0) := (others => '0');
  signal array_b_col1 : signed(7 downto 0) := (others => '0');

  signal array_enable : std_logic := '0';
  signal array_reset  : std_logic := '0';

  signal array_result00 : signed(31 downto 0);
  signal array_result01 : signed(31 downto 0);
  signal array_result10 : signed(31 downto 0);
  signal array_result11 : signed(31 downto 0);

  type state_type is (
    S_IDLE,
    S_CLEAR,
    S_CYCLE1,
    S_CYCLE2,
    S_CYCLE3,
    S_CYCLE4,
    S_DONE
  );

  signal current_state : state_type := S_IDLE;
  signal next_state    : state_type := S_IDLE;

begin
  array_unit : entity work.pe_array_2x2
    --instantiate theeneity pe_array_2x2
    --child entity port  =>  signal in this architecture
    --reset => array_reset means
    --pe_array_2x2's reset port connected to matmul_engine's internal array_reset signal
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
      result01 => array_result01,
      result10 => array_result10,
      result11 => array_result11
    );
  state_register : process (clk)
    -- Clocked process.
    -- Stores the current FSM state and captures Matrix A/B when start = '1'.
    -- current_state only changes on the rising edge of clk.
  begin
    if rising_edge(clk) then
      if reset = '1' then
        current_state <= S_IDLE;

        a00_reg <= (others => '0');
        a01_reg <= (others => '0');
        a10_reg <= (others => '0');
        a11_reg <= (others => '0');

        b00_reg <= (others => '0');
        b01_reg <= (others => '0');
        b10_reg <= (others => '0');
        b11_reg <= (others => '0');

      else
        current_state <= next_state;

        if current_state = S_IDLE and start = '1' then

          a00_reg <= a00;
          a01_reg <= a01;
          a10_reg <= a10;
          a11_reg <= a11;

          b00_reg <= b00;
          b01_reg <= b01;
          b10_reg <= b10;
          b11_reg <= b11;
        end if;
      end if;
    end if;
  end process;
  next_state_logic : process (all)
    -- Combinational process.
    -- Decides which FSM state should come next based on current_state/start.
    -- Does not wait for a clock edge.
  begin
    next_state <= current_state; --default, stay where we are

    case current_state is

      when S_IDLE =>
        if start = '1' then
          next_state <= S_CLEAR;
        end if;

        -- S_CLEAR is a cleanup/reset state for the PE array before starting a new multiplication
      when S_CLEAR =>
        next_state <= S_CYCLE1;

      when S_CYCLE1 =>
        next_state <= S_CYCLE2;

      when S_CYCLE2 =>
        next_state <= S_CYCLE3;

      when S_CYCLE3 =>
        next_state <= S_CYCLE4;

      when S_CYCLE4 =>
        next_state <= S_DONE;

      when S_DONE =>
        next_state <= S_IDLE;

    end case;
  end process;
  scheduler_logic : process (all)
    -- Combinational process.
    -- Defines what each FSM state does.
    -- Feeds the correct skewed A/B values into the systolic array,
    -- controls array_reset/array_enable, and drives done.
  begin
    --safe defaults
    array_reset  <= '0';
    array_enable <= '0';
    array_a_row0 <= (others => '0');
    array_a_row1 <= (others => '0');
    array_b_col0 <= (others => '0');
    array_b_col1 <= (others => '0');
    done         <= '0';

    case current_state is
      when S_IDLE =>
        null;

      when S_CLEAR =>
        array_reset <= '1';

      when S_CYCLE1 =>
        array_enable <= '1';
        array_a_row0 <= a00_reg;
        array_a_row1 <= (others => '0');
        array_b_col0 <= b00_reg;
        array_b_col1 <= (others => '0');

      when S_CYCLE2 =>
        array_enable <= '1';
        array_a_row0 <= a01_reg;
        array_a_row1 <= a10_reg;
        array_b_col0 <= b10_reg;
        array_b_col1 <= b01_reg;

      when S_CYCLE3 =>
        array_enable <= '1';
        array_a_row0 <= (others => '0');
        array_a_row1 <= a11_reg;
        array_b_col0 <= (others => '0');
        array_b_col1 <= b11_reg;

      when S_CYCLE4 =>
        array_enable <= '1';

      when S_DONE =>
        done <= '1';

    end case;
  end process;

  c00 <= array_result00;
  c01 <= array_result01;
  c10 <= array_result10;
  c11 <= array_result11;
  
end architecture;