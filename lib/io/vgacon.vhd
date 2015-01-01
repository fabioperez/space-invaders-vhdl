-------------------------------------------------------------------------------
-- Title      : VGA Controller for DE1 boards
-- Project    : 
-------------------------------------------------------------------------------
-- File       : vgacontop.vhd
-- Author     : Rafael Auler
-- Company    : 
-- Created    : 2010-03-21
-- Last update: 2010-03-26
-- Platform   : 
-- Standard   : VHDL'2008
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2010 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2010-03-21  1.0      Rafael Auler	Created
-- 2010-03-26  1.1      Rafael Auler    Working 64x60 display w/ internal mem.
-- 2010-03-26  1.2      Rafael Auler    Working with arbitrary res. (up to
--                                      640x480, tied to on-chip memory
--                                      availability). Defaults to 128x96.
-------------------------------------------------------------------------------


-- How sync signals are generated for 640x480
-- Note: sync signals are active low
-------------------------------------------------------------------------------
-- Horizontal sync:
-- -------------------__--------

--              |    |  |      |
-- <----------->
--    640
-- <---------------->
--    660
-- <------------------->
--    756
-- <-------------------------->
--    800
-------------------------------------------------------------------------------
-- Vertical sync:
-- -----------------__-------
--
--            |    |  |     |
-- <--------->
--    480
-- <-------------->
--    494
-- <----------------->
--    495
-- <----------------------->
--    525
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Notes:
-- write_clk, write_addr, write_enable and data_in are input signals used to
-- write to this controller memory and thus altering the displayed image on VGA.
--
-- "data_in" has 3 bits and represents a single image pixel.
-- (high bit for RED, middle for GREEN and lower for BLUE - total of 8 colors).
--
-- These signals follow simple memory write protocol (we=1 writes
-- data_in to address (pixel number) write_addr. This last signal may assume
-- NUM_HORZ_PIXELS * NUM_VERT_PIXELS different values, corresponding to each
-- one of the displayable pixels.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity vgacon is
  generic (
    --  When changing this, remember to keep 4:3 aspect ratio
    --  Must also keep in mind that our native resolution is 640x480, and
    --  you can't cross these bounds (although you will seldom have enough
    --  on-chip memory to instantiate this module with higher res).
    NUM_HORZ_PIXELS : natural := 128;  -- Number of horizontal pixels
    NUM_VERT_PIXELS : natural := 96);  -- Number of vertical pixels
  
  port (
    clk27M, rstn              : in  std_logic;
    write_clk, write_enable   : in  std_logic;
    write_addr                : in  integer range 0 to
                                  NUM_HORZ_PIXELS * NUM_VERT_PIXELS - 1;
    data_in                   : in  std_logic_vector(2 downto 0);
    vga_clk                   : buffer std_logic;       -- Ideally 25.175 MHz
    red, green, blue          : out std_logic_vector(3 downto 0);
    hsync, vsync              : out std_logic);
end vgacon;

architecture behav of vgacon is
  -- Two signals: one is delayed by one clock cycle. The monitor control uses
  -- the delayed one. We need a counter 1 clock cycle earlier, relative
  -- to the monitor signal, in order to index the memory contents 
  -- for the next cycle, when the pixel is in fact sent to the monitor.
  signal h_count, h_count_d : integer range 0 to 799;  -- horizontal counter
  signal v_count, v_count_d : integer range 0 to 524;  -- vertical counter
  -- We only want to address HORZ*VERT pixels in memory
  signal read_addr : integer range 0 to NUM_HORZ_PIXELS * NUM_VERT_PIXELS - 1;
  signal h_drawarea, v_drawarea, drawarea : std_logic;
  signal data_out : std_logic_vector(2 downto 0);
begin  -- behav

  -- This is our PLL (Phase Locked Loop) to divide the DE1 27 MHz
  -- clock and produce a 25.2MHz clock adequate to our VGA controller
  divider: work.vga_pll port map (clk27M, vga_clk);

  -- This is our dual clock RAM. We use our VGA clock to read contents from
  -- memory (pixel color value). The user of this module may use any clock
  -- to write contents to this memory, modifying pixels individually.
  vgamem : work.dual_clock_ram
  generic map (
    MEMSIZE => NUM_HORZ_PIXELS * NUM_VERT_PIXELS)
  port map (
    read_clk       => vga_clk,
    write_clk      => write_clk,
    read_address   => read_addr,
    write_address  => write_addr,
    data_in        => data_in,
    data_out       => data_out,
    we             => write_enable);

  -- purpose: Increments the current horizontal position counter
  -- type   : sequential
  -- inputs : vga_clk, rstn
  -- outputs: h_count, h_count_d
  horz_counter: process (vga_clk, rstn)
  begin  -- process horz_counter
    if rstn = '0' then                  -- asynchronous reset (active low)
      h_count <= 0;
      h_count_d <= 0;
    elsif vga_clk'event and vga_clk = '1' then  -- rising clock edge
      h_count_d <= h_count;             -- 1 clock cycle delayed counter
      if h_count = 799 then
        h_count <= 0;
      else
        h_count <= h_count + 1;
      end if;
    end if;
  end process horz_counter;

  -- purpose: Determines if we are in the horizontal "drawable" area
  -- type   : combinational
  -- inputs : h_count_d
  -- outputs: h_drawarea
  horz_sync: process (h_count_d)
  begin  -- process horz_sync
    if h_count_d < 640 then
      h_drawarea <= '1';
    else
      h_drawarea <= '0';
    end if;
  end process horz_sync;

  -- purpose: Increments the current vertical counter position
  -- type   : sequential
  -- inputs : vga_clk, rstn
  -- outputs: v_count, v_count_d
  vert_counter: process (vga_clk, rstn)
  begin  -- process vert_counter
    if rstn = '0' then              -- asynchronous reset (active low)
      v_count <= 0;
      v_count_d <= 0;
    elsif vga_clk'event and vga_clk = '1' then  -- rising clock edge
      v_count_d <= v_count;             -- 1 clock cycle delayed counter
      if h_count = 699 then
        if v_count = 524 then
          v_count <= 0;
        else
          v_count <= v_count + 1;  
        end if;          
      end if;
    end if;
  end process vert_counter;

  -- purpose: Updates information based on vertical position
  -- type   : combinational
  -- inputs : v_count_d
  -- outputs: v_drawarea
  vert_sync: process (v_count_d)
  begin  -- process vert_sync
    if v_count_d < 480 then
      v_drawarea <= '1';
    else
      v_drawarea <= '0';
    end if;
  end process vert_sync;

  -- purpose: Generates synchronization signals
  -- type   : combinational
  -- inputs : v_count_d, h_count_d
  -- outputs: hsync, vsync
  sync: process (v_count_d, h_count_d)
  begin  -- process sync
    if (h_count_d >= 659) and (h_count_d <= 755) then
      hsync <= '0';
    else
      hsync <= '1';
    end if;
    if (v_count_d >= 493) and (v_count_d <= 494) then
      vsync <= '0';
    else
      vsync <= '1';
    end if;
  end process sync;

  -- determines whether we are in drawable area on screen a.t.m.
  drawarea <= v_drawarea and h_drawarea;

  -- purpose: calculates the controller memory address to read pixel data
  -- type   : combinational
  -- inputs : h_count, v_count
  -- outputs: read_addr
  gen_r_addr: process (h_count, v_count)
  begin  -- process gen_r_addr
    read_addr <= h_count / (640 / NUM_HORZ_PIXELS)
                 + ((v_count/(480 / NUM_VERT_PIXELS))
                    * NUM_HORZ_PIXELS);    
  end process gen_r_addr;

  -- Build color signals based on memory output and "drawarea" signal
  -- (if we are not in the drawable area of 640x480, must deassert all
  --  color signals).
  red   <= (others => data_out(2) and drawarea);
  green <= (others => data_out(1) and drawarea);
  blue  <= (others => data_out(0) and drawarea);

end behav;


-------------------------------------------------------------------------------
-- The following entity is a dual clock RAM (read operates at different
-- clock from write). This is used to isolate two clock domains. The first
-- is the 25.2 MHz clock domain in which our VGA controller needs to operate.
-- This is the read clock, because we read from this memory to determine
-- the color of a pixel. The second is the clock domain of the user of this
-- module, writing in the memory the contents it wants to display in the VGA.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity dual_clock_ram is

  generic (
    MEMSIZE : natural);  
  port (
    read_clk, write_clk         : in  std_logic;  -- support different clocks
    data_in                     : in  std_logic_vector(2 downto 0);
    write_address, read_address : in  integer range 0 to MEMSIZE - 1;  
    we                          : in  std_logic;  -- write enable
    data_out                    : out std_logic_vector(2 downto 0));

end dual_clock_ram;

architecture behav of dual_clock_ram is
  -- we only want to address (store) MEMSIZE elements 
  subtype addr is integer range 0 to MEMSIZE - 1;
  type mem is array (addr) of std_logic_vector(2 downto 0);
  signal ram_block : mem;
  -- we don't care with read after write behavior (whether ram reads
  -- old or new data in the same cycle).
  attribute ramstyle : string;
  attribute ramstyle of dual_clock_ram : entity is "no_rw_check";
  --attribute ram_init_file : string;
  --attribute ram_init_file of ram_block : signal is "vga_mem.mif";

begin  -- behav

  -- purpose: Reads data from RAM
  -- type   : sequential
  -- inputs : read_clk, read_address
  -- outputs: data_out
  read: process (read_clk)
  begin  -- process read
    if read_clk'event and read_clk = '1' then  -- rising clock edge
      data_out <= ram_block(read_address);      
    end if;
  end process read;

  -- purpose: Writes data to RAM
  -- type   : sequential
  -- inputs : write_clk, write_address
  -- outputs: ram_block
  write: process (write_clk)
  begin  -- process write
    if write_clk'event and write_clk = '1' then  -- rising clock edge
      if we = '1' then
        ram_block(write_address) <= data_in;
      end if;      
    end if;
  end process write;

end behav;

-------------------------------------------------------------------------------
-- The following entity is automatically generated by Quartus (a megafunction).
-- As Altera DE1 board does not have a 25.175 MHz, but a 27 Mhz, we
-- instantiate a PLL (Phase Locked Loop) to divide out 27 MHz clock
-- and reach a satisfiable 25.2MHz clock for our VGA controller (14/15 ratio)
-------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.all;

ENTITY vga_pll IS
	PORT
	(
		inclk0		: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC 
	);
END vga_pll;


ARCHITECTURE SYN OF vga_pll IS

	SIGNAL sub_wire0	: STD_LOGIC_VECTOR (5 DOWNTO 0);
	SIGNAL sub_wire1	: STD_LOGIC ;
	SIGNAL sub_wire2	: STD_LOGIC ;
	SIGNAL sub_wire3	: STD_LOGIC_VECTOR (1 DOWNTO 0);
	SIGNAL sub_wire4_bv	: BIT_VECTOR (0 DOWNTO 0);
	SIGNAL sub_wire4	: STD_LOGIC_VECTOR (0 DOWNTO 0);



	COMPONENT altpll
	GENERIC (
		clk0_divide_by		: NATURAL;
		clk0_duty_cycle		: NATURAL;
		clk0_multiply_by		: NATURAL;
		clk0_phase_shift		: STRING;
		compensate_clock		: STRING;
		inclk0_input_frequency		: NATURAL;
		intended_device_family		: STRING;
		lpm_hint		: STRING;
		lpm_type		: STRING;
		operation_mode		: STRING;
		port_activeclock		: STRING;
		port_areset		: STRING;
		port_clkbad0		: STRING;
		port_clkbad1		: STRING;
		port_clkloss		: STRING;
		port_clkswitch		: STRING;
		port_configupdate		: STRING;
		port_fbin		: STRING;
		port_inclk0		: STRING;
		port_inclk1		: STRING;
		port_locked		: STRING;
		port_pfdena		: STRING;
		port_phasecounterselect		: STRING;
		port_phasedone		: STRING;
		port_phasestep		: STRING;
		port_phaseupdown		: STRING;
		port_pllena		: STRING;
		port_scanaclr		: STRING;
		port_scanclk		: STRING;
		port_scanclkena		: STRING;
		port_scandata		: STRING;
		port_scandataout		: STRING;
		port_scandone		: STRING;
		port_scanread		: STRING;
		port_scanwrite		: STRING;
		port_clk0		: STRING;
		port_clk1		: STRING;
		port_clk2		: STRING;
		port_clk3		: STRING;
		port_clk4		: STRING;
		port_clk5		: STRING;
		port_clkena0		: STRING;
		port_clkena1		: STRING;
		port_clkena2		: STRING;
		port_clkena3		: STRING;
		port_clkena4		: STRING;
		port_clkena5		: STRING;
		port_extclk0		: STRING;
		port_extclk1		: STRING;
		port_extclk2		: STRING;
		port_extclk3		: STRING
	);
	PORT (
			inclk	: IN STD_LOGIC_VECTOR (1 DOWNTO 0);
			clk	: OUT STD_LOGIC_VECTOR (5 DOWNTO 0)
	);
	END COMPONENT;

BEGIN
	sub_wire4_bv(0 DOWNTO 0) <= "0";
	sub_wire4    <= To_stdlogicvector(sub_wire4_bv);
	sub_wire1    <= sub_wire0(0);
	c0    <= sub_wire1;
	sub_wire2    <= inclk0;
	sub_wire3    <= sub_wire4(0 DOWNTO 0) & sub_wire2;

	altpll_component : altpll
	GENERIC MAP (
		clk0_divide_by => 15,
		clk0_duty_cycle => 50,
		clk0_multiply_by => 14,
		clk0_phase_shift => "0",
		compensate_clock => "CLK0",
		inclk0_input_frequency => 37037,
		intended_device_family => "Cyclone II",
		lpm_hint => "CBX_MODULE_PREFIX=vga_pll",
		lpm_type => "altpll",
		operation_mode => "NORMAL",
		port_activeclock => "PORT_UNUSED",
		port_areset => "PORT_UNUSED",
		port_clkbad0 => "PORT_UNUSED",
		port_clkbad1 => "PORT_UNUSED",
		port_clkloss => "PORT_UNUSED",
		port_clkswitch => "PORT_UNUSED",
		port_configupdate => "PORT_UNUSED",
		port_fbin => "PORT_UNUSED",
		port_inclk0 => "PORT_USED",
		port_inclk1 => "PORT_UNUSED",
		port_locked => "PORT_UNUSED",
		port_pfdena => "PORT_UNUSED",
		port_phasecounterselect => "PORT_UNUSED",
		port_phasedone => "PORT_UNUSED",
		port_phasestep => "PORT_UNUSED",
		port_phaseupdown => "PORT_UNUSED",
		port_pllena => "PORT_UNUSED",
		port_scanaclr => "PORT_UNUSED",
		port_scanclk => "PORT_UNUSED",
		port_scanclkena => "PORT_UNUSED",
		port_scandata => "PORT_UNUSED",
		port_scandataout => "PORT_UNUSED",
		port_scandone => "PORT_UNUSED",
		port_scanread => "PORT_UNUSED",
		port_scanwrite => "PORT_UNUSED",
		port_clk0 => "PORT_USED",
		port_clk1 => "PORT_UNUSED",
		port_clk2 => "PORT_UNUSED",
		port_clk3 => "PORT_UNUSED",
		port_clk4 => "PORT_UNUSED",
		port_clk5 => "PORT_UNUSED",
		port_clkena0 => "PORT_UNUSED",
		port_clkena1 => "PORT_UNUSED",
		port_clkena2 => "PORT_UNUSED",
		port_clkena3 => "PORT_UNUSED",
		port_clkena4 => "PORT_UNUSED",
		port_clkena5 => "PORT_UNUSED",
		port_extclk0 => "PORT_UNUSED",
		port_extclk1 => "PORT_UNUSED",
		port_extclk2 => "PORT_UNUSED",
		port_extclk3 => "PORT_UNUSED"
	)
	PORT MAP (
		inclk => sub_wire3,
		clk => sub_wire0
	);



END SYN;
