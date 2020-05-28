/*
Copyright 2005, 2006, 2007 Dennis van Weeren
Copyright 2008, 2009 Jakub Bednarski

This file is part of Minimig

Minimig is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

Minimig is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

// 2008-10-04   - porting to ARM
// 2008-10-06   - support for 4 floppy drives
// 2008-10-30   - hdd write support
// 2009-05-01   - subdirectory support
// 2009-06-26   - SDHC and FAT32 support
// 2009-08-10   - hardfile selection
// 2009-09-11   - minor changes to hardware initialization routine
// 2009-10-10   - any length fpga core file support
// 2009-11-14   - adapted floppy gap size
//              - changes to OSD labels
// 2009-12-24   - updated version number
// 2010-01-09   - changes to floppy handling
// 2010-07-28   - improved menu button handling
//              - improved FPGA configuration routines
//              - added support for OSD vsync
// 2010-08-15   - support for joystick emulation
// 2010-08-18   - clean-up

// FIXME - detect number of partitions on the SD card, and allow that many to be selected as hard files.

//#include "AT91SAM7S256.h"
//#include "stdio.h"
//#include "string.h"
#include "errors.h"
#include "boot.h"
#include "hardware.h"
#include "mmc.h"
#include "fat.h"
#include "osd.h"
#include "fpga.h"
#include "fdd.h"
#include "hdd.h"
#include "firmware.h"
#include "menu.h"
#include "config.h"

#include <stdio.h>

const char version[] = "$VER:AYQ200515_832";

extern adfTYPE df[4];

char s[40];

#if 0
void FatalError(unsigned long error)
{
    unsigned long i;

    sprintf(s,"Fatal error: %lu\n", error);
	BootPrintEx(s);

    while (1)
    {
        for (i = 0; i < error; i++)
        {
            DISKLED_ON;
            WaitTimer(250);
            DISKLED_OFF;
            WaitTimer(250);
        }
        WaitTimer(1000);
    }
}
#endif


void HandleFpga(void)
{
    unsigned char  c1, c2;

    EnableFpga();
    c1 = SPI(0); // cmd request and drive number
    c2 = SPI(0); // track number
    SPI(0);
    SPI(0);
    SPI(0);
    SPI(0);
    DisableFpga();

    HandleFDD(c1, c2);
    HandleHDD(c1, c2);

    UpdateDriveStatus();
}


void ColdBoot()
{
	/* Reset the chipset briefly to cancel AGA display modes, then Put the CPU in reset while we initialise */
	OsdDoReset(SPI_RST_USR | SPI_RST_CPU | SPI_CPU_HLT,SPI_RST_CPU | SPI_CPU_HLT);

	ErrorMask=0;

    if (MMC_Init())
	{
	    if (FindDrive())
		{
			int key;
			int override=0;
		    ChangeDirectory(DIRECTORY_ROOT);

			config.kickstart.name[0]=0;
			SetConfigurationFilename(0); // Use default config
		    LoadConfiguration(0);	// Use slot-based config filename
			ApplyConfiguration(0);  // Setup screenmodes, etc before loading KickStart.

			fpga_init();	// Display splashscreen

			key = OsdGetCtrl();
			sprintf(s,"Got key: %x\n",key);
			BootPrint(s);
			if ((key == KEY_F1) || (key == KEY_F3))
			{
				override=1;
				config.chipset |= CONFIG_NTSC; // force NTSC mode if F1 or F3 pressed
			}

			if ((key == KEY_F2) || (key == KEY_F4))
			{
				override=1;
				config.chipset &= ~CONFIG_NTSC; // force PAL mode if F2 or F4 pressed
			}

			// FIXME - new interface for scandoubler?
			if ((key == KEY_F3) || (key == KEY_F4))
			{
				override=1;
				config.misc &= ~(1<<(PLATFORM_SCANDOUBLER));	// High byte of platform register
			}

			if ((key == KEY_F1) || (key == KEY_F2))
			{
				override=1;
				config.misc |= 1<<(PLATFORM_SCANDOUBLER);  // High byte of platform register
			}

			if(override)
			{
				BootPrintEx("Overriding screenmode.");
				ApplyConfiguration(0);
//				OsdDoReset(SPI_RST_USR | SPI_RST_CPU | SPI_CPU_HLT,SPI_RST_CPU | SPI_CPU_HLT);
			}

			BootPrintEx("Loading kickstart ROM...");
			ApplyConfiguration(1);
			OsdDoReset(SPI_RST_USR | SPI_RST_CPU,0);
		}
	}
}


void setstack();
#ifdef __GNUC__
void c_entry(void)
#else
__geta4 int main(void)
#endif
{
	setstack();
	debugmsg[0]=0;
	debugmsg2[0]=0;

    DISKLED_ON;

	ColdBoot();

    sprintf(s, "Firmware %s **\n", version + 5);
	printf(s);
    BootPrintEx(s);

    while (1)
    {
        HandleFpga();
        HandleUI();
		if(ErrorMask)
		{
			ShowError();
			while(ErrorMask)
		        HandleUI();
		}
    }
}

