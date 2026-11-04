library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity soc_top is
  generic (
    SIM_INJECT_NNA_FAULT : boolean := false
  );
  port (
    clk   : in std_logic;
    reset : in std_logic;

    led_n : out std_logic_vector(5 downto 0) --_n means active low
  );
end entity;

architecture rtl of soc_top is

  signal bus_addr       : std_logic_vector(31 downto 0);
  signal bus_write_data : std_logic_vector(31 downto 0);
  signal bus_write_en   : std_logic;

  signal bus_read_data : std_logic_vector(31 downto 0);
  signal bus_hit       : std_logic;

  signal seen_done : std_logic                     := '0';
  signal out_ok    : std_logic_vector(15 downto 0) := (others => '0');
  signal reset_i   : std_logic; --internal active high reest seignal

  signal heartbeat_counter : unsigned(23 downto 0) := (others => '0');
  -- 24-bit counter: bit 23 toggles at  abt 1.61 Hz from the 27 MHz clock
  signal mmio_counter  : unsigned(21 downto 0) := (others => '0');
  signal system_pass   : std_logic;
  signal error_latched : std_logic := '0';

  signal mbist_pass : std_logic;
  signal mbist_fail : std_logic;

  signal debug_value : std_logic_vector(31 downto 0) := (others => '0');

  -- CPU MMIO master
  signal cpu_bus_addr       : std_logic_vector(31 downto 0);
  signal cpu_bus_write_data : std_logic_vector(31 downto 0);
  signal cpu_bus_write_en   : std_logic;

  -- NNA BIST MMIO master
  signal bist_bus_addr       : std_logic_vector(31 downto 0);
  signal bist_bus_write_data : std_logic_vector(31 downto 0);
  signal bist_bus_write_en   : std_logic;

  -- DFT coordination
  signal core_dft_ready         : std_logic;
  signal nna_bist_start         : std_logic := '0';
  signal nna_bist_started       : std_logic := '0';
  signal nna_bist_busy          : std_logic;
  signal nna_bist_done          : std_logic;
  signal nna_bist_pass          : std_logic;
  signal nna_bist_fail          : std_logic;
  signal nna_bist_boot_pass     : std_logic := '0';
  signal nna_bist_fault_latched : std_logic := '0';
  signal nna_read_data          : std_logic_vector(31 downto 0);
  signal alu_lbist_pass         : std_logic;
  signal crc_lbist_pass         : std_logic;

  signal dft_pass_status : std_logic_vector(3 downto 0);

  signal nna_bist_done_latched : std_logic := '0';
  signal dft_status_word       : std_logic_vector(31 downto 0);
  component rv32i_core is
    port (
      clk   : in std_logic;
      reset : in std_logic;

      bus_addr         : out std_logic_vector(31 downto 0);
      bus_write_data   : out std_logic_vector(31 downto 0);
      bus_write_en     : out std_logic;
      nna_boot_pass_i  : in std_logic;
      core_dft_ready_o : out std_logic;
      bus_read_data    : in std_logic_vector(31 downto 0);
      bus_hit          : in std_logic;

      mbist_pass_o     : out std_logic;
      mbist_fail_o     : out std_logic;
      alu_lbist_pass_o : out std_logic;
      crc_lbist_pass_o : out std_logic
    );
  end component;

begin
  -- Unified DFT pass status
  -- Bit 3: NNA
  -- Bit 2: XiCRC
  -- Bit 1: ALU
  -- Bit 0: MBIST

  dft_pass_status <=
    nna_bist_boot_pass &
    crc_lbist_pass &
    alu_lbist_pass &
    mbist_pass;

  dft_status_word <=
    x"000000" &
    nna_bist_boot_pass &
    nna_bist_fault_latched &
    nna_bist_done_latched &
    core_dft_ready &
    dft_pass_status;
  -- synthesis translate_off
  process (clk)
    variable status_checked : boolean := false;
  begin
    if rising_edge(clk) then
      if reset_i = '1' then
        status_checked := false;

      elsif not status_checked then

        -- Healthy NNA BIST
        if nna_bist_boot_pass = '1' then

          assert dft_pass_status = x"F"
          report "Incorrect healthy DFT pass status"
            severity failure;

          assert dft_status_word = x"000000BF"
          report "Incorrect healthy 32-bit DFT status"
            severity failure;

          report "PASS: HEALTHY DFT STATUS = 0x000000BF";
          status_checked := true;

          -- Faulty NNA BIST
        elsif nna_bist_fault_latched = '1' then

          assert dft_pass_status = x"7"
          report "Incorrect faulty DFT pass status"
            severity failure;

          assert dft_status_word = x"00000077"
          report "Incorrect faulty 32-bit DFT status"
            severity failure;

          report "PASS: FAULTY DFT STATUS = 0x00000077";
          status_checked := true;

        end if;
      end if;
    end if;
  end process;

  -- synthesis translate_on
  reset_i <= not reset;

  -- Before NNA BIST passes, BIST owns the MMIO bus.
  -- After passing, ownership transfers to the CPU.

  bus_addr <= bist_bus_addr
    when nna_bist_boot_pass = '0'
    else
    cpu_bus_addr;

  bus_write_data <= bist_bus_write_data
    when nna_bist_boot_pass = '0'
    else
    cpu_bus_write_data;

  bus_write_en <= bist_bus_write_en
    when nna_bist_boot_pass = '0'
    else
    cpu_bus_write_en;

  -- Simulation fault injection: corrupt output 7 during BIST
  bus_read_data <= nna_read_data xor x"00000001"
    when SIM_INJECT_NNA_FAULT
    and nna_bist_boot_pass = '0'
    and bus_addr = x"400000DC"
    else
    nna_read_data;

  cpu_inst : rv32i_core
  port map
  (
    clk   => clk,
    reset => reset_i,

    bus_addr       => cpu_bus_addr,
    bus_write_data => cpu_bus_write_data,
    bus_write_en   => cpu_bus_write_en,

    bus_read_data => bus_read_data,
    bus_hit       => bus_hit,

    nna_boot_pass_i  => nna_bist_boot_pass,
    core_dft_ready_o => core_dft_ready,

    mbist_pass_o     => mbist_pass,
    mbist_fail_o     => mbist_fail,
    alu_lbist_pass_o => alu_lbist_pass,
    crc_lbist_pass_o => crc_lbist_pass
  );

  nna_inst : entity work.nna_mmio_wrapper
    port map
    (
      clk   => clk,
      reset => reset_i,

      bus_addr       => bus_addr,
      bus_write_data => bus_write_data,
      bus_write_en   => bus_write_en,

      bus_read_data => nna_read_data,
      bus_hit       => bus_hit
    );

  bist_inst : entity work.nna_bist_ctrl
    port map
    (
      clk   => clk,
      reset => reset_i,
      start => nna_bist_start,

      busy => nna_bist_busy,
      done => nna_bist_done,
      pass => nna_bist_pass,
      fail => nna_bist_fail,

      bus_addr       => bist_bus_addr,
      bus_write_data => bist_bus_write_data,
      bus_write_en   => bist_bus_write_en,

      bus_read_data => bus_read_data,
      bus_hit       => bus_hit
    );

  --heartbeat counter
  process (clk)
  begin
    if rising_edge(clk) then
      if reset_i = '1' then
        heartbeat_counter <= (others => '0');
      else
        heartbeat_counter <= heartbeat_counter + 1;
      end if;
    end if;
  end process;

  --mmio counter with pulse stretching
  --duration of blink lasts about 100ms 2700000/27000000 = 0.1s, 
  -- 1st elsif loads 2700000 and then 2nd elsif eventually follows, counting down to 0, at that point the LED turns off
  process (clk)
  begin
    if rising_edge(clk) then
      if reset_i = '1' then
        mmio_counter <= (others => '0');
      elsif bus_hit = '1' then
        mmio_counter <= to_unsigned(2700000, mmio_counter'length);
        --pulse stretched, load counter with 2700000 in binary accoridng to mmio_counter bit length
      elsif mmio_counter /= 0 then
        --  /= means not equal to
        mmio_counter <= mmio_counter - 1;
        --one decrement per 27 MHz
      end if;
    end if;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      if reset_i = '1' then
        nna_bist_done_latched  <= '0';
        nna_bist_start         <= '0';
        nna_bist_started       <= '0';
        nna_bist_boot_pass     <= '0';
        nna_bist_fault_latched <= '0';
      else
        -- Default: one-cycle START pulse
        nna_bist_start <= '0';

        -- Start NNA BIST after all CPU self-tests pass
        if core_dft_ready = '1'
          and nna_bist_started = '0' then

          nna_bist_start   <= '1';
          nna_bist_started <= '1';
        end if;

        -- Capture BIST completion
        if nna_bist_done = '1' then
          nna_bist_done_latched <= '1';
          if nna_bist_pass = '1' then
            nna_bist_boot_pass <= '1';
          else
            nna_bist_fault_latched <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then

      if reset_i = '1' then

        seen_done <= '0';

        out_ok <= (others => '0');

        error_latched <= '0';

      else

        if nna_bist_boot_pass = '1' and bus_hit = '1'
          and bus_write_en = '0'
          and bus_addr = x"400000EC" then
          debug_value <= bus_read_data;
        end if;

        -- CPU read STATUS = DONE
        if nna_bist_boot_pass = '1' and bus_hit = '1'
          and bus_write_en = '0'
          and bus_addr = x"40000004"
          and bus_read_data(0) = '1' then

          seen_done <= '1';

        end if;
        -- Only accept outputs after NNA has completed
        if nna_bist_boot_pass = '1'
          and seen_done = '1'
          and bus_hit = '1'
          and bus_write_en = '0' then

          case bus_addr is
            when x"400000C0" =>
              if bus_read_data = x"00000050" then -- 80
                out_ok(0) <= '1';
              else
                error_latched <= '1';
              end if;

            when x"400000C4" =>
              if bus_read_data = x"00000046" then -- 70
                out_ok(1) <= '1';
              else
                error_latched <= '1';
              end if;

            when x"400000C8" =>
              if bus_read_data = x"0000003C" then -- 60
                out_ok(2) <= '1';
              else
                error_latched <= '1';
              end if;

            when x"400000CC" =>
              if bus_read_data = x"00000032" then -- 50
                out_ok(3) <= '1';
              else
                error_latched <= '1';
              end if;
            when x"400000D0" =>
              if bus_read_data = x"000000F0" then -- 240
                out_ok(4) <= '1';
              else
                error_latched <= '1';
              end if;

            when x"400000D4" =>
              if bus_read_data = x"000000D6" then -- 214
                out_ok(5) <= '1';
              else
                error_latched <= '1';
              end if;

            when x"400000D8" =>
              if bus_read_data = x"000000BC" then -- 188
                out_ok(6) <= '1';
              else
                error_latched <= '1';
              end if;

            when x"400000DC" =>
              if bus_read_data = x"000000A2" then -- 162
                out_ok(7) <= '1';
              else
                error_latched <= '1';
              end if;
            when x"400000E0" =>
              if bus_read_data = x"00000190" then -- 400
                out_ok(8) <= '1';
              else
                error_latched <= '1';
              end if;

            when x"400000E4" =>
              if bus_read_data = x"00000166" then -- 358
                out_ok(9) <= '1';
              else
                error_latched <= '1';
              end if;

            when x"400000E8" =>
              if bus_read_data = x"0000013C" then -- 316
                out_ok(10) <= '1';
              else
                error_latched <= '1';
              end if;

            when x"400000EC" =>
              if bus_read_data = x"00000112" then -- 274
                out_ok(11) <= '1';
              else
                error_latched <= '1';
              end if;
            when x"400000F0" =>
              if bus_read_data = x"00000230" then -- 560
                out_ok(12) <= '1';
              else
                error_latched <= '1';
              end if;

            when x"400000F4" =>
              if bus_read_data = x"000001F6" then -- 502
                out_ok(13) <= '1';
              else
                error_latched <= '1';
              end if;

            when x"400000F8" =>
              if bus_read_data = x"000001BC" then -- 444
                out_ok(14) <= '1';
              else
                error_latched <= '1';
              end if;

            when x"400000FC" =>
              if bus_read_data = x"00000182" then -- 386
                out_ok(15) <= '1';
              else
                error_latched <= '1';
              end if;

            when others =>
              null;

          end case;
        end if;

      end if;

    end if;
  end process;

  system_pass <= '1'
    when mbist_pass = '1'
    and seen_done = '1'
    and out_ok = x"FFFF"
    and error_latched = '0'
    and mbist_fail = '0'
    else
    '0';

  led_n(0) <= not system_pass;
  led_n(1) <= not heartbeat_counter(23);
  led_n(2) <= '0' when mmio_counter /= 0 else
  '1';
  led_n(3) <= not seen_done;
  led_n(4) <= not mbist_pass;
  led_n(5) <= not (
  error_latched
  or mbist_fail
  or nna_bist_fault_latched
  );
end architecture;