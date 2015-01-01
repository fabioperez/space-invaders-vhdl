library ieee;
use ieee.std_logic_1164.all;

package general is
  component clock_counter is
    generic
    (
      f: integer := 50000000
    );
    port
    (
      clock_i: in std_logic;
      clock_o: out std_logic
    );
  end component;

  component random_gen is
    generic(
             N  :    integer := 24
           );
    port
    (
      input     :    in std_logic;
      clock     :    in std_logic;
      output    :    out integer
    );
  end component;

  component conv_7seg is
    port
    (
      digit: in std_logic_vector(3 downto 0);
      seg: out std_logic_vector(6 downto 0)
    );
  end component;

  component conv_7seg_int is
    port
    (
      digit: in integer;
      seg: out std_logic_vector(6 downto 0)
    );
  end component;
end package;
