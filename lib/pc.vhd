library ieee;
use ieee.std_logic_1164.all;
library lib;
use lib.general.all;

-------------------------------------------------------
-------------------------------------------------------
entity pc is
    generic
        (
            -- limites da tela
            res_x           :    integer := 160;
            res_y           :    integer := 120;
            
            -- ajustes devido ao tamanho da nave
            -- (visto que a lógica foi implementada,
            -- originalmente para elementos 'ponto')
            aux_y           :    integer := 0;
            aux_x           :    integer := 0;
            
            -- altura da nave na tela
            pos_y           :    integer := 5;
            
            -- clock divisor
            clock_div       :    integer := 2
        );
    port
        (
        -- comandos recebidos para reset ou movimento
        reset_i, enable_i   :    in std_logic;
        
        -- movement direction ('0' = left, 1' = right)
        right_flag_i        :    in std_logic;
        
        -- clock input
        clock_i             :     in std_logic;
        
        -- player position output
        clock_o             :    out std_logic; -- to-do: remove
        position_x_o        :    buffer integer range 0 to res_x;
        position_y_o        :    out integer range 0 to res_y
        );
end entity;

architecture behavior of pc is
    -- sinal de clock para atualização da posição x
    signal clock_s            :    std_logic;
begin
    -- contador que gera o sinal de clock para atualizacao
    -- da posicao x
    pc_clock: clock_counter
        generic map ( clock_div )
        port map ( clock_i, clock_s );

    -- registrador de posição da nave do jogador
    -- é atualizado  incremetando ou decrementando
    -- o valor das posições na subida do clock se
    -- receber sinais de controle
    pc_movement:
        process (reset_i, enable_i,clock_s)
        begin
            -- reset assincrono da posição X
            if reset_i = '1' then
                position_x_o <= res_x/2 - aux_x/2;
            else
            
            -- atualização dos registradores a partir
            -- dos sinais de entrada e limites estabelecidos
            if rising_edge(clock_s) and enable_i ='1'  then
                if right_flag_i = '1' then
                    position_x_o <= position_x_o + 1;
                elsif right_flag_i = '0' then
                    position_x_o <= position_x_o - 1;
                end if;
                
                if position_x_o + aux_x > res_x-5 then
                    position_x_o <= res_x-aux_x-5;
                end if;
                
                if position_x_o < 5 then
                    position_x_o <= 5;
                end if;
            end if;
            end if;
        end process;

    -- atualiza posicao de saida com posicao y
    position_y_o <= pos_y + aux_y/2;
    
end architecture;
