##############################################################################
HEXTARGETS +=	JukeBox.hex
				JukeBox_PROCESSOR			= 16F19156

##############################################################################
all: $(HEXTARGETS)

##############################################################################
SOURCE 			=	JukeBox.pbp \
					LCD4x20.pbp \
					EEPROM.pbp \
					ProcessorConfiguration.pbp

##############################################################################
JukeBox.hex				: $(SOURCE)

##############################################################################
$(HEXTARGETS):
	pbpx -ampasmx -oq -p$($(basename $<)_PROCESSOR) $<
	@del $(basename $<).asm
	@del $(basename $<).mac
	@del $(basename $<).o
	@del $(basename $<).err
	@del $(basename $<).lst

##############################################################################

