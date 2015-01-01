-------------------------------------------------------------------------------
-- Title      : MC613
-- Project    : Keyboard Controller
-- Details    : www.ic.unicamp.br/~corte/mc613/
--							www.computer-engineering.org/ps2protocol/
-------------------------------------------------------------------------------
-- File       : kbdext_ctrl.vhd
-- Author     : Thiago Borges Abdnur
-- Company    : IC - UNICAMP
-- Last update: 2010/03/29
-------------------------------------------------------------------------------
-- Description:
-- The keyboard controller receives serial data input from the device and
-- signals through 'key_on' when a key is pressed. Up to 3 keys can be pressed
-- simultaneously. The key code data is written to 'key_code':
-- 		First key pressed:
--			. key_code(15 downto 0) is set with data
--			. key_on(0) rises
-- 		First key released:
--			. key_on(0) falls
--
--		Second key pressed:
--			. key_code(31 downto 16) is set with data
--			. key_on(1) rises
-- 		Second key released:
--			. key_on(1) falls
--
--		Third key pressed:
--			. key_code(47 downto 32) is set with data
--			. key_on(2) rises
-- 		Third key released:
--			. key_on(2) falls
--
-- Remarks:
--    .clk: system clock frequency needs to be at least 10 MHz
--    .PrintScreen key signals as if two keys were pressed (E012 and E07C)
--    .Pause/Break key signals as if two keys were pressed (14 and 77), so it
--      is the same as if LCTRL (14) and NUNLOCK(77) were pressed.
--    .Currently it's not possible to write to the keyboard, turning its lights
--      on.
-------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

entity kbdex_ctrl is
	generic(
		clkfreq : integer
	);
	port(
		ps2_data	:	inout	std_logic;
		ps2_clk		:	inout	std_logic;
		clk				:	in 	std_logic;
		en				:	in 	std_logic;
		resetn		:	in 	std_logic;		
		lights		: 	in	std_logic_vector(2 downto 0) := "000"; -- lights(Caps, Nun, Scroll)
		key_on		:	out	std_logic_vector(2 downto 0);
		key_code	:	out	std_logic_vector(47 downto 0)
	);
end;

architecture rtl of kbdex_ctrl is
	component ps2_iobase
		generic(
			clkfreq : integer	-- This is the system clock value in kHz
		);
		port(
			ps2_data	:	inout	std_logic;
			ps2_clk		:	inout	std_logic;
			clk				:	in	std_logic;
			en				:	in	std_logic;
			resetn		:	in	std_logic;
			idata_rdy	:	in	std_logic;
			idata			:	in	std_logic_vector(7 downto 0);
			send_rdy	:	out	std_logic;
			odata_rdy	:	out	std_logic;
			odata			:	out	std_logic_vector(7 downto 0)
		);
	end component;

	type statename is (
		IDLE, FETCH, DECODE, CODE,
		RELEASE, EXT0, EXT1, CLRDP
	);

	-- State machine signals
	signal state, nstate	:	statename;
	signal sigfetch, sigfetched, sigext0,
				 sigrelease, sigselect, sigclear :	std_logic;

	-- Datapath signals
	signal newdata, selE0, relbt, selbt,
				 key0en, key1en, key2en,
				 key0clearn, key1clearn, key2clearn	: std_logic;
	signal ps2_code			:	unsigned( 7 downto 0);
	signal fetchdata		:	unsigned( 7 downto 0);
	signal upperdata		:	unsigned( 7 downto 0);
	signal datacode			:	unsigned(15 downto 0);
	signal key0code			:	unsigned(15 downto 0);
	signal key1code			:	unsigned(15 downto 0);
	signal key2code			:	unsigned(15 downto 0);

	-- Lights control
	signal hdata				:	std_logic_vector( 7 downto 0);
	signal sigsend, sigsendrdy, sigsending,
				 siguplights	:	std_logic;
	
	-- PS2 output signals
	signal ps2_dataout	:	std_logic_vector(7 downto 0);
	signal ps2_datardy	:	std_logic;

begin
	ps2_ctrl : ps2_iobase generic map(clkfreq) port map(
		ps2_data, ps2_clk, clk, en, resetn, sigsend, hdata,
		sigsendrdy, ps2_datardy, ps2_dataout
	);

	ps2_code <= unsigned(ps2_dataout);

	-- State cicle
	process(clk, resetn, sigsending)
	begin
		-- Change state on falling edge of ps2_clk
		if(rising_edge(clk) and en = '1') then
			state <= nstate;
		end if;
		if resetn = '0' or sigsending = '1' then
			state <= IDLE;
		end if;
	end process;

	-- Select next state
	process(state, newdata)
	begin
		case state is
			when IDLE		=>
				if newdata = '1' then
					nstate <= FETCH;
				else
					nstate <= IDLE;
				end if;

			when FETCH	=>
				nstate <= DECODE;

			when DECODE	=>
				if fetchdata = X"F0" then
					nstate <= RELEASE;
				elsif fetchdata = X"E0" then
					nstate <= EXT0;
				elsif fetchdata = X"E1" then
					nstate <= EXT1;
				else
					nstate <= CODE;
				end if;

			when CODE	=>
				nstate <= CLRDP;

			when RELEASE | EXT0 | EXT1 | CLRDP =>
				nstate <= IDLE;
		end case;
	end process;

	-- Current state output
	process(state)
	begin
		sigfetch <= '0';
		sigfetched <= '0';
		sigext0 <= '0';
		sigrelease <= '0';
		sigselect <= '0';
		sigclear <= '0';

		case state is
			when IDLE | EXT1 =>
				NULL;

			when FETCH =>
				sigfetch <= '1';

			when DECODE	=>
				sigfetched <= '1';

			when CODE =>
				sigselect <= '1';

			when RELEASE =>
				sigrelease <= '1';

			when EXT0 =>
				sigext0 <= '1';

			when CLRDP =>
				sigclear <= '1';
		end case;
	end process;

	-- Fetched signal register
	process(clk, resetn)
	begin
		if(rising_edge(clk) and sigfetch = '1') then
			fetchdata <= ps2_code;
		end if;
		if resetn = '0' then
			fetchdata <= X"00";
		end if;
	end process;

	-- EXT0 selection (SR Latch)
	process(sigext0, sigclear, resetn)
	begin
		if sigclear = '1' or resetn = '0' then
			selE0 <= '0';
		elsif sigext0 = '1' then
			selE0 <= '1';
		end if;
	end process;

	-- Mux for upper value (E0 or 0)
	process(selE0)
	begin
		if selE0 = '1' then
			upperdata <= X"E0";
		else
			upperdata <= X"00";
		end if;
	end process;

	-- datacode data set
	datacode <= upperdata & fetchdata;

	-- Keys registers
	KEY0 : process(clk, key0clearn, resetn)
	begin
		if(rising_edge(clk) and key0en = '1') then
			key0code <= datacode;
		end if;
		if key0clearn = '0' or resetn = '0' then
			key0code <= X"0000";
		end if;
	end process;

	KEY1 : process(clk, key1clearn, resetn)
	begin
		if(rising_edge(clk) and key1en = '1') then
			key1code <= datacode;
		end if;
		if key1clearn = '0' or resetn = '0' then
			key1code <= X"0000";
		end if;
	end process;

	KEY2 : process(clk, key2clearn, resetn)
	begin
		if(rising_edge(clk) and key2en = '1') then
			key2code <= datacode;
		end if;
		if key2clearn = '0' or resetn = '0' then
			key2code <= X"0000";
		end if;
	end process;

	-- Release command (SR Latch)
	process(sigrelease, sigclear, resetn)
	begin
		if sigclear = '1' or resetn = '0' then
			relbt <= '0';
		elsif sigrelease = '1' then
			relbt <= '1';
		end if;
	end process;

	-- Release command (SR Latch)
	process(sigselect, sigclear, resetn)
	begin
		if sigclear = '1' or resetn = '0' then
			selbt <= '0';
		elsif sigselect = '1' then
			selbt <= '1';
		end if;
	end process;

	-- Key replacement and clear selector
	SELECTOR : process(relbt, selbt)
	begin
		key0en <= '0'; key1en <= '0'; key2en <= '0';
		key0clearn <= '1'; key1clearn <= '1'; key2clearn <= '1';

		-- Select an empty register to record fetched data
		if relbt = '0' and selbt = '1' then
			if datacode /= key0code and datacode /= key1code and
			 datacode /= key2code then
				if key0code = X"0000" then
					key0en <= '1';
				elsif key1code = X"0000" then
					key1en <= '1';
				elsif key2code = X"0000" then
					key2en <= '1';
				end if;
			end if;
		-- Clear released key
		elsif relbt = '1' and selbt = '1' then
			-- Handle fake shifts
			if datacode = X"0012" then
				if key0code = X"E012" then
					key0clearn <= '0';
				elsif key1code = X"E012" then
					key1clearn <= '0';
				elsif key2code = X"E012" then
					key2clearn <= '0';
				end if;
			elsif datacode = X"0059" then
				if key0code = X"E059" then
					key0clearn <= '0';
				elsif key1code = X"E059" then
					key1clearn <= '0';
				elsif key2code = X"E059" then
					key2clearn <= '0';
				end if;
			end if;
			-- Handle normal release
			if key0code = datacode then
				key0clearn <= '0';
			elsif key1code = datacode then
				key1clearn <= '0';
			elsif key2code = datacode then
				key2clearn <= '0';
			end if;
		end if;
	end process;

	-- Out with key codes
	key_code <= std_logic_vector(key2code & key1code & key0code);

	-- Turn buttons on
	process(clk, sigclear, resetn)
	begin
		if(rising_edge(clk) and sigclear = '1') then
			if key0code /= X"0000" then
				key_on(0) <= '1';
			else
				key_on(0) <= '0';
			end if;

			if key1code /= X"0000" then
				key_on(1) <= '1';
			else
				key_on(1) <= '0';
			end if;

			if key2code /= X"0000" then
				key_on(2) <= '1';
			else
				key_on(2) <= '0';
			end if;
		end if;
		if resetn = '0' then
			key_on <= "000";
		end if;
	end process;

	-- Comparator for newdata signal
	--   Signals on rising edge of ps2_datardy
	process(ps2_datardy, sigfetched, sigsending, resetn)
	begin
		if(rising_edge(ps2_datardy)) then
			newdata <= '1';
		end if;
		if resetn = '0' or sigfetched = '1' or sigsending = '1' then
			newdata <= '0';
		end if;
	end process;
	
	-- Keyboar lights control
	-- Detect ligths state change
	process(clk, lights, sigsending, resetn)
		variable laststate : std_logic_vector(2 downto 0);
	begin
		if resetn = '0' or sigsending = '1' then
			laststate := "XXX";
			siguplights <= '0';
		elsif(rising_edge(clk)) then
			if laststate /= lights then
				siguplights <= '1';				
				laststate := lights;
			else
				siguplights <= '0';
			end if;			
		end if;		
	end process;

	-- Send commands to keyboard
	process(clk, siguplights, en, resetn)
		type cmdstatename is (
			SETCMD, SEND, WAITACK, SETLIGHTS, SENDVAL, WAITACK1, CLEAR
		);		
		variable cmdstate : cmdstatename;
	begin
		if(rising_edge(clk)) then
			sigsend <= '0';
			sigsending <= '1';
			
			case cmdstate is
				when SETCMD =>
					hdata <= X"ED";
					if sigsendrdy = '1' then
						cmdstate := SEND;
					end if;
					
				when SEND =>
					sigsend <= '1';
					cmdstate := WAITACK;
					
				when WAITACK =>
					if ps2_datardy = '1' then
						if ps2_dataout = X"FE" then
							cmdstate := SETCMD;
						else
							cmdstate := SETLIGHTS;
						end if;							
					end if;
					
				when SETLIGHTS =>
					hdata <= "00000" & "000";
					if sigsendrdy = '1' then
							cmdstate := SENDVAL;
					end if;
			
				when SENDVAL =>					
					sigsend <= '1';
					cmdstate := WAITACK1;					
			
				when WAITACK1 =>
					if ps2_datardy = '1' then		
						if ps2_dataout = X"FE" then
							cmdstate := SETLIGHTS;
						else
							cmdstate := CLEAR;
						end if;
					end if;
			
				when CLEAR =>
					sigsending <= '0';
			end case;
		end if;
		if resetn = '0' or en = '0' or siguplights = '1' then
			sigsending <= '1';
			sigsend <= '0';
			cmdstate := SETCMD;
		end if;
	end process;

end rtl;