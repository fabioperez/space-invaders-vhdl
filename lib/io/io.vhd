library ieee;
use ieee.std_logic_1164.all;
library lib;
use lib.io.all;

--------------------------------------------------------------------------------
--                                I/O PACKAGE
--------------------------------------------------------------------------------
package io is    
  constant ALIENS_PER_LINE  : integer := 7;
  constant ALIEN_LINES      : integer := 5;
  type pos_arr_xt is array(ALIENS_PER_LINE*ALIEN_LINES-1 downto 0) of integer range 0 to 160;
  type pos_arr_yt is array(ALIENS_PER_LINE*ALIEN_LINES-1 downto 0) of integer range 0 to 120;
  type GAME_STATE is (START, PLAYING, GAME_OVER_STATE, WIN);

  component kbd_input is
    port
    (
      clock_i     : in std_logic;
      reset_i     : in std_logic;
      hold_i      : in std_logic;

      PS2_DAT     : inout STD_LOGIC;    --    PS2 Data
      PS2_CLK     : inout STD_LOGIC;    --    PS2 Clock

      shot_o      : buffer std_logic;
      move_o      : buffer std_logic;
      control_o   : buffer std_logic_vector(2 downto 0)
    );
  end component;

  component vga_module IS
    generic (
              RX : INTEGER := 160;            -- Number of horizontal pixels
              RY : INTEGER := 120;            -- Number of vertical pixels
              NUM_OF_ALIENS : INTEGER := 24   -- Number of enemies
            );
    port (
            clk27m                : in std_logic;
            reset                 : in std_logic;
            game_state_i          : GAME_STATE;
            nave_x                : INTEGER RANGE 0 TO RX;
            nave_y                : INTEGER RANGE 0 TO RY;
            nave_d                : std_logic; -- nave destroy
            tiro_x                : INTEGER RANGE 0 TO RX;
            tiro_y                : INTEGER RANGE 0 TO RY;
            tiro_enemy_x          : INTEGER RANGE 0 TO RX;
            tiro_enemy_y          : INTEGER RANGE 0 TO RY;
            cpu_e                 : std_logic_vector(NUM_OF_ALIENS-1 downto 0);
            cpu_d                 : std_logic_vector(NUM_OF_ALIENS-1 downto 0);
            cpu_x                 : pos_arr_xt;
            cpu_y                 : pos_arr_yt;
            red, green, blue     : out std_logic_vector (3 downto 0);
            hsync, vsync         : out std_logic
  );
  end component;

end package;
