library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pe_array_2x2 is
    port(
        clk : in std_logic;
        reset: in std_logic;
        enable : in std_logic;

        a_row0_in : in signed(7 downto 0);
        a_row1_in : in signed(7 downto 0);
        b_col0_in : in signed(7 downto 0);
        b_col1_in : in signed(7 downto 0);
        a_row0_out : out signed(7 downto 0);
        a_row1_out : out signed(7 downto 0);
        b_col0_out : out signed(7 downto 0);
        b_col1_out : out signed(7 downto 0);

        result00 : out signed(31 downto 0);
        result01 : out signed(31 downto 0);
        result10 : out signed(31 downto 0);
        result11 : out signed(31 downto 0)  
    );
    end entity pe_array_2x2;

architecture rtl of pe_array_2x2 is
signal a_00_01 : signed(7 downto 0); -- A travelling from PE00 → PE01
signal a_10_11 : signed(7 downto 0); -- A travelling from PE10 → PE11
signal b_00_10 : signed(7 downto 0); -- B travelling from PE00 → PE10
signal b_01_11 : signed(7 downto 0); -- B travelling from PE01 → PE11
begin
    pe00 : entity work.pe
    port map(
        clk => clk,
        reset => reset,
        enable => enable, 
        a_in => a_row0_in,
        b_in => b_col0_in,
        a_out => a_00_01,
        b_out => b_00_10,

        result => result00
    );

    pe01 : entity work.pe
    port map(
        clk => clk,
        reset => reset,
        enable => enable, 
        a_in => a_00_01, --from PE00
        b_in => b_col1_in, --directly from top of col 1
        a_out => a_row0_out, --exits right side of the array
        b_out => b_01_11, --goes downwards to PE11

        result => result01
    );

    pe10 : entity work.pe
    port map(
        clk => clk,
        reset => reset,
        enable => enable, 
        a_in => a_row1_in, 
        b_in => b_00_10,
        a_out => a_10_11, 
        b_out => b_col0_out, 

        result => result10
    );

    pe11 : entity work.pe
    port map(
        clk => clk,
        reset => reset,
        enable => enable, 
        a_in => a_10_11, 
        b_in => b_01_11,
        a_out => a_row1_out, 
        b_out => b_col1_out, 

        result => result11
    );


end architecture;