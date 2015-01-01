library ieee;
use ieee.std_logic_1164.all;
library lib;
use lib.general.all;

--------------------------------------------------------------------------------
-- SHOT CONTROLLING ENTITY
--------------------------------------------------------------------------------
entity shot is
  generic
  (
    res_x                    :    integer     := 15;
    res_y                    :    integer     := 15;
    aux_x                    :    integer     := 0;
    aux_y                    :    integer     := 0;
    flag_up                  :    std_logic   := '1';
    clock_div                :    integer     := 1
  );
  port
  (
  clock_i,
  reset_i,
  trigger_i     :    in std_logic;
  position_x_i  : in integer range 0 to res_x;
  position_y_i  : in integer range 0 to res_y;
  enable_o      : buffer std_logic;
  position_x_o  : buffer integer range 0 to res_x;
  position_y_o  : buffer integer range 0 to res_y
);
end entity;

architecture behavior of shot is
  signal clock_s: std_logic;
begin        
  shot_clock: clock_counter
  generic map ( clock_div )
  port map ( clock_i, clock_s );    

  shot_movement:
  process (reset_i, trigger_i, clock_s, position_y_i, position_x_i)
    variable trigger_v: std_logic := '0';
  begin
    trigger_v := trigger_i;
    if reset_i = '1' then
      enable_o <= '0';
      trigger_v := '0';
      position_y_o <= position_y_i;
      position_x_o <= position_x_i+aux_x/2;

    elsif rising_edge(clock_s) then

      -- If triggered and there is no bullet in the screen
      if trigger_v = '1' and enable_o = '0' then
        enable_o <= '1';
        trigger_v := '0';
        position_y_o <= position_y_i;
        position_x_o <= position_x_i+aux_x/2;

      -- If the bullet is enabled
      elsif enable_o = '1' and position_y_o > 0 and position_y_o < res_y then
        -- player shoot
        if flag_up = '1' then 
          position_y_o <= position_y_o - 1;
          if position_y_o < 4 then
            enable_o <= '0';
          end if;
        -- enemy shoot
        else
          position_y_o <= position_y_o + 1;
          if position_y_o = res_y then
            enable_o <= '0';
          end if;
        end if;


      elsif trigger_v = '0' then
        position_x_o <= 0; --
        position_y_o <= 0;
        enable_o <= '0';
      else
        position_x_o <= position_x_i+aux_x/2; --
        position_y_o <= position_y_i; --
      end if;
    end if;

  end process;
end architecture;
