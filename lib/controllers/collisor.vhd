library ieee;
use ieee.std_logic_1164.all;
library lib;
use lib.general.all;

entity collisor is
    generic
        (
        res_x     :    integer    := 15; -- 
        res_y     :    integer    := 15; -- 
        w         :    integer    := 13;  -- 
        h         :    integer    := 6;   -- 
        clock_div :    integer    := 100
        );
    port
        (
        clock        : in std_logic;
        enable_i     : in std_logic;
        position_x1,
        position_x2  : in integer range 0 to res_x;
        position_y1,
        position_y2  : in integer range 0 to res_y;
        collision_o  : out std_logic
        );
end entity;

architecture behavior of collisor is
    signal clock_slow    :    std_logic;
begin    
    
    -- Divisor de clock
    clock_division: clock_counter
    generic map ( clock_div )
    port map ( clock, clock_slow );
    
    process(clock_slow, enable_i, position_x1, position_y1, position_x2, position_y2)
    begin
        if enable_i = '0' then
            collision_o <= '0';
        elsif rising_edge(clock_slow) then
            collision_o <= '0';
            if     (position_x1 >= position_x2)
                    and (position_x1 < position_x2 + w) 
                    and (position_y1 >= position_y2)
                    and (position_y1 <= position_y2 + h) then
                        collision_o <= '1';
            end if;
        end if;
    end process;
end architecture;
