library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pe_array_4x4 is
  port (
    clk    : in std_logic;
    reset  : in std_logic;
    enable : in std_logic;

    a_row0_in : in signed(7 downto 0);
    a_row1_in : in signed(7 downto 0);
    a_row2_in : in signed(7 downto 0);
    a_row3_in : in signed(7 downto 0);
    b_col0_in : in signed(7 downto 0);
    b_col1_in : in signed(7 downto 0);
    b_col2_in : in signed(7 downto 0);
    b_col3_in : in signed(7 downto 0);

    a_row0_out : out signed(7 downto 0);
    a_row1_out : out signed(7 downto 0);
    a_row2_out : out signed(7 downto 0);
    a_row3_out : out signed(7 downto 0);
    b_col0_out : out signed(7 downto 0);
    b_col1_out : out signed(7 downto 0);
    b_col2_out : out signed(7 downto 0);
    b_col3_out : out signed(7 downto 0);

    result00 : out signed(31 downto 0);
    result01 : out signed(31 downto 0);
    result10 : out signed(31 downto 0);
    result11 : out signed(31 downto 0);

    result02 : out signed(31 downto 0);
    result03 : out signed(31 downto 0);
    result12 : out signed(31 downto 0);
    result13 : out signed(31 downto 0);

    result20 : out signed(31 downto 0);
    result21 : out signed(31 downto 0);
    result30 : out signed(31 downto 0);
    result31 : out signed(31 downto 0);

    result22 : out signed(31 downto 0);
    result23 : out signed(31 downto 0);
    result32 : out signed(31 downto 0);
    result33 : out signed(31 downto 0)
  );
end entity;

architecture rtl of pe_array_4x4 is
signal a_00_01, a_01_02, a_02_03 : signed(7 downto 0);
signal a_10_11, a_11_12, a_12_13 : signed(7 downto 0);
signal a_20_21, a_21_22, a_22_23 : signed(7 downto 0);
signal a_30_31, a_31_32, a_32_33 : signed(7 downto 0);

signal b_00_10, b_10_20, b_20_30 : signed(7 downto 0);
signal b_01_11, b_11_21, b_21_31 : signed(7 downto 0);
signal b_02_12, b_12_22, b_22_32 : signed(7 downto 0);
signal b_03_13, b_13_23, b_23_33 : signed(7 downto 0);

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

a_in => a_00_01,
b_in => b_col1_in,

a_out => a_01_02,
b_out => b_01_11,

result => result01
);

pe02 : entity work.pe
port map(
clk => clk,
reset => reset, 
enable => enable,

a_in => a_01_02,
b_in => b_col2_in,

a_out => a_02_03,
b_out => b_02_12,

result => result02
);

pe03 : entity work.pe
port map(
clk => clk,
reset => reset, 
enable => enable,

a_in => a_02_03,
b_in => b_col3_in,

a_out => a_row0_out,
b_out => b_03_13,

result => result03
);


pe10 : entity work.pe
port map(
clk => clk,
reset => reset, 
enable => enable,

a_in => a_row1_in,
b_in => b_00_10,

a_out => a_10_11,
b_out => b_10_20,

result => result10
);

pe11 : entity work.pe
port map(
clk => clk,
reset => reset, 
enable => enable,

a_in => a_10_11,
b_in => b_01_11,

a_out => a_11_12,
b_out => b_11_21,

result => result11
);

pe12 : entity work.pe
port map(
clk => clk,
reset => reset, 
enable => enable,

a_in => a_11_12,
b_in => b_02_12,

a_out => a_12_13,
b_out => b_12_22,

result => result12
);

pe13 : entity work.pe
port map(
clk => clk,
reset => reset, 
enable => enable,

a_in => a_12_13,
b_in => b_03_13,

a_out => a_row1_out,
b_out => b_13_23,

result => result13
);

pe20 : entity work.pe
port map(
clk => clk,
reset => reset, 
enable => enable,

a_in => a_row2_in,
b_in => b_10_20,

a_out => a_20_21,
b_out => b_20_30,

result => result20
);

pe21 : entity work.pe
port map(
clk => clk,
reset => reset, 
enable => enable,

a_in => a_20_21,
b_in => b_11_21,

a_out => a_21_22,
b_out => b_21_31,

result => result21
);

pe22 : entity work.pe
port map(
clk => clk,
reset => reset, 
enable => enable,

a_in => a_21_22,
b_in => b_12_22,

a_out => a_22_23,
b_out => b_22_32,

result => result22
);

pe23 : entity work.pe
port map(
clk => clk,
reset => reset, 
enable => enable,

a_in => a_22_23,
b_in => b_13_23,

a_out => a_row2_out,
b_out => b_23_33,

result => result23
);

pe30 : entity work.pe
port map(
clk => clk,
reset => reset, 
enable => enable,

a_in => a_row3_in,
b_in => b_20_30,

a_out => a_30_31,
b_out => b_col0_out,

result => result30
);

pe31 : entity work.pe
port map(
clk => clk,
reset => reset, 
enable => enable,

a_in => a_30_31,
b_in => b_21_31,

a_out => a_31_32,
b_out => b_col1_out,

result => result31
);

pe32 : entity work.pe
port map(
clk => clk,
reset => reset, 
enable => enable,

a_in => a_31_32,
b_in => b_22_32,

a_out => a_32_33,
b_out => b_col2_out,

result => result32
);

pe33 : entity work.pe
port map(
clk => clk,
reset => reset, 
enable => enable,

a_in => a_32_33,
b_in => b_23_33,

a_out => a_row3_out,
b_out => b_col3_out,

result => result33
);







end architecture;