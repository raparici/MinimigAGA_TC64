/********************************************/
/* minimig_mist_top.v                       */
/* MiST Board Top File                      */
/*                                          */
/* 2012-2015, rok.krajnc@gmail.com          */
/********************************************/


// board type define
`define MINIMIG_VIRTUAL

`include "minimig_defines.vh"

module minimig_virtual_top
	#(parameter debug = 0, parameter spimux = 0 )
(
  // clock inputs
  input wire            CLK_IN,
  output wire           CLK_114,
  output wire           CLK_28,
  output wire           PLL_LOCKED,
  input wire            RESET_N,
  
  // Button inputs
  input						MENU_BUTTON,
  
  // LED outputs
  output wire           LED_POWER,  // LED green
  output wire           LED_DISK,   // LED red
  
  // UART
  output wire           CTRL_TX,    // UART Transmitter
  input wire            CTRL_RX,    // UART Receiver
  output wire           AMIGA_TX,    // UART Transmitter
  input wire            AMIGA_RX,    // UART Receiver
  
  // VGA
  output wire           VGA_SELCS,  // Select CSYNC
  output wire           VGA_CS,     // VGA C_SYNC
  output wire           VGA_HS,     // VGA H_SYNC
  output wire           VGA_VS,     // VGA V_SYNC
  output wire [  8-1:0] VGA_R,      // VGA Red[5:0]
  output wire [  8-1:0] VGA_G,      // VGA Green[5:0]
  output wire [  8-1:0] VGA_B,      // VGA Blue[5:0]
  
  // SDRAM
  inout  wire [ 16-1:0] SDRAM_DQ,   // SDRAM Data bus 16 Bits
  output wire [ 13-1:0] SDRAM_A,    // SDRAM Address bus 13 Bits
  output wire           SDRAM_DQML, // SDRAM Low-byte Data Mask
  output wire           SDRAM_DQMH, // SDRAM High-byte Data Mask
  output wire           SDRAM_nWE,  // SDRAM Write Enable
  output wire           SDRAM_nCAS, // SDRAM Column Address Strobe
  output wire           SDRAM_nRAS, // SDRAM Row Address Strobe
  output wire           SDRAM_nCS,  // SDRAM Chip Select
  output wire [  2-1:0] SDRAM_BA,   // SDRAM Bank Address
  output wire           SDRAM_CLK,  // SDRAM Clock
  output wire           SDRAM_CKE,  // SDRAM Clock Enable
  
  // MINIMIG specific
  output wire[14:0]     AUDIO_L,    // sigma-delta DAC output left
  output wire[14:0]     AUDIO_R,    // sigma-delta DAC output right

  // Keyboard / Mouse
  input                 PS2_DAT_I,      // PS2 Keyboard Data
  input                 PS2_CLK_I,      // PS2 Keyboard Clock
  input                 PS2_MDAT_I,     // PS2 Mouse Data
  input                 PS2_MCLK_I,     // PS2 Mouse Clock
  output                PS2_DAT_O,      // PS2 Keyboard Data
  output                PS2_CLK_O,      // PS2 Keyboard Clock
  output                PS2_MDAT_O,     // PS2 Mouse Data
  output                PS2_MCLK_O,     // PS2 Mouse Clock

  // Joystick
  input       [  7-1:0] JOYA,         // joystick port A
  input       [  7-1:0] JOYB,         // joystick port B
  input       [  7-1:0] JOYC,         // joystick port A
  input       [  7-1:0] JOYD,         // joystick port B
  
  // SPI 
  input wire            SD_MISO,     // inout
  output wire           SD_MOSI,
  output wire           SD_CLK,
  output wire           SD_CS,
  input wire            SD_ACK
);


////////////////////////////////////////
// internal signals                   //
////////////////////////////////////////

// clock
wire           clk_sdram;
wire           clk7_en;
wire           clk7n_en;
wire           c1;
wire           c3;
wire           cck;
wire [ 10-1:0] eclk;

// reset
wire           pll_rst;
wire           sdctl_rst;
wire           rst_50;
wire           rst_minimig;

// ctrl
wire           rom_status;
wire           ram_status;
wire           reg_status;

// tg68
wire           tg68_rst;
wire [ 16-1:0] tg68_dat_in;
wire [ 16-1:0] tg68_dat_out;
wire [ 32-1:0] tg68_adr;
wire [  3-1:0] tg68_IPL;
wire           tg68_dtack;
wire           tg68_as;
wire           tg68_uds;
wire           tg68_lds;
wire           tg68_rw;
wire           tg68_ena7RD;
wire           tg68_ena7WR;
wire           tg68_enaWR;
wire [ 16-1:0] tg68_cout;
wire           tg68_cpuena;
wire [  4-1:0] cpu_config;
wire [  6-1:0] memcfg;
wire           turbochipram;
wire           turbokick;
wire           cache_inhibit;
wire [ 32-1:0] tg68_cad;
wire [  7-1:0] tg68_cpustate;
wire           tg68_nrst_out;
//wire           tg68_cdma;
wire           tg68_clds;
wire           tg68_cuds;
wire [  4-1:0] tg68_CACR_out;
wire [ 32-1:0] tg68_VBR_out;
wire           tg68_ovr;

// minimig
wire           led;
wire [ 16-1:0] ram_data;      // sram data bus
wire [ 16-1:0] ramdata_in;    // sram data bus in
wire [ 48-1:0] chip48;        // big chip read
wire [ 23-1:1] ram_address;   // sram address bus
wire           _ram_bhe;      // sram upper byte select
wire           _ram_ble;      // sram lower byte select
wire           _ram_we;       // sram write enable
wire           _ram_oe;       // sram output enable
wire           _15khz;        // scandoubler disable
wire           sdo;           // SPI data output
wire           vs;
wire           hs;
wire           cs;
wire [  8-1:0] red;
wire [  8-1:0] green;
wire [  8-1:0] blue;
reg            cs_reg;
reg            vs_reg;
reg            hs_reg;
reg  [  8-1:0] red_reg;
reg  [  8-1:0] green_reg;
reg  [  8-1:0] blue_reg;

// sdram
wire           reset_out;
wire [  4-1:0] sdram_cs;
wire [  2-1:0] sdram_dqm;
wire [  2-1:0] sdram_ba;

// mist
wire           user_io_sdo;
wire           minimig_sdo;
wire [  16-1:0] joya;
wire [  16-1:0] joyb;
wire [  16-1:0] joyc;
wire [  16-1:0] joyd;
wire [  8-1:0] kbd_mouse_data;
wire           kbd_mouse_strobe;
wire           kms_level;
wire [  2-1:0] kbd_mouse_type;
wire [  3-1:0] mouse_buttons;

// UART
wire minimig_rxd;
wire minimig_txd;
wire debug_rxd;
wire debug_txd;


////////////////////////////////////////
// toplevel assignments               //
////////////////////////////////////////

// SDRAM
assign SDRAM_CKE        = 1'b1;
assign SDRAM_CLK        = clk_sdram;
assign SDRAM_nCS        = sdram_cs[0];
assign SDRAM_DQML       = sdram_dqm[0];
assign SDRAM_DQMH       = sdram_dqm[1];
assign SDRAM_BA         = sdram_ba;

// reset
assign pll_rst          = 1'b0;
assign sdctl_rst        = PLL_LOCKED & RESET_N;


// RTG support...

wire rtg_ena;	// RTG screen on/off
wire rtg_clut;	// Are we in high-colour or 8-bit CLUT mode?

reg [3:0] rtg_pixelctr;	// Counter, compared against rtg_pixelwidth
wire [3:0] rtg_pixelwidth; // Number of clocks per fetch - 1
wire [7:0] rtg_clut_idx;	// The currently selected colour in indexed mode
wire rtg_pixel;	// Strobe the next pixel from the FIFO

wire hblank_out;
wire vblank_out;
reg rtg_vblank;
wire rtg_blank;
reg rtg_blank_d;
reg [6:0] rtg_vbcounter;	// Vvbco counter
wire [6:0] rtg_vbend; // Size of VBlank area


wire [7:0] rtg_r;	// 16-bit mode RGB data
wire [7:0] rtg_g;
wire [7:0] rtg_b;
reg rtg_clut_in_sel;	// Select first or second byte of 16-bit word as CLUT index
reg rtg_clut_in_sel_d;
wire rtg_ext;	// Extend the active area by one clock.
wire [7:0] rtg_clut_r;	// RGB data from CLUT
wire [7:0] rtg_clut_g;
wire [7:0] rtg_clut_b;


// RTG data fetch strobe
assign rtg_pixel=(rtg_ena && (!rtg_blank || (!rtg_blank_d && rtg_ext)) && rtg_pixelctr==rtg_pixelwidth) ? 1'b1 : 1'b0;


always @(posedge CLK_114) begin

	// Delayed copies of signals
	rtg_blank_d<=rtg_blank;
	rtg_clut_in_sel_d<=rtg_clut_in_sel;

	// Alternate colour index at twice the fetch clock.
	if(rtg_pixelctr=={1'b0,rtg_pixelwidth[3:1]})
		rtg_clut_in_sel<=1'b1;
	
	// Increment the fetch clock, reset during blank.
	if(rtg_blank || rtg_pixel) begin
		rtg_pixelctr<=3'b0;
		rtg_clut_in_sel<=1'b0;
	end else begin
		rtg_pixelctr<=rtg_pixelctr+1;
	end
end

always @(posedge CLK_114)
begin
	// Handle vblank manually, since the OS makes it awkward to use the chipset for this.
	if(vblank_out) begin
		rtg_vblank<=1'b1;
		rtg_vbcounter<=5'b0;
	end else if(rtg_vbcounter==rtg_vbend) begin
		rtg_vblank<=1'b0;
	end else if(hs & !hs_reg) begin
		rtg_vbcounter<=rtg_vbcounter+1;
	end
end

assign rtg_blank = rtg_vblank | hblank_out;

assign rtg_clut_idx = rtg_clut_in_sel_d ? rtg_dat[7:0] : rtg_dat[15:8];
assign rtg_r=!rtg_blank ? {rtg_dat[14:10],rtg_dat[14:12]} : 16'b0 ;
assign rtg_g=!rtg_blank ? {rtg_dat[9:5],rtg_dat[9:7]} : 16'b0 ;
assign rtg_b=!rtg_blank ? {rtg_dat[4:0],rtg_dat[4:2]} : 16'b0 ;

wire [24:4] rtg_baseaddr;
wire [24:0] rtg_addr;
wire [15:0] rtg_dat;

wire rtg_ramreq;
wire [15:0] rtg_fromram;
wire rtg_fill;

// Replicate the CPU's address mangling.
wire [24:0] rtg_addr_mangled;
assign rtg_addr_mangled[24]=rtg_addr[24];
assign rtg_addr_mangled[23]=rtg_addr[23]^(rtg_addr[22]|rtg_addr[21]);
assign rtg_addr_mangled[22:0]=rtg_addr[22:0];

VideoStream myvs
(
	.clk(CLK_114),
	.reset_n((!vblank_out) & rtg_ena),
	.enable(rtg_ena),
	.baseaddr({rtg_baseaddr[24:4],4'b0}),
	// SDRAM interface
	.a(rtg_addr),
	.req(rtg_ramreq),
	.d(rtg_fromram),
	.fill(rtg_fill),
	// Display interface
	.rdreq(rtg_pixel),
	.q(rtg_dat)
);


always @ (posedge CLK_114) begin
  cs_reg    <= #1 cs;
  vs_reg    <= #1 vs;
  hs_reg    <= #1 hs;
  red_reg   <= #1 rtg_ena && !rtg_blank ? rtg_clut ? rtg_clut_r : rtg_r : red;
  green_reg <= #1 rtg_ena && !rtg_blank ? rtg_clut ? rtg_clut_g : rtg_g : green;
  blue_reg  <= #1 rtg_ena && !rtg_blank ? rtg_clut ? rtg_clut_b : rtg_b : blue;
end


// 


wire osd_window;
wire osd_pixel;
wire [1:0] osd_r;
wire [1:0] osd_g;
wire [1:0] osd_b;
assign osd_r = osd_pixel ? 2'b11 : 2'b00;
assign osd_g = osd_pixel ? 2'b11 : 2'b00;
assign osd_b = osd_pixel ? 2'b11 : 2'b10;
assign VGA_CS           = cs_reg;
assign VGA_VS           = vs_reg;
assign VGA_HS           = hs_reg;
//assign VGA_R[7:0]       = osd_window ? {osd_r,red_reg[7:2]} : red_reg[7:0];
assign VGA_G[7:0]       = osd_window ? {osd_g,green_reg[7:2]} : green_reg[7:0];
assign VGA_B[7:0]       = osd_window ? {osd_b,blue_reg[7:2]} : blue_reg[7:0];
// The lengths we go to in order to make an otherwise unused signal visible in signaltap!
assign VGA_R[7:0]       = osd_window ? {osd_r,red_reg[7:6],debug_sdr} : red_reg[7:0];


//// amiga clocks ////
amiga_clk amiga_clk (
  .rst          (1'b0             ), // async reset input
  .clk_in       (CLK_IN           ), // input clock     ( 27.000000MHz)
  .clk_114      (CLK_114          ), // output clock c0 (114.750000MHz)
  .clk_sdram    (clk_sdram        ), // output clock c2 (114.750000MHz, -146.25 deg)
  .clk_28       (CLK_28           ), // output clock c1 ( 28.687500MHz)
  .clk7_en      (clk7_en          ), // output clock 7 enable (on 28MHz clock domain)
  .clk7n_en     (clk7n_en         ), // 7MHz negedge output clock enable (on 28MHz clock domain)
  .c1           (c1               ), // clk28m clock domain signal synchronous with clk signal
  .c3           (c3               ), // clk28m clock domain signal synchronous with clk signal delayed by 90 degrees
  .cck          (cck              ), // colour clock output (3.54 MHz)
  .eclk         (eclk             ), // 0.709379 MHz clock enable output (clk domain pulse)
  .locked       (PLL_LOCKED       )  // pll locked output
);


//// TG68K main CPU ////

TG68K tg68k (
  .clk          (CLK_114          ),
  .reset        (tg68_rst         ),
  .clkena_in    (1'b1             ),
  .IPL          (tg68_IPL         ),
  .dtack        (tg68_dtack       ),
  .vpa          (1'b1             ),
  .ein          (1'b1             ),
  .addr         (tg68_adr         ),
  .data_read    (tg68_dat_in      ),
  .data_write   (tg68_dat_out     ),
  .as           (tg68_as          ),
  .uds          (tg68_uds         ),
  .lds          (tg68_lds         ),
  .rw           (tg68_rw          ),
  .vma          (                 ),
  .wrd          (                 ),
  .ena7RDreg    (tg68_ena7RD      ),
  .ena7WRreg    (tg68_ena7WR      ),
  .enaWRreg     (tg68_enaWR       ),
  .fromram      (tg68_cout        ),
  .ramready     (tg68_cpuena      ),
  .cpu          (cpu_config[1:0]  ),
  .turbochipram (turbochipram     ),
  .turbokick    (turbokick        ),
  .cache_inhibit(cache_inhibit    ),
  .fastramcfg   ({&memcfg[5:4],memcfg[5:4]}),
  .eth_en       (1'b1), // TODO
  .sel_eth      (),
  .frometh      (16'd0),
  .ethready     (1'b0),
  .ramaddr      (tg68_cad         ),
  .cpustate     (tg68_cpustate    ),
  .nResetOut    (tg68_nrst_out    ),
  .skipFetch    (                 ),
  .ramlds       (tg68_clds        ),
  .ramuds       (tg68_cuds        ),
  .CACR_out     (tg68_CACR_out    ),
  .VBR_out      (tg68_VBR_out     ),
  // RTG signals
	.rtg_addr(rtg_baseaddr),
	.rtg_vbend(rtg_vbend),
	.rtg_ext(rtg_ext),
	.rtg_pixelclock(rtg_pixelwidth),
	.rtg_clut(rtg_clut),
	.rtg_clut_idx(rtg_clut_idx),
	.rtg_clut_r(rtg_clut_r),
	.rtg_clut_g(rtg_clut_g),
	.rtg_clut_b(rtg_clut_b)
);


wire [ 32-1:0] hostRD;
wire [ 32-1:0] hostWR;
wire [ 32-1:0] hostaddr;
reg  [ 32-1:0] hostaddr_d;
wire [  3-1:0] hostState;
wire [3:0]     hostbytesel;
reg  [ 32-1:0] hostdata;
wire           hostramena;
wire           hostena;
wire           hostwe;
wire           hostreq;
wire           hostack;
wire           hostce;
wire [3:0]     debug_sdr;


always @(posedge CLK_114) begin
	hostaddr_d<=hostaddr;
end

//sdram sdram (
sdram_ctrl sdram (
  .cache_rst    (tg68_rst         ),
  .cache_inhibit(cache_inhibit    ),
  .cpu_cache_ctrl (tg68_CACR_out    ),
  .sdata        (SDRAM_DQ         ),
  .sdaddr       (SDRAM_A[12:0]    ),
  .dqm          (sdram_dqm        ),
  .sd_cs        (sdram_cs         ),
  .ba           (sdram_ba         ),
  .sd_we        (SDRAM_nWE        ),
  .sd_ras       (SDRAM_nRAS       ),
  .sd_cas       (SDRAM_nCAS       ),
  .sysclk       (CLK_114          ),
  .reset_in     (sdctl_rst        ),
  
  .hostWR       (hostWR           ),
  .hostAddr     (hostaddr_d[23:0] ),
  .hostwe       (hostwe           ),
  .hostce       (hostce           ),
  .hostbytesel  (hostbytesel      ),
  .hostRD       (hostRD           ),
  .hostena      (hostramena       ),

  .cpuWR        (tg68_dat_out     ),
  .cpuAddr      (tg68_cad[24:1]   ),
  .cpuU         (tg68_cuds        ),
  .cpuL         (tg68_clds        ),
  .cpustate     (tg68_cpustate    ),
  .cpuRD        (tg68_cout        ),
  .cpuena       (tg68_cpuena      ),

//  .cpu_dma      (tg68_cdma        ),
  .chipWR       (ram_data         ),
  .chipAddr     ({1'b0, ram_address[22:1]}),
  .chipU        (_ram_bhe         ),
  .chipL        (_ram_ble         ),
  .chipRW       (_ram_we          ),
  .chip_dma     (_ram_oe          ),
  .clk7_en      (clk7_en          ),
  .chipRD       (ramdata_in       ),
  .chip48       (chip48           ),

  .rtgAddr      (rtg_addr_mangled ),
  .rtgce        (rtg_ramreq       ),
  .rtgfill      (rtg_fill         ),
  .rtgRd        (rtg_fromram      ),

  .reset_out    (reset_out        ),
  .enaRDreg     (                 ),
  .enaWRreg     (tg68_enaWR       ),
  .ena7RDreg    (tg68_ena7RD      ),
  .ena7WRreg    (tg68_ena7WR      ),
  .debug        (debug_sdr        )
);


// multiplex spi_do, drive it from user_io if that's selected, drive
// it from minimig if it's selected and leave it open else (also
// to be able to monitor sd card data directly)

wire [8-1 : 0] SPI_CS;
wire SPI_DO;
wire SPI_DI;
wire SPI_SCK;
wire SPI_SS;
wire SPI_SS2;
wire SPI_SS3;
wire SPI_SS4;
wire CONF_DATA0;

//assign SPI_DO = (CONF_DATA0 == 1'b0)?user_io_sdo:
//    (((SPI_SS2 == 1'b0)|| (SPI_SS3 == 1'b0))?minimig_sdo:1'bZ);

assign SD_CLK = SPI_SCK;
assign SD_CS = SPI_CS[1];
assign SD_MOSI = SPI_DI;
assign SPI_SS4 = SPI_CS[6];
assign SPI_SS3 = SPI_CS[5];
assign SPI_SS2 = SPI_CS[4];

//// minimig top ////
minimig minimig (
	//m68k pins
	.cpu_address  (tg68_adr[23:1]   ), // M68K address bus
	.cpu_data     (tg68_dat_in      ), // M68K data bus
	.cpudata_in   (tg68_dat_out     ), // M68K data in
	._cpu_ipl     (tg68_IPL         ), // M68K interrupt request
	._cpu_as      (tg68_as          ), // M68K address strobe
	._cpu_uds     (tg68_uds         ), // M68K upper data strobe
	._cpu_lds     (tg68_lds         ), // M68K lower data strobe
	.cpu_r_w      (tg68_rw          ), // M68K read / write
	._cpu_dtack   (tg68_dtack       ), // M68K data acknowledge
	._cpu_reset   (tg68_rst         ), // M68K reset
	._cpu_reset_in(tg68_nrst_out    ), // M68K reset out
	.cpu_vbr      (tg68_VBR_out     ), // M68K VBR
	.ovr          (tg68_ovr         ), // NMI override address decoding
	//sram pins
	.ram_data     (ram_data         ), // SRAM data bus
	.ramdata_in   (ramdata_in       ), // SRAM data bus in
	.ram_address  (ram_address[22:1]), // SRAM address bus
	._ram_bhe     (_ram_bhe         ), // SRAM upper byte select
	._ram_ble     (_ram_ble         ), // SRAM lower byte select
	._ram_we      (_ram_we          ), // SRAM write enable
	._ram_oe      (_ram_oe          ), // SRAM output enable
	.chip48       (chip48           ), // big chipram read
	//system  pins
	.rst_ext      (!RESET_N         ), // reset from ctrl block
	.rst_out      (                 ), // minimig reset status
	.clk          (CLK_28           ), // output clock c1 ( 28.687500MHz)
	.clk7_en      (clk7_en          ), // 7MHz clock enable
	.clk7n_en     (clk7n_en         ), // 7MHz negedge clock enable
	.c1           (c1               ), // clk28m clock domain signal synchronous with clk signal
	.c3           (c3               ), // clk28m clock domain signal synchronous with clk signal delayed by 90 degrees
	.cck          (cck              ), // colour clock output (3.54 MHz)
	.eclk         (eclk             ), // 0.709379 MHz clock enable output (clk domain pulse)
	//rs232 pins
	.rxd          (AMIGA_RX         ),  // RS232 receive
	.txd          (AMIGA_TX         ),  // RS232 send
	.cts          (1'b0             ),  // RS232 clear to send
	.rts          (                 ),  // RS232 request to send
	//I/O
	._joy1        (JOYA             ),  // joystick 1 [fire7:fire,up,down,left,right] (default mouse port)
	._joy2        (JOYB             ),  // joystick 2 [fire7:fire,up,down,left,right] (default joystick port)
	._joy3        (JOYC             ),  // joystick 3 [fire7:fire,up,down,left,right]
	._joy4        (JOYD             ),  // joystick 4 [fire7:fire,up,down,left,right]
	.mouse_btn1   (1'b1             ), // mouse button 1
	.mouse_btn2   (1'b1             ), // mouse button 2
	//  .mouse_btn    (mouse_buttons    ),  // mouse buttons
	//  .kbd_mouse_data (kbd_mouse_data ),  // mouse direction data, keycodes
	//  .kbd_mouse_type (kbd_mouse_type ),  // type of data
	.kbd_mouse_strobe (1'b0         ), // kbd_mouse_strobe), // kbd/mouse data strobe
	.kms_level    (1'b0             ), // kms_level        ),
	._15khz       (_15khz           ), // scandoubler disable
	.pwr_led      (LED_POWER        ), // power led
	.disk_led     (LED_DISK         ), // power led
	.msdat_i      (PS2_MDAT_I       ), // PS2 mouse data
	.msclk_i      (PS2_MCLK_I       ), // PS2 mouse clk
	.kbddat_i     (PS2_DAT_I        ), // PS2 keyboard data
	.kbdclk_i     (PS2_CLK_I        ), // PS2 keyboard clk
	.msdat_o      (PS2_MDAT_O       ), // PS2 mouse data
	.msclk_o      (PS2_MCLK_O       ), // PS2 mouse clk
	.kbddat_o     (PS2_DAT_O        ), // PS2 keyboard data
	.kbdclk_o     (PS2_CLK_O        ), // PS2 keyboard clk
	//host controller interface (SPI)
	._scs         ( {SPI_SS4,SPI_SS3,SPI_SS2}  ),  // SPI chip select spi_chipselect(6 downto 4),
	.direct_sdi   (SD_MISO          ),  // SD Card direct in  SPI_SDO
	.sdi          (SPI_DI           ),  // SPI data input
	.sdo          (SPI_DO           ),  // SPI data output
	.sck          (SPI_SCK          ),  // SPI clock
	//video
	.selcsync     (VGA_SELCS        ),
	._csync       (cs               ),  // horizontal sync
	._hsync       (hs               ),  // horizontal sync
	._vsync       (vs               ),  // vertical sync
	.red          (red              ),  // red
	.green        (green            ),  // green
	.blue         (blue             ),  // blue
	//audio
	.left         (                 ),  // audio bitstream left
	.right        (                 ),  // audio bitstream right
	.ldata        (AUDIO_L          ),  // left DAC data
	.rdata        (AUDIO_R          ),  // right DAC data
	//user i/o
	.cpu_config   (cpu_config       ), // CPU config
	.memcfg       (memcfg           ), // memory config
	.turbochipram (turbochipram     ), // turbo chipRAM
	.turbokick    (turbokick        ), // turbo kickstart
	.init_b       (                 ), // vertical sync for MCU (sync OSD update)
	.fifo_full    (                 ),
	// fifo / track display
	.trackdisp    (                 ),  // floppy track number
	.secdisp      (                 ),  // sector
	.floppy_fwr   (                 ),  // floppy fifo writing
	.floppy_frd   (                 ),  // floppy fifo reading
	.hd_fwr       (                 ),  // hd fifo writing
	.hd_frd       (                 ),  // hd fifo  ading
	.hblank_out   (hblank_out       ),
	.vblank_out   (vblank_out       ),
	.osd_blank_out(osd_window       ),  // Let the toplevel dither module handle drawing the OSD.
	.osd_pixel_out(osd_pixel        ),
	.rtg_ena      (rtg_ena          )
);


EightThirtyTwo_Bridge #( debug ? "true" : "false") hostcpu
(
	.clk(CLK_114),
	.nReset(reset_out),
	.data_in(hostdata),
	.addr(hostaddr[31:2]),
	.data_write(hostWR),
	.req(hostreq),
	.bytesel(hostbytesel),
	.ack(hostack),
	.wr(hostwe)
);


cfide #(.spimux(spimux ? "true" : "false")) mycfide
( 
		.sysclk(CLK_114),
		.n_reset(reset_out),
		.enaWR(tg68_enaWR),

		.memce(hostce),
		.cpuena_in(hostramena),
		.memdata_in(hostRD),
		.addr(hostaddr),
		.cpudata_in(hostWR),
		.cpu_bytesel(hostbytesel),
		.cpu_req(hostreq),
		.cpu_wr(hostwe),
		.cpu_ack(hostack),
		.cpudata(hostdata),

		.sd_di(SPI_DO),
		.sd_cs(SPI_CS),
		.sd_clk(SPI_SCK),
		.sd_do(SPI_DI),
		.sd_dimm(SD_MISO),
		.sd_ack(SD_ACK),

		.debugTxD(CTRL_TX),
		.debugRxD(CTRL_RX),
		.menu_button(MENU_BUTTON),
		.scandoubler(_15khz)
   );
	
endmodule

