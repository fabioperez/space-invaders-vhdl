library ieee;
use ieee.std_logic_1164.all;

entity clock_counter is
  generic
  (
    f: integer := 50000000
  );
  port
  (
    clock_i: in std_logic;
    clock_o: out std_logic
  );
end entity;

architecture behavior of clock_counter is
begin
  process (clock_i)
    variable counter: integer := 0;
  begin
    if rising_edge(clock_i) then
      if counter < f/2 then
        counter := counter + 1;
        clock_o <= '0';
      elsif counter < f then
        counter := counter + 1;
        clock_o <= '1';
      end if;

      if counter = f then
        counter := 0;
      end if;
    end if;
  end process;
end architecture;
