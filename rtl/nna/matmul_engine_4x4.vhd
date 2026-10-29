library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity matmul_engine_4x4 is
  port (
    clk   : in std_logic;
    reset : in std_logic;
    start : in std_logic;

    -- Matrix A
    a00, a01, a02, a03 : in signed(7 downto 0);
    a10, a11, a12, a13 : in signed(7 downto 0);
    a20, a21, a22, a23 : in signed(7 downto 0);
    a30, a31, a32, a33 : in signed(7 downto 0);

    -- Matrix B
    b00, b01, b02, b03 : in signed(7 downto 0);
    b10, b11, b12, b13 : in signed(7 downto 0);
    b20, b21, b22, b23 : in signed(7 downto 0);
    b30, b31, b32, b33 : in signed(7 downto 0);

    -- Matrix C
    c00, c01, c02, c03 : out signed(31 downto 0);
    c10, c11, c12, c13 : out signed(31 downto 0);
    c20, c21, c22, c23 : out signed(31 downto 0);
    c30, c31, c32, c33 : out signed(31 downto 0);

    done : out std_logic
  );
end entity;

architecture rtl of matmul_engine_4x4 is
  type row4_t is array (0 to 3) of signed(7 downto 0);
  type matrix4_t is array (0 to 3) of row4_t;

  signal a_reg : matrix4_t;
  signal b_reg : matrix4_t;

  type state_t is (
    S_IDLE,
    S_CLEAR, --reset the 16 PE accumulators
    S_RUN, --cycle_count goes 1,2,3,...10
    S_DONE); --done = 1

  signal current_state : state_t := S_IDLE;
  signal next_state    : state_t := S_IDLE;

  signal cycle_count : integer range 0 to 10 := 0; --tells the scheduler which skewed inputs to feed

  signal array_a_in : row4_t;
  signal array_b_in : row4_t;

  signal array_reset  : std_logic;
  signal array_enable : std_logic;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        a_reg <= (others => (others => (others => '0')));
        b_reg <= (others => (others => (others => '0')));
      elsif start = '1' and current_state = S_IDLE then
        a_reg <= (
          0 => (a00, a01, a02, a03),
          1 => (a10, a11, a12, a13),
          2 => (a20, a21, a22, a23),
          3 => (a30, a31, a32, a33)
          );

        b_reg <= (
          0 => (b00, b01, b02, b03),
          1 => (b10, b11, b12, b13),
          2 => (b20, b21, b22, b23),
          3 => (b30, b31, b32, b33)
          );
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

      --open means dc
      a_row0_out => open,
      a_row1_out => open,
      a_row2_out => open,
      a_row3_out => open,

      b_col0_out => open,
      b_col1_out => open,
      b_col2_out => open,
      b_col3_out => open,

      result00 => c00,
      result01 => c01,
      result02 => c02,
      result03 => c03,

      result10 => c10,
      result11 => c11,
      result12 => c12,
      result13 => c13,

      result20 => c20,
      result21 => c21,
      result22 => c22,
      result23 => c23,

      result30 => c30,
      result31 => c31,
      result32 => c32,
      result33 => c33
    );

  process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        current_state <= S_IDLE;
        cycle_count   <= 0;

      else
        --At every rising edge, move the FSM into whatever state the combinational logic has decided should come next.
        current_state <= next_state;

        if current_state = S_CLEAR then
          cycle_count <= 1;

        elsif current_state = S_RUN then
          if cycle_count < 10 then
            cycle_count <= cycle_count + 1;
          end if;

        else
          cycle_count <= 0;
        end if;
      end if;
    end if;
  end process;

  process (all)
  begin
    --stay where we are
    next_state <= current_state;

    case current_state is

      when S_IDLE =>
        if start = '1' then
          next_state <= S_CLEAR;
        end if;

      when S_CLEAR =>
        next_state <= S_RUN;

      when S_RUN =>
        if cycle_count = 10 then
          next_state <= S_DONE;
        end if;

      when S_DONE =>
        next_state <= S_IDLE;

    end case;
  end process;

  --scheduler + control outputs
  process (all)
    variable index_a : integer;
    variable index_b : integer;
  begin
    array_a_in <= (others => (others => '0'));
    array_b_in <= (others => (others => '0'));

    array_reset  <= reset;
    array_enable <= '0';
    done         <= '0';

    case current_state is

      when S_IDLE =>
        null;

        --global reset = 1 → whole engine + all 16 PE accumulators reset
        --S_CLEAR         → PE accumulators reset before every new multiplication
      when S_CLEAR =>
        array_reset <= '1';

      when S_RUN =>
        array_enable <= '1';

        -- Feed A rows
        for row in 0 to 3 loop
          index_a := cycle_count - 1 - row;
          --calculates which element of that row should be injected this cycle

          if index_a >= 0 and index_a <= 3 then
            array_a_in(row)             <= a_reg(row)(index_a);
          end if;
        end loop;

        -- Feed B columns
        for col in 0 to 3 loop
          index_b := cycle_count - 1 - col;
          -- calculates which element of that column should be injected this cyclee

          if index_b >= 0 and index_b <= 3 then
            array_b_in(col)             <= b_reg(index_b)(col);
          end if;
        end loop;

      when S_DONE =>
        done <= '1';

    end case;
  end process;

end architecture;