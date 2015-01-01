library ieee;
use ieee.std_logic_1164.all;
library lib;
use lib.general.all;

--------------------------------------------------------------------------------
--                               PLAYER CONTROLLER
--------------------------------------------------------------------------------
-- TODO:
-- Remove output clock_o;
-- Define constants/generics instead of magic numbers
-- Change aux_x/aux_y to something more explanatory
--------------------------------------------------------------------------------
entity pc is
    generic
        (
            -- screen limits (follows game resolution)
            res_x           :    integer := 160;
            res_y           :    integer := 120;
            
            -- used to take into account the dimensions of the ship 
            aux_y           :    integer := 0;
            aux_x           :    integer := 1;
            
            -- y-position of the player ship
            pos_y           :    integer := 5;
            
            -- clock divider
            clock_div       :    integer := 2
        );
    port
        (
        -- input commands for reset or movement
        reset_i, enable_i   :    in std_logic;
        
        -- movement direction ('0' = left, 1' = right)
        right_flag_i        :    in std_logic;
        
        -- clock input
        clock_i             :     in std_logic;
        
        -- player position output
        clock_o             :    out std_logic; -- TODO: remove
        position_x_o        :    buffer integer range 0 to res_x;
        position_y_o        :    out integer range 0 to res_y
        );
end entity;

architecture behavior of pc is
    -- clock signal for updating x position
    signal clock_s            :    std_logic;
begin
    -- counter that generates the clock signal for updating x position
    pc_clock: clock_counter
        generic map ( clock_div )
        port map ( clock_i, clock_s );

    -- register: keeps the position of the player ship
    pc_movement:
        process (reset_i, enable_i,clock_s)
        begin
            -- asynchronous reset of x coordinate
            if reset_i = '1' then
                position_x_o <= res_x/2 - aux_x/2;
            else
            
            -- move the ship according to right_flag_i input
            if rising_edge(clock_s) and enable_i ='1'  then
                if right_flag_i = '1' then
                    position_x_o <= position_x_o + 1; -- move right
                elsif right_flag_i = '0' then
                    position_x_o <= position_x_o - 1; -- move left
                end if;
                
                -- check boundaries
                if position_x_o + aux_x > res_x-5 then
                    position_x_o <= res_x-aux_x-5;
                end if;
                
                if position_x_o < 5 then
                    position_x_o <= 5;
                end if;
            end if;
            end if;
        end process;

    -- updates output position with new y-position
    position_y_o <= pos_y + aux_y/2;
    
end architecture;
