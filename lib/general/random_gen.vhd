library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library lib;
use lib.general.all;

entity random_gen is
  generic(
           N    : integer := 24
         );
  port(
        input   : in std_logic;
        clock   : in std_logic;
        output  : out integer
      );
end random_gen;

architecture behavior of random_gen is
  signal clock_s   : std_logic;
  signal counter_s : integer;
begin

  clock_div2: clock_counter
  generic map (100)
  port map (clock, clock_s);

  contador:     
  process(clock)
  begin
    if rising_edge(clock) then
      counter_s <= counter_s + 1;
      if input = '1' then
        output <= (counter_s mod N);
      end if;
    end if;
  end process;

end behavior;
