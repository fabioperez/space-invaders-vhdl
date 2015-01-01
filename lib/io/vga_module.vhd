--------------------------------------------------------------------------------
--                                 WARNING!                                   -- 
-- You have entered the Twilight Zone                                         --
-- Beyond this world strange things are known.                                --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library lib;
use lib.io.all;

-------------------------------------------------------------------------------- 
--                                  VGA MODULE
-------------------------------------------------------------------------------- 
entity vga_module is
  generic (
            RX : integer := 160;             -- Number of horizontal pixels
            RY : integer := 120;             -- Number of vertical pixels
            NUM_OF_ALIENS : integer := 24    -- Number of enemies
          );
  port (
         clk27M         : in std_logic;
         reset          : in std_logic;

  game_state_i          : GAME_STATE;
  nave_x                : integer range 0 to RX; -- ship x coordinate
  nave_y                : integer range 0 to RY; -- ship y coordinate
  nave_d                : std_logic;             -- ship destroy
  tiro_x                : integer range 0 to RX; -- shoot x coordinate
  tiro_y                : integer range 0 to RY; -- shoot y coordinate
  tiro_enemy_x          : integer range 0 to RX; -- enemy shoot x coordinate
  tiro_enemy_y          : integer range 0 to RY; -- enemy shoot y coordinate
  cpu_e                 : std_logic_vector(NUM_OF_ALIENS-1 downto 0);
  cpu_d                 : std_logic_vector(NUM_OF_ALIENS-1 downto 0);
  cpu_x                 : pos_arr_xt;
  cpu_y                 : pos_arr_yt;

  red, green, blue      : out std_logic_vector (3 downto 0);
  hsync, vsync          : out std_logic
);
end entity;

architecture behavior of vga_module is
  component vgacon is
    generic (
              NUM_HORZ_PIXELS : natural := 128;    -- Number of horizontal pixels
              NUM_VERT_PIXELS : natural := 96      -- Number of vertical pixels
            );
    port (
    clk27M, rstn              : in std_logic;
    write_clk, write_enable   : in std_logic;
    write_addr                : in integer range 0 to NUM_HORZ_PIXELS * NUM_VERT_PIXELS - 1;
    data_in                   : in std_logic_vector (2 downto 0);
    red, green, blue          : out std_logic_vector (3 downto 0);
    hsync, vsync              : out std_logic
  );
  end component;

  constant CONS_CLOCK_DIV    : integer := 400000;
  constant HORZ_SIZE         : integer := 160;
  constant VERT_SIZE         : integer := 120;
  constant NUM_HORZ_PIXELS1  : integer := 160;
  constant NUM_VERT_PIXELS1  : integer := 120;

  signal slow_clock      : std_logic;

  signal video_address   : integer range 0 TO HORZ_SIZE * VERT_SIZE - 1;
  signal video_word      : std_logic_vector (2 downto 0);
  signal video_word_s    : std_logic_vector (2 downto 0);

  -- Sprites
  signal inv1, inv2     : std_logic_vector (87 downto 0);
  signal dead_player    : std_logic_vector (119 downto 0);
  signal space_inv      : std_logic_vector (1304 downto 0);
  signal big_alien      : std_logic_vector (2199 downto 0);
  signal you_win        : std_logic_vector (674 downto 0);
  signal game_over      : std_logic_vector (872 downto 0);
  signal dead_inv       : std_logic_vector (87 downto 0);

begin
  vga_component: vgacon
  generic map (
                NUM_HORZ_PIXELS => HORZ_SIZE,
                NUM_VERT_PIXELS => VERT_SIZE
              ) port map (
                           clk27M          => clk27M,
                           rstn            => reset,
                           write_clk       => clk27M,
                           write_enable    => '1',
                           write_addr      => video_address,
                           data_in         => video_word,
                           red             => red,
                           green           => green,
                           blue            => blue,
                           hsync           => hsync,
                           vsync           => vsync        
                         );

              -- Clock Divider
              clock_divider:
              process (clk27M, reset)
                variable i : INTEGER := 0;
              begin
                if (reset = '0') then
                  i := 0;
                  slow_clock <= '0';
                elsif (rising_edge(clk27M)) then
                  if (i <= CONS_CLOCK_DIV/2) then
                    i := i + 1;
                    slow_clock <= '0';
                  elsif (i < CONS_CLOCK_DIV-1) then
                    i := i + 1;
                    slow_clock <= '1';
                  else        
                    i := 0;
                  end if;    
                end if;
              end process;
  ----------------------------------------

  ----------------------------------------
  -- SPRITES
  -- Really, these numbers are sprites!
  ----------------------------------------
  -- Invader
  inv1 <= "0001101100010100000101101111111011111111111101101110110001111111000001000100000100000100";
  inv2 <= "0100000001000100000100011111111100111111111011101110111101111111011001000100100100000100";
  dead_inv <= "1001000100101001010010001000001001100000001100100000100010010100101001000100100000000000";
  -- Dead ship (player)
  dead_player <= "011111111110101001111111100100100010110101000000000110110000001001000000000000001010100000000000000010000000001000000000";

  -- Text: SPACE INVADERS
  space_inv <= "111111111001100000110011111111100001111111001100000110000011000000110000011001100000000000001111111110011111111100110000011000000000110011111111111111111100110000011001111111110000111111100110000011000001100000011000001100110000000000000111111111001111111110011000001100000000011001111111111100000000000100001100000000011001100000110011000001100001101100001100000110011000000000000000000001100000000011001100000110000000001100110000000110000000000010000110000000001100110000011001100000110000110110000110000011001100000000000000000000110000000001100110000011000000000110011000000011111111100111111111000001111110011000001100111111111001100000110011000001100110000000000000000111111000000000110011111111100111111111001111111110000000110011000001100000000011001100000110011000001100110000011001100000110011000000000000000000001100000000011001100000110011000001100000000011000000011001100000110000000001100110000011001100000110011000001100110000011001100000000000000000000110000000001100110000011001100000110000000001111111111100111111111001111111110000111111100111111111001100000110011111111100110000000000000111111111001111111110011111111100111111111001111111111111111110011111111100111111111000011111110011111111100110000011001111111110011000000000000011111111100111111111001111111110011111111100111111111";
  -- Text: YOU WIN
  you_win <= "110000011001111111110011000001100000000000001111111110011111111100000110000110000011001111111110011000001100000000000001111111110011111111100000110000111000011000000100000011110111100000000000001100000110011000001100000110000111000011000000100000011110111100000000000001100000110011000001100000110000110110011000000100000011001001100000000000001100000110011000001100111111111110001111000000100000011000001100000000000001100000110011000001100110000011110001111000000100000011000001100000000000001100000110011000001100110000011110000011001111111110011000001100000000000001100000110011111111100110000011110000011001111111110011000001100000000000001100000110011111111100110000011";
  -- Text: GAME OVER
  game_over <= "110000011001111111110000011000000111111111000000000000011111111100110000011001100000110011111111111000001100111111111000001100000011111111100000000000001111111110011000001100110000011001111111110010000110000000001100001101100001100000110000000000000000000011001100000110011000001100110000011001000011000000000110000110110000110000011000000000000000000001100110000011001100000110011000001111111111100000111111001100000110011000001100000000000000001111110011011001100111111111001111100111100000110000000001100110000011001100000110000000000000000000011001111011110011000001100000000011110000011000000000110011000001100110000011000000000000000000001100111101111001100000110000000001100111111100111111111001100000110011111111100000000000001111111110011000001100111111111001111111110011111110011111111100110000011001111111110000000000000111111111001100000110011111111100111111111";
  -- Big Invader
  big_alien <= "0000011111000000000000000000000000000000000001111100000000001111100000000000000000000000000000000000111110000000000111110000000000000000000000000000000000011111000000000011111000000000000000000000000000000000001111100000000001111100000000000000000000000000000000000111110000000000000001111100000000000000000000000001111100000000000000000000111110000000000000000000000000111110000000000000000000011111000000000000000000000000011111000000000000000000001111100000000000000000000000001111100000000000000000000111110000000000000000000000000111110000000000000001111111111111111111111111111111111111111111110000000000111111111111111111111111111111111111111111111000000000011111111111111111111111111111111111111111111100000000001111111111111111111111111111111111111111111110000000000111111111111111111111111111111111111111111111000001111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111100000111111111111111000001111111111111111111111111111110000011111111111111100000111111111111111111111111111111000001111111111111110000011111111111111111111111111111100000111111111111111000001111111111111111111111111111110000011111111111111100000111111111111111111110000011111111111111111111111111111111111000001111111111000001111111111111111111111111111111111100000111111111100000111111111111111111111111111111111110000011111111110000011111111111111111111111111111111111000001111111111000001111111111111111111111111111111111100000111111111100000000001111100000000000000011111000000000011111111110000000000111110000000000000001111100000000001111111111000000000011111000000000000000111110000000000111111111100000000001111100000000000000011111000000000011111111110000000000111110000000000000001111100000000001111100000000001111100000000000000000000000001111100000000000000000000111110000000000000000000000000111110000000000000000000011111000000000000000000000000011111000000000000000000001111100000000000000000000000001111100000000000000000000111110000000000000000000000000111110000000000";


  vga_fsm:
  process (clk27M)
  begin
    if rising_edge(clk27M) then
      case game_state_i is 

        -- START SCREEN
        when START => 
          video_word <= "000"; 

          -- Text SPACE INVADERS
          if video_address >= 4*HORZ_SIZE AND video_address < (9+4)*HORZ_SIZE then
            if (video_address mod HORZ_SIZE) >= 7 AND (video_address mod HORZ_SIZE) < 145+7 then
              video_word <= (OTHERS => space_inv( (video_address mod 160-7) + 145*(video_address/160-4))) ;                    
            end if;
          -- Big Invader
          elsif video_address >= 40*HORZ_SIZE AND video_address < (40+40)*HORZ_SIZE then
            if (video_address mod HORZ_SIZE) >= 52 AND (video_address mod HORZ_SIZE) < 55+52 then
              video_word <= "0" & big_alien( (video_address mod 160-52) + 55*(video_address/160-40)) & "0" ;                    
            end IF;
          end if;

          video_address <= video_address + 1;

        -- GAME OVER SCREEN
        when GAME_OVER_STATE => 
          video_word <= "000"; 

          -- Text "GAME OVER"
          if video_address >= 4*HORZ_SIZE AND video_address < (9+4)*HORZ_SIZE then
            if (video_address mod HORZ_SIZE) >= 32 AND (video_address mod HORZ_SIZE) < 97+32 then
              video_word <= (OTHERS => game_over( (video_address mod 160-32) + 97*(video_address/160-4))) ;                    
            end if;
          -- Big Invader
          elsif video_address >= 40*HORZ_SIZE AND video_address < (40+40)*HORZ_SIZE then
            if (video_address mod HORZ_SIZE) >= 52 AND (video_address mod HORZ_SIZE) < 55+52 then
              video_word <= big_alien( (video_address mod 160-52) + 55*(video_address/160-40)) & "00" ;                    
            end if;
          end if;

          video_address <= video_address + 1;

        -- WIN SCREEN
        when WIN =>
          video_word <= "000"; 

          -- Text YOU WIN
          if video_address >= 4*HORZ_SIZE AND video_address < (9+4)*HORZ_SIZE then
            if (video_address mod HORZ_SIZE) >= 42 AND (video_address mod HORZ_SIZE) < 75+42 then
              video_word <= (OTHERS => you_win( (video_address mod 160-42) + 75*(video_address/160-4))) ;                    
            end if;
          -- Big Invader
          elsif video_address >= 40*HORZ_SIZE AND video_address < (40+40)*HORZ_SIZE then
            if (video_address mod HORZ_SIZE) >= 52 AND (video_address mod HORZ_SIZE) < 55+52 then
              video_word <= "0" & big_alien( (video_address mod 160-52) + 55*(video_address/160-40)) & "0" ;                    
            end if;
          end if;

          video_address <= video_address + 1;

        when PLAYING =>
          video_word <= "000";
          video_address <= video_address + 1;

          ----------------------------------------
          -- DRAWS THE PLAYER SHOT
          ----------------------------------------
          if (tiro_x + tiro_y > 0) AND (video_address = (tiro_x + tiro_y*HORZ_SIZE) 
          OR video_address = (tiro_x + (tiro_y+1)*HORZ_SIZE) 
          OR video_address = (tiro_x + (tiro_y+2)*HORZ_SIZE))  then
            video_word <= "001";
          end if;
          ----------------------------------------    

          ----------------------------------------
          -- DRAWS THE PLAYER SHIP
          ----------------------------------------
          if nave_d = '1' then
            if video_address >= nave_y*HORZ_SIZE AND video_address < (nave_y+8)*HORZ_SIZE then
              if (video_address mod HORZ_SIZE) >= (nave_x) AND (video_address mod HORZ_SIZE) < nave_x+15 then
                video_word <= '0' & dead_player( (video_address mod 160-nave_x) + 15*(video_address/160-nave_y)) & '0' ;                    
              end if;
            end if;
          else
            if video_address >= (nave_y)*HORZ_SIZE AND video_address < (nave_y+2)*HORZ_SIZE then
              video_word <= "000";
              if (video_address mod HORZ_SIZE) >= (nave_x+4) AND (video_address mod HORZ_SIZE) <= (nave_x+8) then
                video_word <= "010";
              end if;
            elsif video_address >= (nave_y+2)*HORZ_SIZE AND video_address < (nave_y+6)*HORZ_SIZE then
              if (video_address mod HORZ_SIZE) >= (nave_x) AND (video_address mod HORZ_SIZE) <= (nave_x+12) then
                video_word <= "010";
              end if;
            end if;
          end if;
          ----------------------------------------

          ----------------------------------------
          -- DRAWS ENEMY SHIPS
          ----------------------------------------    
          for i in NUM_OF_ALIENS-1 downto 0 loop
            if video_address >= (cpu_y(i))*HORZ_SIZE and video_address < (cpu_y(i)+8)*HORZ_SIZE then
              if (video_address mod HORZ_SIZE) >= (cpu_x(i)) and (video_address mod HORZ_SIZE) <= (cpu_x(i)+10) then
                if cpu_d(i)='1' then
                  video_word <= (others => dead_inv( (video_address mod 160)-cpu_x(i) + 11*(video_address/160 - cpu_y(i)))) ;
                elsif cpu_e(i)='1' then
                  if (cpu_x(i) rem 2) = 0 then
                    video_word <= (others => inv1( (video_address mod 160)-cpu_x(i) + 11*(video_address/160 - cpu_y(i)))) ;
                  else
                    video_word <= (others => inv2( (video_address mod 160)-cpu_x(i) + 11*(video_address/160 - cpu_y(i)))) ;
                  end if;

                end if;
              end if;
            end if;
          end loop;
          ----------------------------------------

          ----------------------------------------
          -- DRAWS ENEMY SHOTS
          ----------------------------------------
          if (tiro_enemy_x + tiro_enemy_y > 0) AND (video_address = (tiro_enemy_x + tiro_enemy_y*HORZ_SIZE)
          OR video_address = (tiro_enemy_x + (tiro_enemy_y+1)*HORZ_SIZE)) then
            video_word <= "100";
          end if;
        ----------------------------------------

        when others =>    

      end case;
    end if;
  end process;

end architecture;
