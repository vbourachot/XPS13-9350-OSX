# makefile

#
# Patches/Installs/Builds DSDT patches for Dell XPS 13 9350
#
# Created by RehabMan
# Adapted by vbourachot for XPS 13 9350
#

# DSDT patch: from compiled acpi tables to installed patched dsdt/ssdt-1
# make distclean disassemble patch && make && make install
#
# AppleHDA patch: Create injector kext and install in SLE
# make patch_hda && sudo make install_hda
#
# Install Clover config
# make install_config

# Confirm location:
EFIVOL=/dev/disk1s1
EFIDIR=/Volumes/EFI

LAPTOPGIT=../Laptop-DSDT-Patch
DEBUGGIT=../OS-X-ACPI-Debug
BUILDDIR=./build
PATCHED=./patched
UNPATCHED=./unpatched
DISASSEMBLE_SCRIPT=./disassemble.sh
OSXV=10.11

PATCH_HDA_SCRIPT=./patch_hda.sh
HDACODEC=ALC256

NULLETHDIR=./null_eth
PATCH_RMNE_SCRIPT=./patch_null_eth_mac.sh

IASLFLAGSVERBOSE=-vr -w1
IASLFLAGS=-ve
IASL=/usr/local/bin/iasl
PATCHMATIC=/usr/local/bin/patchmatic

XMLLINT=xmllint --valid --noout
#XMLLINT=touch

# RehabMan's handy helper functions to identify PM SSDTs
# Name(_PPC, ...) identifies SSDT with _PPC
PPC=$(shell grep -l Name.*_PPC $(UNPATCHED)/SSDT*.dsl)
PPC:=$(subst $(UNPATCHED)/,,$(subst .dsl,,$(PPC)))

# Name(SSDT, Package...) identifies SSDT with dynamic SSDTs
DYN=$(shell grep -l Name.*SSDT.*Package $(UNPATCHED)/SSDT*.dsl)
DYN:=$(subst $(UNPATCHED)/,,$(subst .dsl,,$(DYN)))

# No IAOE device in skylake it seems.
#ADDLSSDT1=$(shell grep -l Device.*IAOE $(UNPATCHED)/SSDT*.dsl)
#ADDLSSDT1:=$(subst $(UNPATCHED)/,,$(subst .dsl,,$(ADDLSSDT1)))

# Do the same thing for the GPU ssdt while we're at it.
# Identified via Device (PEG0) in unpatched folder
# Device is actually defined in DSDT, but SSDT5 is GPU related
#GFXSSDT=$(shell grep -l Device.*PEG0 $(UNPATCHED)/SSDT*.dsl)
#GFXSSDT:=$(subst $(UNPATCHED)/,,$(subst .dsl,,$(GFXSSDT)))
GFXSSDT=SSDT-5

PRODUCTS=$(BUILDDIR)/dsdt.aml $(BUILDDIR)/$(GFXSSDT).aml $(BUILDDIR)/$(PPC).aml $(BUILDDIR)/$(DYN).aml $(BUILDDIR)/SSDT-0.aml $(BUILDDIR)/SSDT-3.aml $(BUILDDIR)/SSDT-4.aml $(BUILDDIR)/SSDT-6.aml


# Compile DSDT/SSDTs
all: $(PRODUCTS)

$(BUILDDIR)/dsdt.aml: $(PATCHED)/dsdt.dsl
	$(IASL) $(IASLFLAGS) -p $@ $<

$(BUILDDIR)/$(GFXSSDT).aml: $(PATCHED)/$(GFXSSDT).dsl
	$(IASL) $(IASLFLAGS) -p $@ $<

$(BUILDDIR)/$(PPC).aml: $(PATCHED)/$(PPC).dsl
	$(IASL) $(IASLFLAGS) -p $@ $<

$(BUILDDIR)/$(DYN).aml: $(PATCHED)/$(DYN).dsl
	$(IASL) $(IASLFLAGS) -p $@ $<

$(BUILDDIR)/SSDT-0.aml: $(PATCHED)/SSDT-0.dsl
	$(IASL) $(IASLFLAGS) -p $@ $<

$(BUILDDIR)/SSDT-3.aml: $(PATCHED)/SSDT-3.dsl
	$(IASL) $(IASLFLAGS) -p $@ $<

$(BUILDDIR)/SSDT-4.aml: $(PATCHED)/SSDT-4.dsl
	$(IASL) $(IASLFLAGS) -p $@ $<

# Clean everything but the disassembled unpatched dsdt
clean:
	rm -f $(PRODUCTS)
	rm -rf $(BUILDDIR)/AppleHDA_$(HDACODEC).kext
	rm -f $(PATCHED)/*.dsl

# Clean everything
distclean: clean
	rm -f $(UNPATCHED)/*.dsl


# Clover Install DSDT/SSDTs
install: $(PRODUCTS)
	if [ ! -d $(EFIDIR) ]; then mkdir $(EFIDIR) && diskutil mount -mountPoint $(EFIDIR) $(EFIVOL); fi
	cp $(BUILDDIR)/dsdt.aml $(EFIDIR)/EFI/CLOVER/ACPI/patched
	cp $(BUILDDIR)/$(PPC).aml $(EFIDIR)/EFI/CLOVER/ACPI/patched/
	cp $(BUILDDIR)/$(DYN).aml $(EFIDIR)/EFI/CLOVER/ACPI/patched/
	cp $(BUILDDIR)/$(GFXSSDT).aml $(EFIDIR)/EFI/CLOVER/ACPI/patched/
	cp $(BUILDDIR)/SSDT-0.aml $(EFIDIR)/EFI/CLOVER/ACPI/patched/
	cp $(BUILDDIR)/SSDT-3.aml $(EFIDIR)/EFI/CLOVER/ACPI/patched/
	cp $(BUILDDIR)/SSDT-4.aml $(EFIDIR)/EFI/CLOVER/ACPI/patched/
	diskutil unmount $(EFIDIR)
	if [ -d $(EFIDIR) ]; then rmdir $(EFIDIR); fi

# Patch with 'patchmatic'
patch:
	cp $(UNPATCHED)/dsdt.dsl $(UNPATCHED)/$(GFXSSDT).dsl $(UNPATCHED)/$(PPC).dsl $(UNPATCHED)/$(DYN).dsl $(UNPATCHED)/SSDT-0.dsl $(UNPATCHED)/SSDT-3.dsl $(UNPATCHED)/SSDT-4.dsl $(PATCHED)

	# Syntax
	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/syntax_dsdt.txt $(PATCHED)/dsdt.dsl
	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/SAT0._DSM.txt $(PATCHED)/dsdt.dsl
	perl -i -pe 's/_DSM/XDSM/g' $(PATCHED)/dsdt.dsl
	$(PATCHMATIC) $(PATCHED)/$(GFXSSDT).dsl $(LAPTOPGIT)/syntax/remove_DSM.txt $(PATCHED)/$(GFXSSDT).dsl

	# Audio
	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/rename-HDAS-HDEF.txt $(PATCHED)/dsdt.dsl
	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/audio.txt $(PATCHED)/dsdt.dsl
	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/system/system_IRQ.txt $(PATCHED)/dsdt.dsl

	# Brightness
	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/graphics/graphics_PNLF.txt $(PATCHED)/dsdt.dsl
	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/system_OSYS.txt $(PATCHED)/dsdt.dsl
	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/keyboard.txt $(PATCHED)/dsdt.dsl



#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/battery/battery_Dell-XPS-13.txt $(PATCHED)/dsdt.dsl

#	BREAKS?
#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/remove_wmi.txt $(PATCHED)/dsdt.dsl


#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/graphics/graphics_Rename-GFX0.txt $(PATCHED)/dsdt.dsl
#	$(PATCHMATIC) $(PATCHED)/$(GFXSSDT).dsl $(LAPTOPGIT)/graphics/graphics_Rename-GFX0.txt $(PATCHED)/$(GFXSSDT).dsl
#	$(PATCHMATIC) $(PATCHED)/$(GFXSSDT).dsl patches/hdmi_audio.txt $(PATCHED)/$(GFXSSDT).dsl

#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/usb/usb_7-series.txt $(PATCHED)/dsdt.dsl
#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/system/system_WAK2.txt $(PATCHED)/dsdt.dsl
#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/system/system_MCHC.txt $(PATCHED)/dsdt.dsl
#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/system/system_HPET.txt $(PATCHED)/dsdt.dsl
#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/system/system_RTC.txt $(PATCHED)/dsdt.dsl
#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/system/system_SMBUS.txt $(PATCHED)/dsdt.dsl
#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/system/system_Mutex.txt $(PATCHED)/dsdt.dsl
##	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/system/system_PNOT.txt $(PATCHED)/dsdt.dsl
#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/system/system_IMEI.txt $(PATCHED)/dsdt.dsl
#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/system/system_ADP1.txt $(PATCHED)/dsdt.dsl

#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/system/system_ADP1.txt $(PATCHED)/dsdt.dsl
##	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(LAPTOPGIT)/misc/misc_Haswell-LPC.txt $(PATCHED)/dsdt.dsl
#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/remove_GLAN.txt $(PATCHED)/dsdt.dsl
#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/rename_B0D3.txt $(PATCHED)/dsdt.dsl
##	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/fix_WAK.txt $(PATCHED)/dsdt.dsl
##	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/fix_OCNT.txt $(PATCHED)/dsdt.dsl
##	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/disable_wifi_switch.txt $(PATCHED)/dsdt.dsl
##	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/add_SMCD.txt $(PATCHED)/dsdt.dsl
##	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/lpss.txt $(PATCHED)/dsdt.dsl
##	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/usb_XHC1.txt $(PATCHED)/dsdt.dsl
#	$(PATCHMATIC) $(PATCHED)/$(PPC).dsl patches/syntax_ppc.txt $(PATCHED)/$(PPC).dsl

patch_debug: patch
	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(DEBUGGIT)/debug.txt $(PATCHED)/dsdt.dsl
	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(DEBUGGIT)/instrument_Qxx.txt $(PATCHED)/dsdt.dsl
#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(DEBUGGIT)/instrument_WAK_PTS.txt $(PATCHED)/dsdt.dsl
#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/instrument_TTS.txt $(PATCHED)/dsdt.dsl
	$(PATCHMATIC) $(PATCHED)/dsdt.dsl $(DEBUGGIT)/instrument_Lxx.txt $(PATCHED)/dsdt.dsl
#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/instrument_Qxx.txt $(PATCHED)/dsdt.dsl
#	$(PATCHMATIC) $(PATCHED)/dsdt.dsl patches/instrument_SBUS.txt $(PATCHED)/dsdt.dsl


# Disassemble DSDT/SSDTs from linux_native/ acpi extract
disassemble:
	$(DISASSEMBLE_SCRIPT)

# Get ACPI tables from CLOVER EFI/CLOVER/ACPI/origin/
get_acpi:
	if [ ! -d $(EFIDIR) ]; then mkdir $(EFIDIR) && diskutil mount -mountPoint $(EFIDIR) $(EFIVOL); fi
	cp $(EFIDIR)/EFI/CLOVER/ACPI/origin/* ./origin/
	diskutil unmount $(EFIDIR)
	if [ -d $(EFIDIR) ]; then rmdir $(EFIDIR); fi


# Patch AppleHDA for ALC256 codec
patch_hda:
	$(PATCH_HDA_SCRIPT)

# Install AppleHDA_ALC256.kext injector in SLE
install_hda:
	if [ -d /System/Library/Extensions/AppleHDA_$(HDACODEC).kext ]; \
	then rm -rf /System/Library/Extensions/AppleHDA_$(HDACODEC).kext && cp -R $(BUILDDIR)/AppleHDA_$(HDACODEC).kext /System/Library/Extensions/; \
	else cp -R $(BUILDDIR)/AppleHDA_$(HDACODEC).kext /System/Library/Extensions/; fi
	touch /System/Library/Extensions


# Install Clover config.plist
# Appends smbios info if ./config.plist.smbios exists
install_config:
	if [ -f ./config.plist.smbios ]; then \
		./config_append_smbios.sh && \
		$(XMLLINT) ./config.plist.local; \
	else \
		$(XMLLINT) ./config.plist; \
	fi
	if [ ! -d $(EFIDIR) ]; then mkdir $(EFIDIR) && diskutil mount -mountPoint $(EFIDIR) $(EFIVOL); fi
	if [ -f ./config.plist.smbios ]; then \
		cp ./config.plist.local $(EFIDIR)/EFI/CLOVER/config.plist; \
		diff ./config.plist $(EFIDIR)/EFI/CLOVER/config.plist || exit 0; \
	else \
		cp ./config.plist $(EFIDIR)/EFI/CLOVER/; \
	fi
	diskutil unmount $(EFIDIR)
	if [ -d $(EFIDIR) ]; then rmdir $(EFIDIR); fi


null_eth:
	$(PATCH_RMNE_SCRIPT)
	$(IASL) $(IASLFLAGS) -p $(BUILDDIR)/ssdt-rmne_rand_mac.aml $(NULLETHDIR)/ssdt-rmne_rand_mac.dsl

# Install null ethernet ssdt
install_null_eth: null_eth
	if [ ! -d $(EFIDIR) ]; then mkdir $(EFIDIR) && diskutil mount -mountPoint $(EFIDIR) $(EFIVOL); fi
	cp $(BUILDDIR)/ssdt-rmne_rand_mac.aml $(EFIDIR)/EFI/CLOVER/ACPI/patched/ssdt-5.aml
	diskutil unmount $(EFIDIR)
	if [ -d $(EFIDIR) ]; then rmdir $(EFIDIR); fi


.PHONY: all clean distclean patch patch_debug install \
		get_acpi disassemble patch_hda install_hda \
		install_config null_eth install_null_eth

# native correlations
# ssdt-0 - sataTabl - ok
# ssdt-1 - sensrhub - ko
# ssdt-2 - PtidDevc
# ssdt-3 - Ther_Rvp - ok
# ssdt-4 - xh_rvp07 - ok (xhc related)
# ssdt-5 - SaSsdt - ok 
# ssdt-6 - CpuSsdt - ok
# ssdt-14 - DptfTabl - ok



# ssdt-0 - sensrhub
# ssdt-1 - PtidDevc
# ssdt-2 - Cpu0Ist
# ssdt-3 - CpuPm
# ssdt-7 - SaSsdt (gfx0)
# ssdt-8 - TpmTable
# ssdt-9 - IsctTabl Defines Device IAOE for _PST
# ssdtxx - PmRef - Cpu0Cst (dynamic)
# ssdtxx - PmRef - ApIst (dynamic)
# ssdtxx - PmRef - ApCst (dynamic)

