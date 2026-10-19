library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pe_chain_2 is
    port(
    clk : in std_logic;
    reset : in std_logic;
    enable : in std_logic;
    a_in : in signed (7 downto 0);
    b_in : in signed (7 downto 0);
    a_out : out signed (7 downto 0);
    b_out : out signed (7 downto 0);
    result0 : out signed (31 downto 0);
    result1 : out signed (31 downto 0)
    );
end entity pe_chain_2;

architecture rtl of pe_chain_2 is
    signal a_link : signed (7 downto 0); --PE0 a_out ---> a_link ---> PE1 a_in
    signal b_link : signed (7 downto 0); --PE0 b_out ---> b_link ---> PE1 b_in

    begin

        --No clocked process is needed in pe_chain_2.vhd, because each PE already contains its own registers.
        
        pe0 : entity work.pe
        port map(
            clk => clk,
            reset => reset,
            enable => enable,

            a_in => a_in,
            b_in => b_in,
            a_out => a_link,
            b_out => b_link,

            result => result0
        );

        pe1 : entity work.pe
        port map(
            clk => clk,
            reset => reset,
            enable => enable,

            a_in => a_link,
            b_in => b_link,
            a_out => a_out,
            b_out => b_out,

            result => result1
        );
    end architecture;