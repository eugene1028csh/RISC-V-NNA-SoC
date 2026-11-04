library ieee;
use ieee.std_logic_1164.all;

entity rv32i_core is
    port (
        clk   : in std_logic;
        reset : in std_logic;

        bus_addr       : out std_logic_vector(31 downto 0);
        bus_write_data : out std_logic_vector(31 downto 0);
        bus_write_en   : out std_logic;
        bus_read_data  : in std_logic_vector(31 downto 0);
        bus_hit        : in std_logic;

        nna_boot_pass_i  : in std_logic;
        core_dft_ready_o : out std_logic;

        mbist_pass_o : out std_logic;
        mbist_fail_o : out std_logic;
        alu_lbist_pass_o : out std_logic;
        crc_lbist_pass_o : out std_logic
    );
end entity;

architecture sim_stub of rv32i_core is
    signal cycle_count : integer range 0 to 6 := 0;
    signal boot_reported : std_logic := '0';
begin
    -- Simulated sequential CPU self-test completion
    alu_lbist_pass_o <= '1'
        when cycle_count >= 4 else '0';

    crc_lbist_pass_o <= '1'
        when cycle_count >= 6 else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                cycle_count <= 0;
                boot_reported <= '0';
            else
                if cycle_count < 6 then
                    cycle_count <= cycle_count + 1;
                end if;

                if nna_boot_pass_i = '1'
                   and boot_reported = '0' then
                    report "CPU BOOT RELEASED AFTER NNA BIST";
                    boot_reported <= '1';
                end if;
            end if;
        end if;
    end process;

    mbist_pass_o <= '1' when cycle_count >= 2 else '0';
    mbist_fail_o <= '0';

    core_dft_ready_o <= '1'
        when cycle_count = 6 else '0';

    -- Simulate CPU polling NNA status after boot.
    bus_addr <= x"40000004"
        when nna_boot_pass_i = '1'
        else (others => '0');

    bus_write_data <= (others => '0');
    bus_write_en <= '0';

end architecture;
