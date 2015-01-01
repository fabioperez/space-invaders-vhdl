LIBRARY ieee;
USE ieee.std_logic_1164.all;
LIBRARY lib;
USE lib.io.all;

entity kbd_input is
	port
	(
		clock_i			: 	in std_logic;
		reset_i			: 	in std_logic;
		hold_i			: 	in std_logic;
		PS2_DAT 		:		inout	STD_LOGIC;	--	PS2 Data
		PS2_CLK			:		inout	STD_LOGIC;		--	PS2 Clock
		shot_o			:		buffer 	std_logic;
		move_o			:		buffer 	std_logic;
		control_o		:		buffer 	std_logic_vector(2 downto 0)
	);
end;

architecture struct of kbd_input is
	component kbdex_ctrl
		generic(
			clkfreq : integer
		);
		port(
			ps2_data	:	inout	std_logic;
			ps2_clk		:	inout	std_logic;
			clk				:	in 	std_logic;
			en				:	in 	std_logic;
			resetn		:	in 	std_logic;
			lights		: in	std_logic_vector(2 downto 0); -- lights(Caps, Nun, Scroll)		
			key_on		:	out	std_logic_vector(2 downto 0);
			key_code	:	out	std_logic_vector(47 downto 0)
		);
	end component;
	
	signal CLOCKHZ, resetn 	: std_logic;
	signal keys		: std_logic_vector(31 downto 0);
	signal control_s1,control_s2	: std_logic_vector(2 downto 0);
	signal lights	: std_logic_vector(2 downto 0);
begin 
	resetn <= reset_i;

	-- Instanciação da componente controladora do teclado
	kbd_ctrl : kbdex_ctrl generic map(24000) port map(
		PS2_DAT, PS2_CLK, clock_i, hold_i, resetn, lights,
		open, key_code(31 downto 0) => keys
	);
	
	-- Processo divisor de clock
	process(clock_i)
		constant F_HZ : integer := 5;
		constant DIVIDER : integer := 24000000/F_HZ;
		variable count : integer range 0 to DIVIDER := 0;		
	begin
		if(rising_edge(clock_i)) then
			if count < DIVIDER / 2 then
				CLOCKHZ <= '1';
			else 
				CLOCKHZ <= '0';
			end if;
			if count = DIVIDER then
				count := 0;
			end if;
			count := count + 1;			
		end if;
	end process;
	
	---------------------------------------------
	---- MUX PARA TECLAS DE CONTROLE DO JOGO ----
	-- Aqui as teclas 4 e 6 do teclado numérico
	-- sao usadas para controle da direcao e as
	-- teclas 5 (do teclado numerico) e espaco
	-- sao usadas para disparo dos tiros pelo
	-- jogador. Esta componente é responsável
	-- por gerar sinais para estes controles,
	-- podendo haver tiro e movimento ao mesmo
	-- tempo, mas nunca movimentos em direcoes
	-- diferentes ao mesmo tempo.
	---------------------------------------------
	
	-- MUX que recebe sinal de controle da primeira
	-- tecla pressionada
	with keys(15 downto 0) select
		control_s1 <=
			"001"	when	"0000000001110100", -- DIREITA
			"010"	when	"0000000001110011", -- DISPARO
			"010"	when	"0000000000101001", -- DISPARO
			"100"	when	"0000000001101011", -- ESQUERDA
			"000" when others;
		
	-- MUX que recebe sinal de controle da segunda 
	-- tecla pressionada simultaneamente
	with keys(31 downto 16) select
		control_s2 <=
			"001"	when	"0000000001110100", -- DIREITA
			"010"	when	"0000000001110011", -- DISPARO
			"010"	when	"0000000000101001", -- DISPARO
			"100"	when	"0000000001101011", -- ESQUERDA
			"000" when others;
	
	-- Geração dos sinais que indicam que um sinal
	-- de controle foi enviado para a saída.
	shot_o <= control_s1(1) or control_s2(1); -- DISPARO
	move_o <= (control_s1(2) or control_s1(0)) xor (control_s2(2) or control_s2(0)); -- MOVIMENTO
	control_o <= control_s1 xor control_s2; -- CONTROLES
end struct;