library ieee;
use ieee.std_logic_1164.all;
library lib;
use lib.general.all;

--------------------------------------------------------------------------------
-- CPU: ENEMY ALIEN CONTROLLER
-- This entity asynchronously receives commands (reset/enable) and synchronously
-- updates the positions of the aliens.
--------------------------------------------------------------------------------
entity cpu is
  generic
  (
    res_x                    :    integer := 15;
    res_y                    :    integer := 15;
    pos_x                    :    integer := 11;
    pos_y                    :    integer := 8;
    aux_x                    :    integer := 11;
    aux_y                    :    integer := 8;
    clock_div                :    integer := 4
  );
  port
  (
  reset_i,kill_i     :    in std_logic;

  clock_i, turn_i    :     in std_logic;

  turn_o             :    out std_logic; -- when any alien reaches a side, it sends
                                         -- sends a signal for every alien to change
                                         -- direction.
  enable_o           :    buffer std_logic;
  position_x_o       :    buffer integer range 0 to res_x;
  position_y_o       :    buffer integer range 0 to res_y;

  dying              :    out std_logic; -- exploding animation
  game_over          :    out std_logic
);
end entity;

architecture behavior of cpu is
  -- clock for updating x position
  signal clock_s            :    std_logic;

  type CPU_STATE is (ALIVE, EXPLODING, DEAD);
  signal state : CPU_STATE;

begin
  cpu_clock: clock_counter
  generic map ( clock_div )
  port map ( clock_i, clock_s );

  cpu_movement_x:
  process (reset_i, kill_i, clock_s, enable_o)
    variable move_right_v : std_logic := '1';
  begin        
    if reset_i = '1' then
      position_x_o <= pos_x - aux_x/2;
      position_y_o <= pos_y - aux_y/2;
      --enable_o <= '1';
      move_right_v := '1';
      turn_o <= '0';
      game_over <= '0';
    elsif kill_i = '1' then
      --enable_o <= '0';
      turn_o <= '0';
    else
      if rising_edge(clock_s) and enable_o='1' then
        if position_y_o >= 110 then
          game_over <= '1';

        elsif turn_i = '1' then
          position_y_o <= position_y_o + 10;
          move_right_v := not(move_right_v);
          turn_o <= '0';

        else

          if move_right_v = '1' then
            position_x_o <= position_x_o + 3;
          elsif move_right_v = '0' then
            position_x_o <= position_x_o - 3;
          end if;

          if position_x_o + aux_x > res_x-9 and move_right_v = '1' then
            turn_o <= '1';            
          elsif position_x_o < 9 and move_right_v = '0' then
            turn_o <= '1';
          end if;

        end if;

      end if;
    end if;

  end process;

  -- CPU State Control
  cpu_fsm:
  process (reset_i,clock_s,kill_i)
  begin
    if reset_i = '1' then
      enable_o <= '1';
      dying <= '0';
      state <= ALIVE;
    elsif kill_i = '1' then
      dying <= '1';
      state <= EXPLODING;
    elsif rising_edge(clock_s) then
      case state is 

        when ALIVE =>

        when EXPLODING =>
          enable_o <= '0';
          state <= DEAD;

        when DEAD =>
          dying <= '0';

      end case;
    end if;

  end process;

end architecture;
