library ieee;
use ieee.std_logic_1164.all;

package controller is
  component pc is
    generic
    (
      res_x       : integer := 15;
      res_y       : integer := 15;
      aux_y       : integer := 0;
      aux_x       : integer := 0;
      pos_y       : integer := 5;
      clock_div   : integer := 2
    );
    port
    (
    reset_i, enable_i : in std_logic;
    right_flag_i      : in std_logic;
    clock_i           : in std_logic;
    clock_o           : out std_logic;
    position_x_o      : buffer integer range 0 to res_x;
    position_y_o      : out integer range 0 to res_y
  );
  end component;

  component cpu is
    generic
    (
      res_x      : integer := 15;
      res_y      : integer := 15;
      pos_x      : integer := 10;
      pos_y      : integer := 10;
      aux_x      : integer := 0;
      aux_y      : integer := 0;
      clock_div  : integer := 4
    );
    port
    (
    reset_i, kill_i     :       in std_logic;

    clock_i,turn_i      :       in std_logic;

    -- position of player's ship
    turn_o       : out std_logic;
    enable_o     : out std_logic;
    position_x_o : out integer range 0 to res_x;
    position_y_o : out integer range 0 to res_y;

    dying        : out std_logic;
    game_over    : out std_logic
  );
  end component;

  component shot is
    generic
    (
      res_x     : integer     := 15;
      res_y     : integer     := 15;
      aux_y     : integer     := 0;
      aux_x     : integer     := 0;
      flag_up   : std_logic   := '1';
      clock_div : integer     := 2
    );
    port
    (
    clock_i,
    reset_i,
    trigger_i     : std_logic;
    position_x_i  : in integer range 0 to res_x;
    position_y_i  : in integer range 0 to res_y;
    enable_o      : buffer std_logic;
    position_x_o  : buffer integer range 0 to res_x;
    position_y_ox : buffer integer range 0 to res_y
  );
  end component;

  component collisor is
    generic
    (
      res_x     : integer := 15;
      res_y     : integer := 15; 
      w         : integer := 2; 
      h         : integer := 2; 
      clock_div : integer := 100
    );
    port 
    (
      clock: in std_logic;
      enable_i: in std_logic;
    position_x1,
    position_x2: in integer range 0 to res_x;
    position_y1,
    position_y2: in integer range 0 to res_y;
    collision_o: out std_logic
  );
  end component;

  component score is
    port
    (
    clock_i,reset_i: in std_logic;
    score_o: out std_logic_vector(27 downto 0)
  );
  end component;

end package;
