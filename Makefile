PROJECT:=Tallbrood
AUTHOR:=simplex
VERSION:=2.0
API_VERSION:=2
DESCRIPTION:=A life cycle for Tallbirds.
FORUM_THREAD:=23974
FORUM_DOWNLOAD_ID:=330


PROJECT_lc:=$(shell echo $(PROJECT) | tr A-Z a-z)

ICON_DIR:=favicon

ICON:=$(ICON_DIR)/$(PROJECT_lc).tex
ICON_ATLAS:=$(ICON_DIR)/$(PROJECT_lc).xml

SCRIPT_DIR:=scripts/$(PROJECT_lc)

THEMAIN:=$(SCRIPT_DIR)/main.lua
GROUND_SCRIPTS:=modmain.lua modinfo.lua
CONFIGURATION_SCRIPTS:=rc.lua $(SCRIPT_DIR)/rc/defaults.lua $(SCRIPT_DIR)/rc/schema.lua
BASE_SCRIPTS:=$(foreach f, utils.lua, $(SCRIPT_DIR)/$(f))
API_SCRIPTS:=$(foreach f, core.lua init.lua themod.lua, $(SCRIPT_DIR)/api/$(f))
UTIL_SCRIPTS:=$(foreach f, algo.lua game.lua io.lua string.lua table.lua table/core.lua table/tree.lua table/tree/core.lua table/tree/dfs.lua time.lua, $(SCRIPT_DIR)/utils/$(f))
PARADIGM_SCRIPTS:=$(foreach f, functional.lua logic.lua, $(SCRIPT_DIR)/paradigms/$(f))
LIB_SCRIPTS:=$(foreach f, predicates.lua searchspace.lua, $(SCRIPT_DIR)/lib/$(f))
GADGET_SCRIPTS:=$(foreach f, configurable.lua debuggable.lua eventchain.lua, $(SCRIPT_DIR)/gadgets/$(f))
MISC_SCRIPTS:=$(foreach f, src/tallbird_logic.lua src/debugtools.lua, $(SCRIPT_DIR)/$(f))

COMPONENT_LIST:=nester.lua
PREFAB_LIST:=

COMPONENT_SCRIPTS:=$(foreach f, $(COMPONENT_LIST), scripts/components/$(f)) $(foreach f, $(COMPONENT_LIST), $(SCRIPT_DIR)/components/$(f))

PREFAB_LIST:=$(foreach f, $(PREFAB_LIST), scripts/prefabs/$(f)) $(foreach f, $(PREFAB_LIST), $(SCRIPT_DIR)/prefabs/$(f))

FILES=$(THEMAIN) $(GROUND_SCRIPTS) $(CONFIGURATION_SCRIPTS) $(BASE_SCRIPTS) $(API_SCRIPTS) $(UTIL_SCRIPTS) $(PARADIGM_SCRIPTS) $(LIB_SCRIPTS) $(GADGET_SCRIPTS) $(MISC_SCRIPTS) $(COMPONENT_SCRIPTS) $(PREFAB_SCRIPTS)

LICENSE_FILES:=AUTHORS.txt COPYING.txt
IMAGE_FILES:=$(ICON) $(ICON_ATLAS)

FILES+=$(LICENSE_FILES) $(IMAGE_FILES)


.PHONY: dist rc rc.lua count modmain.lua modinfo.lua $(THEMAIN) boot

SHELL:=/usr/bin/bash

define MOD_INFO =
--[[
Copyright (C) 2013  $(AUTHOR)

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

The file $(ICON) is based on textures from Klei Entertainment's
Don't Starve and is not covered under the terms of this license.
]]--

name = "$(PROJECT)"
version = "$(VERSION)"
author = "$(AUTHOR)"


description = "$(DESCRIPTION)"
forumthread = "$(FORUM_THREAD)"


api_version = $(API_VERSION)
icon = "$(ICON)"
icon_atlas = "$(ICON_ATLAS)"
endef
export MOD_INFO

PROJECT_NAME:=$(PROJECT)
PROJECT_VERSION:=$(VERSION)
PROJECT_AUTHOR=$(AUTHOR)
PROJECT_FORUM_THREAD=$(FORUM_THREAD)
PROJECT_FORUM_DOWNLOAD_ID=$(FORUM_DOWNLOAD_ID)
export PROJECT_NAME
export PROJECT_VERSION
export PROJECT_AUTHOR
export PROJECT_FORUM_THREAD
export PROJECT_FORUM_DOWNLOAD_ID

dist: $(PROJECT).zip

boot: tools/bootup_gen.pl
	find "$(SCRIPT_DIR)" -type f -name '*.lua' -exec perl "$<" '{}' \;

modmain.lua: tools/touch_modmain.pl
	perl -i $< $@

$(THEMAIN): tools/touch_modmain.pl
	perl -i $< $@

modinfo.lua:
	echo "$$MOD_INFO" > $@

# Please don't run this inside a symbolic link.
CURDIR_TAIL:=$(notdir $(CURDIR))
$(PROJECT).zip: $(FILES) Post.discussion Post.upload
	echo -e "$$PROJECT_NAME $$PROJECT_VERSION (http://forums.kleientertainment.com/showthread.php?$$PROJECT_FORUM_THREAD).\nCreated by $$PROJECT_AUTHOR.\nPackaged on `date +%F`." | \
		( cd ..; zip -FS -8 --archive-comment $(CURDIR)/$(PROJECT).zip $(foreach f, $(FILES), $(CURDIR_TAIL)/$(f)) )

Post.discussion: ./tools/postman.pl Post.template rc.example.lua
	$< discussion < Post.template > $@

Post.upload: ./tools/postman.pl Post.template rc.example.lua
	$< upload < Post.template > $@

rc: ./tools/rc_gen.pl rc.template.lua
	$< rc < rc.template.lua > rc.lua
	$< rc.defaults < rc.template.lua > $(SCRIPT_DIR)/rc/defaults.lua
	$< rc.example < rc.template.lua > rc.example.lua

rc.defaults.lua: rc

rc.lua: rc

$(SCRIPT_DIR)/rc/defaults.lua: rc.lua

rc.example.lua: rc

count: $(filter-out $(LICENSE_FILES), $(FILES))
	@(for i in $^; do [[ "$$(file -bi "$$i")" =~ "text/" ]] && wc -l $$i; done) | sort -s -g | perl -e '$$t = 0; while($$l = <>){ $$t += $$l; print $$l; } print "Total: $$t\n";'
