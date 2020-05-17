library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- -----------------------------------------------------------------------

entity DE10liteToplevel is
	port
	(
		ADC_CLK_10		:	 IN STD_LOGIC;
		MAX10_CLK1_50		:	 IN STD_LOGIC;
		MAX10_CLK2_50		:	 IN STD_LOGIC;
		KEY		:	 IN STD_LOGIC_VECTOR(1 DOWNTO 0);
		SW		:	 IN STD_LOGIC_VECTOR(9 DOWNTO 0);
		LEDR		:	 OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
		HEX0		:	 OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		HEX1		:	 OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		HEX2		:	 OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		HEX3		:	 OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		HEX4		:	 OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		HEX5		:	 OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		DRAM_CLK		:	 OUT STD_LOGIC;
		DRAM_CKE		:	 OUT STD_LOGIC;
		DRAM_ADDR		:	 OUT STD_LOGIC_VECTOR(12 DOWNTO 0);
		DRAM_BA		:	 OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
		DRAM_DQ		:	 INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		DRAM_LDQM		:	 OUT STD_LOGIC;
		DRAM_UDQM		:	 OUT STD_LOGIC;
		DRAM_CS_N		:	 OUT STD_LOGIC;
		DRAM_WE_N		:	 OUT STD_LOGIC;
		DRAM_CAS_N		:	 OUT STD_LOGIC;
		DRAM_RAS_N		:	 OUT STD_LOGIC;
		VGA_HS		:	 OUT STD_LOGIC;
		VGA_VS		:	 OUT STD_LOGIC;
		VGA_R		:	 OUT UNSIGNED(3 DOWNTO 0);
		VGA_G		:	 OUT UNSIGNED(3 DOWNTO 0);
		VGA_B		:	 OUT UNSIGNED(3 DOWNTO 0);
		CLK_I2C_SCL		:	 OUT STD_LOGIC;
		CLK_I2C_SDA		:	 INOUT STD_LOGIC;
		GSENSOR_SCLK		:	 OUT STD_LOGIC;
		GSENSOR_SDO		:	 INOUT STD_LOGIC;
		GSENSOR_SDI		:	 INOUT STD_LOGIC;
		GSENSOR_INT		:	 IN STD_LOGIC_VECTOR(2 DOWNTO 1);
		GSENSOR_CS_N		:	 OUT STD_LOGIC;
		GPIO		:	 INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
		ARDUINO_IO		:	 INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		ARDUINO_RESET_N		:	 INOUT STD_LOGIC
	);
END entity;

architecture RTL of DE10liteToplevel is
   constant reset_cycles : integer := 131071;
	
-- System clocks

	signal sysclk : std_logic;

--	signal slowclk : std_logic;
--	signal fastclk : std_logic;
--	signal pll_locked : std_logic;

-- SPI signals

	signal diskled :std_logic;
	signal floppyled : std_logic;
	signal powerled : unsigned(1 downto 0);

	signal sd_clk : std_logic;
	signal sd_cs : std_logic;
	signal sd_mosi : std_logic;
	signal sd_miso : std_logic;
	
-- Global signals
	signal reset_n : std_logic;
	signal pll_locked : std_logic;

-- PS/2 Keyboard socket - used for second mouse
	alias ps2_keyboard_clk : std_logic is GPIO(10);
	alias ps2_keyboard_dat : std_logic is GPIO(12);

	signal ps2_keyboard_clk_in : std_logic;
	signal ps2_keyboard_dat_in : std_logic;
	signal ps2_keyboard_clk_out : std_logic;
	signal ps2_keyboard_dat_out : std_logic;

-- PS/2 Mouse
	alias ps2_mouse_clk : std_logic is GPIO(14);
	alias ps2_mouse_dat : std_logic is GPIO(16);

	signal ps2_mouse_clk_in: std_logic;
	signal ps2_mouse_dat_in: std_logic;
	signal ps2_mouse_clk_out: std_logic;
	signal ps2_mouse_dat_out: std_logic;

	
-- Video
	signal vga_red: std_logic_vector(7 downto 0);
	signal vga_green: std_logic_vector(7 downto 0);
	signal vga_blue: std_logic_vector(7 downto 0);
	signal vga_window : std_logic;
	signal vga_hsync : std_logic;
	signal vga_vsync : std_logic;
	
	
-- RS232 serial
	signal rs232_rxd : std_logic;
	signal rs232_txd : std_logic;

	alias sigma_l : std_logic is GPIO(18);
	alias sigma_r : std_logic is GPIO(20);

	signal audio_l : std_logic_vector(15 downto 0);
	signal audio_r : std_logic_vector(15 downto 0);
	
-- IO

	signal joya : std_logic_vector(6 downto 0);
	signal joyb : std_logic_vector(6 downto 0);
	signal joyc : std_logic_vector(6 downto 0);
	signal joyd : std_logic_vector(6 downto 0);

	COMPONENT hybrid_pwm_sd
		PORT
		(
			clk		:	 IN STD_LOGIC;
			n_reset	:	 IN STD_LOGIC;
			din		:	 IN STD_LOGIC_VECTOR(15 DOWNTO 0);
			dout		:	 OUT STD_LOGIC
		);
	END COMPONENT;
	
	COMPONENT minimig_virtual_top
	generic
	( debug : boolean := false );
	PORT
	(
		CLK_IN		:	 IN STD_LOGIC;
		CLK_114		:	 OUT STD_LOGIC;
		RESET_N     :   IN STD_LOGIC;
		LED_POWER	:	 OUT STD_LOGIC;
		LED_DISK    :   OUT STD_LOGIC;
		MENU_BUTTON :   IN STD_LOGIC;
		UART_TX		:	 OUT STD_LOGIC;
		UART_RX		:	 IN STD_LOGIC;
		VGA_HS		:	 OUT STD_LOGIC;
		VGA_VS		:	 OUT STD_LOGIC;
		VGA_R		:	 OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		VGA_G		:	 OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		VGA_B		:	 OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		SDRAM_DQ		:	 INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		SDRAM_A		:	 OUT STD_LOGIC_VECTOR(12 DOWNTO 0);
		SDRAM_DQML		:	 OUT STD_LOGIC;
		SDRAM_DQMH		:	 OUT STD_LOGIC;
		SDRAM_nWE		:	 OUT STD_LOGIC;
		SDRAM_nCAS		:	 OUT STD_LOGIC;
		SDRAM_nRAS		:	 OUT STD_LOGIC;
		SDRAM_nCS		:	 OUT STD_LOGIC;
		SDRAM_BA		:	 OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
		SDRAM_CLK		:	 OUT STD_LOGIC;
		SDRAM_CKE		:	 OUT STD_LOGIC;
		AUDIO_L		:	 OUT STD_LOGIC_VECTOR(14 downto 0);
		AUDIO_R		:	 OUT STD_LOGIC_VECTOR(14 downto 0);
		PS2_DAT_I		:	 INOUT STD_LOGIC;
		PS2_CLK_I		:	 INOUT STD_LOGIC;
		PS2_MDAT_I	:	 INOUT STD_LOGIC;
		PS2_MCLK_I		:	 INOUT STD_LOGIC;
		PS2_DAT_O		:	 INOUT STD_LOGIC;
		PS2_CLK_O		:	 INOUT STD_LOGIC;
		PS2_MDAT_O		:	 INOUT STD_LOGIC;
		PS2_MCLK_O		:	 INOUT STD_LOGIC;
		JOYA		:	 IN STD_LOGIC_VECTOR(6 DOWNTO 0);
		JOYB		:	 IN STD_LOGIC_VECTOR(6 DOWNTO 0);
		JOYC		:	 IN STD_LOGIC_VECTOR(6 DOWNTO 0);
		JOYD		:	 IN STD_LOGIC_VECTOR(6 DOWNTO 0);
		SD_MISO	:	 IN STD_LOGIC;
		SD_MOSI	:	 OUT STD_LOGIC;
		SD_CLK	:	 OUT STD_LOGIC;
		SD_CS		:	 OUT STD_LOGIC;
		SD_ACK	:	 IN STD_LOGIC
	);
	END COMPONENT;

begin

-- SPI

ARDUINO_IO(10)<=sd_cs;
ARDUINO_IO(11)<=sd_mosi;
ARDUINO_IO(12)<='Z';
sd_miso<=ARDUINO_IO(12);
ARDUINO_IO(13)<=sd_clk;

vga_window<='1';

reset_n<=KEY(0) and pll_locked;


-- External devices tied to GPIOs

ps2_mouse_dat_in<=ps2_mouse_dat;
ps2_mouse_dat <= '0' when ps2_mouse_dat_out='0' else 'Z';
ps2_mouse_clk_in<=ps2_mouse_clk;
ps2_mouse_clk <= '0' when ps2_mouse_clk_out='0' else 'Z';

ps2_keyboard_dat_in<=ps2_keyboard_dat;
ps2_keyboard_dat <= '0' when ps2_keyboard_dat_out='0' else 'Z';
ps2_keyboard_clk_in<=ps2_keyboard_clk;
ps2_keyboard_clk <= '0' when ps2_keyboard_clk_out='0' else 'Z';


virtual_top : COMPONENT minimig_virtual_top
generic map
	(
		debug => true
	)
PORT map
	(
		CLK_IN => MAX10_CLK1_50,
		CLK_114 => sysclk,
		RESET_N => KEY(0),
		LED_POWER => LEDR(0),
		LED_DISK => LEDR(1),
		MENU_BUTTON => KEY(1),
		UART_TX => rs232_txd,
		UART_RX => rs232_rxd,
		VGA_HS => vga_hsync,
		VGA_VS => vga_vsync,
		VGA_R	=> vga_red,
		VGA_G	=> vga_green,
		VGA_B	=> vga_blue,
	
		SDRAM_DQ	=> DRAM_DQ,
		SDRAM_A => DRAM_ADDR,
		SDRAM_DQML => DRAM_LDQM,
		SDRAM_DQMH => DRAM_UDQM,
		SDRAM_nWE => DRAM_WE_N,
		SDRAM_nCAS => DRAM_CAS_N,
		SDRAM_nRAS => DRAM_RAS_N,
		SDRAM_nCS => DRAM_CS_N,
		SDRAM_BA => DRAM_BA,
		SDRAM_CLK => DRAM_CLK,
		SDRAM_CKE => DRAM_CKE,

		AUDIO_L => audio_l(15 downto 1),
		AUDIO_R => audio_r(15 downto 1),
		
		PS2_DAT_I => ps2_keyboard_dat_in,
		PS2_CLK_I => ps2_keyboard_clk_in,
		PS2_MDAT_I => ps2_mouse_dat_in,
		PS2_MCLK_I => ps2_mouse_clk_in,

		PS2_DAT_O => ps2_keyboard_dat_out,
		PS2_CLK_O => ps2_keyboard_clk_out,
		PS2_MDAT_O => ps2_mouse_dat_out,
		PS2_MCLK_O => ps2_mouse_clk_out,
		
		JOYA => joya,
		JOYB => joyb,
		JOYC => joyc,
		JOYD => joyd,
		
		SD_MISO => sd_miso,
		SD_MOSI => sd_mosi,
		SD_CLK => sd_clk,
		SD_CS => sd_cs,
		SD_ACK => '1'
	);
	
audio_l(0)<='0';
audio_r(0)<='0';

VGA_HS<=vga_hsync;
VGA_VS<=vga_vsync;
VGA_R<=unsigned(vga_red(7 downto 4));
VGA_G<=unsigned(vga_green(7 downto 4));
VGA_B<=unsigned(vga_blue(7 downto 4));
	
GPIO(0)<=rs232_txd;
rs232_rxd<=GPIO(1);

joya<=(others=>'1');
joyb<=(others=>'1');
joyc<=(others=>'1');
joyd<=(others=>'1');

left_sd : COMPONENT hybrid_pwm_sd
	PORT map
	(
		clk => sysclk,
		n_reset => vga_hsync,
		din(15) => not audio_l(15),
		din(14 downto 0) => audio_l(14 downto 0),
		dout => sigma_l
	);

right_sd : COMPONENT hybrid_pwm_sd
	PORT map
	(
		clk => sysclk,
		n_reset => vga_hsync,
		din(15) => not audio_r(15),
		din(14 downto 0) => audio_r(14 downto 0),
		dout => sigma_r
	);

end rtl;
