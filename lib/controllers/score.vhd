LIBRARY ieee ;
USE ieee.std_logic_1164.all;
LIBRARY lib;
USE lib.general.all;

entity score is
    port(
        clock_i,reset_i: in std_logic;
        score_o: out std_logic_vector(27 downto 0)
        );
end score;

architecture Behavior of score is
    signal unidade, dezena, centena, milhar: integer := 0;
begin
    process(clock_i,reset_i)
    begin
        if reset_i = '1' then
                unidade <= 0;
                dezena <= 0;
                centena <= 0;
                milhar <= 0;
        elsif rising_edge(clock_i) then
            dezena <= dezena + 1;
            
            if dezena >= 9 then
                dezena <= 0;
                centena <= centena + 1;
            end if;
            
            if centena >= 9 then
                centena <= 0;
                milhar <= milhar + 1;
            end if;
            
        end if;
    end process;
    
    disp_u: conv_7seg_int
        port map (unidade,score_o(6 downto 0));
            
    disp_d:  conv_7seg_int
        port map (dezena,score_o(13 downto 7));

    disp_c:  conv_7seg_int
        port map (centena,score_o(20 downto 14));
    
    disp_m:  conv_7seg_int
        port map (milhar,score_o(27 downto 21));

end Behavior;
