PROJECT:=Tallbrood
AUTHOR:=simplex
VERSION:=2.0
API_VERSION:=2
DESCRIPTION:=A life cycle for Tallbirds.
FORUM_THREAD:=23974
FORUM_DOWNLOAD_ID:=330


PROJECT_lc:=$(shell echo $(PROJECT) | tr A-Z a-z)
SCRIPT_DIR:=scripts/$(PROJECT_lc)


include $(SCRIPT_DIR)/wicker/make/preamble.mk

FILES:=

THEMAIN:=$(SCRIPT_DIR)/main.lua
FILES+=$(THEMAIN)

GROUND_SCRIPTS:=modmain.lua modinfo.lua
FILES+=$(GROUND_SCRIPTS)

MISC_SCRIPTS:=$(foreach f, tallbird_logic.lua debugtools.lua, $(SCRIPT_DIR)/$(f))
FILES+=$(MISC_SCRIPTS)

PREFAB_SCRIPTS:=
COMPONENT_SCRIPTS:=$(call WICKER_ADD_COMPONENTS, nester.lua)
FILES+=$(PREFAB_SCRIPTS) $(COMPONENT_SCRIPTS)


LICENSE_FILES:=AUTHORS.txt COPYING.txt
IMAGE_FILES:=

FILES+=$(LICENSE_FILES) $(IMAGE_FILES)


include $(SCRIPT_DIR)/wicker/make/rules.mk
