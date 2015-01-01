library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
library lib;
use lib.controller.all;
use lib.general.all;
use lib.io.all;

entity spaceinvaders is
    generic
    (
        rx          : integer := 160;             -- H resolution
        ry          : integer := 120;             -- W resolution
        cpu_num     : integer := ALIENS_PER_LINE; -- aliens per line (set in io.vhd)
        cpu_lines   : integer := ALIEN_LINES;     -- number of lines (set in io.vhd)
        py          : integer := 110;             -- 
        alien_w     : integer := 11;              -- enemy width
        alien_h     : integer := 8;               -- enemy height
        player_w    : integer := 13;              -- player width
        player_h    : integer := 6                -- player height
    );
    port
    (
        ------------------------    Clock Input         ------------------------
        CLOCK_24    :     in    STD_LOGIC_VECTOR (1 downto 0);        --    24 MHz
        CLOCK_50    :     in    STD_LOGIC;                            --    50 MHz
        CLOCK_27    :     in    STD_LOGIC;                            --    27 MHz
        
        ------------------------    Push Button        ------------------------
        KEY     :        in    STD_LOGIC_VECTOR (3 downto 0);        --    Pushbutton[3:0]
        
        ------------------------    7-SEG Display    ------------------------
        HEX0     :        out    STD_LOGIC_VECTOR (6 downto 0); 
        HEX1     :        out    STD_LOGIC_VECTOR (6 downto 0);
        HEX2     :        out    STD_LOGIC_VECTOR (6 downto 0);
        HEX3     :        out    STD_LOGIC_VECTOR (6 downto 0);
        
        ----------------------------    LED        ----------------------------
        LEDG     :        out    STD_LOGIC_VECTOR (7 downto 0);        --    LED Green[7:0]
                    
        ------------------------    PS2        --------------------------------
        PS2_DAT     :        inout    STD_LOGIC;        --    PS2 Data
        PS2_CLK        :        inout    STD_LOGIC;        --    PS2 Clock
        
        ------------------------    VGA        --------------------------------
        VGA_R, VGA_G, VGA_B     : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        VGA_HS, VGA_VS        : OUT STD_LOGIC
        );
end entity;

architecture Behavior of spaceinvaders is
    --------------------------- CLK/RESET ------------------------------
    signal     clock_s,reset_s,reset:    std_logic;
    
    SIGNAL state : GAME_STATE;
    
    ------------------------    PLAYER        ----------------------------
    signal    move_s,shot_s,shot_e_s:    std_logic;    
    signal    controls:         std_logic_vector(2 downto 0);
    signal    position_x_s:     integer range 0 to rx;
    signal    position_y_s:     integer range 0 to ry;
    signal    shot_y_s:        integer range 0 to ry;
    signal    shot_x_s:        integer range 0 to rx;
    signal    shot_r_s:        std_logic;
    
    ------------------------    CPU        --------------------------------
    signal    cpu_arr_x:    pos_arr_xt;
    signal    cpu_arr_y:    pos_arr_yt;
    
    signal    cpu_arr_e:        std_logic_vector(cpu_num*cpu_lines-1 downto 0);
    signal    cpu_arr_c:        std_logic_vector(cpu_num*cpu_lines-1 downto 0);
    signal    cpu_arr_m:        std_logic_vector(cpu_num*cpu_lines-1 downto 0);
    signal    cpu_arr_d:        std_logic_vector(cpu_num*cpu_lines-1 downto 0);
    signal    cpu_game_over:    std_logic_vector(cpu_num*cpu_lines-1 downto 0);
    signal    turn:    std_logic;
    
    signal    shot_enemy_y_s:        integer range 0 to ry;
    signal    shot_enemy_x_s:        integer range 0 to rx;
    signal    shot_enemy_e_s:        std_logic;
    signal    shot_enemy_r_s:        std_logic;
    signal    enemy_shooting:        std_logic;
    signal    clk_enemy_shoot:       std_logic;
    
    signal player_death, player_reset    :        std_logic;
    signal player_death_by_alien        :        std_logic;
    signal player_exploding,pc_dead_delay                :         std_logic;
    type PC_STATE_TYPE is (ALIVE, EXPLODING, DEAD);
    signal pc_state : PC_STATE_TYPE;
    signal game_over,game_over_by_lives    : std_logic;
    signal game_win : std_logic;
            
    ------------------------    HEX        --------------------------------            
    signal     hex_s: std_logic_vector(27 downto 0);
    signal     rnd_s,cmb_s: integer;
    signal     choosen_enemy : integer;
    
    type       hex_arr_t is array(cpu_num-1 downto 0) of std_logic_vector(6 downto 0);
    signal     hex0_arr,hex1_arr,hex2_arr,hex3_arr: hex_arr_t;

    signal lives : natural range 0 to 4 := 4;

begin
    ----------------------------------------------------------------
    -- Game reset
    ----------------------------------------------------------------
    reset <= not(KEY(0)); -- Push Button 0
    ----------------------------------------------------------------

    ----------------------------------------------------------------
    -- Keyboard control
    ----------------------------------------------------------------
    control: kbd_input
    port map
        ( CLOCK_24(0), not(reset_s), KEY(1), PS2_DAT, PS2_CLK, SHOT_S, MOVE_S, CONTROLS );
    ----------------------------------------------------------------
    
    ----------------------------------------------------------------    
    -- VGA
    ----------------------------------------------------------------
    vga: vga_module
    generic map (
        rx,
        ry,
        cpu_num*cpu_lines
    )
    port map
    (
        CLOCK_27, NOT(reset),
        state,
        POSITION_X_S,
        POSITION_Y_S,
        player_exploding,
        SHOT_X_S,
        SHOT_Y_S,
        shot_enemy_x_s,
        shot_enemy_y_s,
        cpu_arr_e,
        cpu_arr_d,
        cpu_arr_x,
        cpu_arr_y,
        
        VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS
    );
    ----------------------------------------------------------------
    
    ----------------------------------------------------------------    
    -- Player
    ----------------------------------------------------------------
    -- Player controller
    player: pc
    generic map
        (
            clock_div => 1000000,
            res_x=>rx,
            res_y=>ry,
            aux_x=>player_w,
            aux_y=>player_h,
            pos_y=>py
        )
    port map
        ( reset_s OR player_reset, move_s and not(player_exploding), controls(0), CLOCK_50, clock_s, position_x_s, position_y_s);

    --    Player shot
    pc_shooter: shot
    generic map
        (
            clock_div => 500000,
            res_x=>rx,
            res_y=>ry,
            aux_x=>player_w,
            aux_y=>player_h
        )
    port map
        (CLOCK_50, reset_s or shot_r_s, shot_s and not(player_exploding), position_x_s, position_y_s,shot_e_s,shot_x_s,shot_y_s);
        
    -- Player dead sprite
    pc_delay: clock_counter
        generic map ( 18000000 )
        port map ( CLOCK_27, pc_dead_delay );
    
    process (pc_dead_delay)
    begin
        if reset_s = '1' or player_reset = '1' then
            player_exploding <= '0';
            player_reset <= '0';
            pc_state <= ALIVE;
        elsif player_death = '1' then
            player_exploding <= '1';
            pc_state <= EXPLODING;
        elsif rising_edge(pc_dead_delay) then
        case pc_state is 
            
            when ALIVE =>
                    
            when EXPLODING =>
                pc_state <= DEAD;
            
            when DEAD =>
                player_reset <= '1';
                player_exploding <= '0';
                
        end case;
        end if;
    end process;
    ----------------------------------------------------------------    
        
    ----------------------------------------------------------------
    -- Aliens generator
    ----------------------------------------------------------------
    
    -- Verify if any enemy reached one of the sides
    turn  <= '0' when cpu_arr_m = (cpu_arr_m'range => '0') else '1';

    -- Generate enemies
    generate_cpu:
    for i in 0 to (cpu_num*cpu_lines-1) generate
    
    cpu_x: cpu
        generic map
            (
                res_x    => rx,
                res_y    => ry,    
                pos_x    => 15+(18*(i mod cpu_num)),
                pos_y    => 15+10*(i/cpu_num),
                aux_x    => alien_w,
                aux_y    => alien_h,        
                clock_div    => 18000000 -- 18000000
            )
        port map
            (reset_s,cpu_arr_c(i),CLOCK_50,turn,cpu_arr_m(i),cpu_arr_e(i),cpu_arr_x(i),cpu_arr_y(i),cpu_arr_d(i),cpu_game_over(i));
        
    collision_x: collisor
        generic map
            (    res_x=>rx,
                res_y=>ry,
                w=>alien_w,
                h=>alien_h,
                clock_div=>100
            )
        port map
            (CLOCK_27, cpu_arr_e(i) and shot_e_s, shot_x_s,cpu_arr_x(i),shot_y_s,cpu_arr_y(i),cpu_arr_c(i));
    end generate;
    ----------------------------------------------------------------
    
    ----------------------------------------------------------------
    -- ALIEN SHOOTER
    ----------------------------------------------------------------
    enemy_shot_clock: clock_counter
    generic map ( 27000000 )
    port map ( CLOCK_27, clk_enemy_shoot );    
    
    -- Randomly select an alive enemy to shoot
    PROCESS (clk_enemy_shoot)
    BEGIN
    if rising_edge(clk_enemy_shoot) then
        choosen_enemy <= rnd_s;
        enemy_shooting <= cpu_arr_e(choosen_enemy);
    end if;
    end process;
    
    cpu_x_shooter: shot
        generic map
            (
                clock_div => 1000000, -- 2500000
                res_x=>rx,
                res_y=>ry,
                aux_x=>alien_w,
                aux_y=>0,
                flag_up=>'0'
            )
        port map
            (CLOCK_50, reset_s OR shot_enemy_r_s, enemy_shooting, cpu_arr_x(choosen_enemy), cpu_arr_y(choosen_enemy),shot_enemy_e_s,shot_enemy_x_s,shot_enemy_y_s);
    
    -- ALIEN SHOOT COLLISION WITH PLAYER
    collision_x:     collisor
        generic map
            (    res_x=>rx,
                res_y=>ry,
                w=>player_w,
                h=>player_h,
                clock_div=>100
            )
        port map
            (CLOCK_27, shot_enemy_e_s, shot_enemy_x_s, position_x_s, shot_enemy_y_s, position_y_s, shot_enemy_r_s);
    
    shot_r_s <= '0' when cpu_arr_c = (cpu_arr_c'range => '0') else '1';
    ----------------------------------------------------------------
    
    ----------------------------------------------------------------
    -- GAME STATE MACHINE 
    ----------------------------------------------------------------
    spaceinvaders_fsm:
    PROCESS (reset,CLOCK_27)
    BEGIN
        IF reset = '1' THEN
            reset_s <= '1';
            state <= START;
        ELSIF rising_edge(CLOCK_27) THEN
        CASE state IS 
            
            WHEN START =>
                reset_s <= '0';
                IF controls(1) = '1' THEN
                    reset_s <= '1';
                    state <= PLAYING;
                END IF;
            
            WHEN PLAYING =>
                reset_s <= '0';
                IF game_over = '1' THEN
                    state <= GAME_OVER_STATE;
                ELSIF game_win = '1' THEN
                    state <= WIN;
                END IF;

                
            WHEN GAME_OVER_STATE | WIN =>
                IF controls(1) = '1' THEN
                    reset_s <= '1';
                    state <= PLAYING;
                END IF;
                            
        END CASE;
        END IF;
    END PROCESS;
    ----------------------------------------------------------------

    ----------------------------------------------------------------
    -- Live system
    ----------------------------------------------------------------
    -- Death verification
    player_death_by_alien <= '0' when cpu_game_over = (cpu_game_over'range => '0') else '1';
    player_death <= shot_enemy_r_s;
    
    -- lives: asynchronous reverse counter
    process (player_death, reset_s)
    begin
        if reset_s = '1' then
            lives <= 4;
        elsif rising_edge(player_death) then
                lives <= lives - 1;
        end if;
    end process;
    
    -- Game win verification
    game_win <= '1' when cpu_arr_e = (cpu_arr_e'range => '0') else '0';
    
    -- Game over verification
    game_over_by_lives <= '1' when lives = 0 else '0';          -- game over when lives = 0
    game_over <= (player_death_by_alien OR game_over_by_lives) and not (player_exploding); -- game over when aliens reach player
    
    -- Lives counter (shown in LEDS)
    with lives select
        LEDG(0) <= '0' when 0 | 1,
                   '1' when others;
    with lives select               
        LEDG(1) <= '0' when 0 | 1 | 2,
                   '1' when others;
    with lives select               
        LEDG(2) <= '1' when 4,
                   '0' when others;
    ----------------------------------------------------------------

    ----------------------------------------------------------------
    -- Random number generator
    ----------------------------------------------------------------
    rnd: random_gen
        generic map    ( cpu_num*cpu_lines )
        port map    ( clk_enemy_shoot, clock_50, rnd_s);
    
    ----------------------------------------------------------------
    -- Score system
    ----------------------------------------------------------------
    show_score: score
    port map(shot_r_s, reset_s, hex_s); -- shot_r_s as clock
    
    HEX0 <= hex_s(6 downto 0);
    HEX1 <= hex_s(13 downto 7);
    HEX2 <= hex_s(20 downto 14);
    HEX3 <= hex_s(27 downto 21);
    ----------------------------------------------------------------
    
end architecture;
