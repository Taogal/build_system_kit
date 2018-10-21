#
# Main Project Makefile
# This Makefile is included directly from the user project Makefile in order to call the component.mk
# makefiles of all components (in a separate make process) to build all the libraries, then links them
# together into the final file. If so, PWD is the project dir (we assume).
#

#
# This makefile requires the environment variable BSD_PATH to be set to the top-level Build System Kit directory
# where this file is located.
#

.PHONY: build-components menuconfig defconfig all build clean distclean check-submodules list-components

MAKECMDGOALS ?= all
all: $(APP)
# see below for recipe of 'all' target
#
# # other components will add dependencies to 'all_binaries'. The
# reason all_binaries is used instead of 'all' is so that the flash
# target can build everything without triggering the per-component "to
# flash..." output targets.)

help:
	@echo "Welcome to BSD build system. Some useful make targets:"
	@echo ""
	@echo "make menuconfig - Configure BSD project"
	@echo "make defconfig - Set defaults for all new configuration options"
	@echo ""
	@echo "make all - Build app"
	@echo "make clean - Remove include app-clean config-clean"
	@echo "make distclean - Remove all build output"
	@echo "make list-components - List all components in the project"
	@echo ""
	@echo "make app - Build just the app"
	@echo "make app-clean - Clean just the app"
	@echo ""

# Non-interactive targets. Mostly, those for which you do not need to build a binary
NON_INTERACTIVE_TARGET += defconfig clean% %clean help list-components print_flash_cmd

# dependency checks
ifndef MAKE_RESTARTS
ifeq ("$(filter 4.% 3.81 3.82,$(MAKE_VERSION))","")
$(warning Build System Kit only supports GNU Make versions 3.81 or newer. You may see unexpected results with other Makes.)
endif

ifdef MSYSTEM
ifneq ("$(MSYSTEM)","MINGW32")
$(warning Build System Kit only supports MSYS2 in "MINGW32" mode. Consult the Build System Kit documentation for details.)
endif
endif  # MSYSTEM

endif  # MAKE_RESTARTS

# can't run 'clean' along with any non-clean targets
ifneq ("$(filter clean% %clean,$(MAKECMDGOALS))" ,"")
ifneq ("$(filter-out clean% %clean,$(MAKECMDGOALS))", "")
$(error Build System Kit doesn't support running 'clean' targets along with any others. Run 'make clean' and then run other targets separately.)
endif
endif

OS ?=

# make BSD_PATH a "real" absolute path
# * works around the case where a shell character is embedded in the environment variable value.
# * changes Windows-style C:/blah/ paths to MSYS style /c/blah
ifeq ("$(OS)","Windows_NT")
# On Windows MSYS2, make wildcard function returns empty string for paths of form /xyz
# where /xyz is a directory inside the MSYS root - so we don't use it.
SANITISED_BSD_PATH:=$(realpath $(BSD_PATH))
else
SANITISED_BSD_PATH:=$(realpath $(wildcard $(BSD_PATH)))
endif

export BSD_PATH := $(SANITISED_BSD_PATH)

ifndef BSD_PATH
$(error BSD_PATH variable is not set to a valid directory.)
endif

ifneq ("$(BSD_PATH)","$(SANITISED_BSD_PATH)")
# implies BSD_PATH was overriden on make command line.
# Due to the way make manages variables, this is hard to account for
#
# if you see this error, do the shell expansion in the shell ie
# make BSD_PATH=~/blah not make BSD_PATH="~/blah"
$(error If BSD_PATH is overriden on command line, it must be an absolute path with no embedded shell special characters)
endif

ifneq ("$(BSD_PATH)","$(subst :,,$(BSD_PATH))")
$(error BSD_PATH cannot contain colons. If overriding BSD_PATH on Windows, use MSYS Unix-style /c/dir instead of C:/dir)
endif

# disable built-in make rules, makes debugging saner
MAKEFLAGS_OLD := $(MAKEFLAGS)
MAKEFLAGS +=-rR

# Default path to the project: we assume the Makefile including this file
# is in the project directory
ifndef PROJECT_PATH
PROJECT_PATH := $(abspath $(dir $(firstword $(MAKEFILE_LIST))))
export PROJECT_PATH
endif

# A list of the "common" makefiles, to use as a target dependency
COMMON_MAKEFILES := $(abspath $(BSD_PATH)/make/project.mk $(BSD_PATH)/make/common.mk $(BSD_PATH)/make/component_wrapper.mk $(firstword $(MAKEFILE_LIST)))
export COMMON_MAKEFILES

# The directory where we put all objects/libraries/binaries. The project Makefile can
# configure this if needed.
ifndef BUILD_DIR_BASE
BUILD_DIR_BASE := $(PROJECT_PATH)/build
endif
export BUILD_DIR_BASE

# Component directories. These directories are searched for components (either the directory is a component,
# or the directory contains subdirectories which are components.)
# The project Makefile can override these component dirs, or add extras via EXTRA_COMPONENT_DIRS
ifndef COMPONENT_DIRS
EXTRA_COMPONENT_DIRS ?=
COMPONENT_DIRS := $(PROJECT_PATH)/components $(EXTRA_COMPONENT_DIRS) $(BSD_PATH)/components $(PROJECT_PATH)/main
endif
export COMPONENT_DIRS

ifdef SRCDIRS
$(warning SRCDIRS variable is deprecated. These paths can be added to EXTRA_COMPONENT_DIRS or COMPONENT_DIRS instead.)
COMPONENT_DIRS += $(abspath $(SRCDIRS))
endif

# The project Makefile can define a list of components, but if it does not do this we just take all available components
# in the component dirs. A component is COMPONENT_DIRS directory, or immediate subdirectory,
# which contains a component.mk file.
#
# Use the "make list-components" target to debug this step.
ifndef COMPONENTS
# Find all component names. The component names are the same as the
# directories they're in, so /bla/components/mycomponent/component.mk -> mycomponent.
COMPONENTS := $(dir $(foreach cd,$(COMPONENT_DIRS),                           \
					$(wildcard $(cd)/*/component.mk) $(wildcard $(cd)/component.mk) \
				))
COMPONENTS := $(sort $(foreach comp,$(COMPONENTS),$(lastword $(subst /, ,$(comp)))))
endif
# After a full manifest of component names is determined, subtract the ones explicitly omitted by the project Makefile.
ifdef EXCLUDE_COMPONENTS
COMPONENTS := $(filter-out $(EXCLUDE_COMPONENTS), $(COMPONENTS))
endif
export COMPONENTS

# Resolve all of COMPONENTS into absolute paths in COMPONENT_PATHS.
#
# If a component name exists in multiple COMPONENT_DIRS, we take the first match.
#
# NOTE: These paths must be generated WITHOUT a trailing / so we
# can use $(notdir x) to get the component name.
COMPONENT_PATHS := $(foreach comp,$(COMPONENTS),$(firstword $(foreach cd,$(COMPONENT_DIRS),$(wildcard $(dir $(cd))$(comp) $(cd)/$(comp)))))
export COMPONENT_PATHS

TEST_COMPONENTS ?=
TESTS_ALL ?=

# If TESTS_ALL set to 1, set TEST_COMPONENTS_LIST to all components.
# Otherwise, use the list supplied in TEST_COMPONENTS.
ifeq ($(TESTS_ALL),1)
TEST_COMPONENTS_LIST := $(COMPONENTS)
else
TEST_COMPONENTS_LIST := $(TEST_COMPONENTS)
endif

TEST_COMPONENT_PATHS := $(foreach comp,$(TEST_COMPONENTS_LIST),$(firstword $(foreach dir,$(COMPONENT_DIRS),$(wildcard $(dir)/$(comp)/test))))
TEST_COMPONENT_NAMES := $(foreach comp,$(TEST_COMPONENT_PATHS),$(lastword $(subst /, ,$(dir $(comp))))_test)

# Initialise project-wide variables which can be added to by
# each component.
#
# These variables are built up via the component_project_vars.mk
# generated makefiles (one per component).
#
# See docs/build-system.rst for more details.
COMPONENT_INCLUDES :=
COMPONENT_LDFLAGS :=
COMPONENT_SUBMODULES :=
COMPONENT_LIBRARIES :=

# COMPONENT_PROJECT_VARS is the list of component_project_vars.mk generated makefiles
# for each component.
#
# Including $(COMPONENT_PROJECT_VARS) builds the COMPONENT_INCLUDES,
# COMPONENT_LDFLAGS variables and also targets for any inter-component
# dependencies.
#
# See the component_project_vars.mk target in component_wrapper.mk
COMPONENT_PROJECT_VARS := $(addsuffix /component_project_vars.mk,$(notdir $(COMPONENT_PATHS) ) $(TEST_COMPONENT_NAMES))
COMPONENT_PROJECT_VARS := $(addprefix $(BUILD_DIR_BASE)/,$(COMPONENT_PROJECT_VARS))
# this line is -include instead of include to prevent a spurious error message on make 3.81
-include $(COMPONENT_PROJECT_VARS)

# Also add top-level project include path, for top-level includes
COMPONENT_INCLUDES += $(abspath $(BUILD_DIR_BASE)/include/)

export COMPONENT_INCLUDES

# Set variables common to both project & component
include $(BSD_PATH)/make/common.mk

# If we have `version.txt` then prefer that for extracting BSD version
ifeq ("$(wildcard ${BSD_PATH}/version.txt)","")
BSD_VER := $(shell cd ${BSD_PATH} && git describe --always --tags --dirty)
else
BSD_VER := `cat ${BSD_PATH}/version.txt`
endif

# Set default LDFLAGS
EXTRA_LDFLAGS ?=
LDFLAGS ?= $(EXTRA_LDFLAGS) \
	$(COMPONENT_LDFLAGS) \
	-lgcc \
	-lstdc++ \
	-Wl,-EL

# Set default CPPFLAGS, CFLAGS, CXXFLAGS
# These are exported so that components can use them when compiling.
# If you need your component to add CFLAGS/etc for it's own source compilation only, set CFLAGS += in your component's Makefile.
# If you need your component to add CFLAGS/etc globally for all source
#  files, set CFLAGS += in your component's Makefile.projbuild
# If you need to set CFLAGS/CPPFLAGS/CXXFLAGS at project level, set them in application Makefile
#  before including project.mk. Default flags will be added before the ones provided in application Makefile.

# CPPFLAGS used by C preprocessor
# If any flags are defined in application Makefile, add them at the end. 
CPPFLAGS ?=
EXTRA_CPPFLAGS ?=
CPPFLAGS := -D BSD_VER=\"$(BSD_VER)\" -MMD -MP $(CPPFLAGS) $(EXTRA_CPPFLAGS)

# Warnings-related flags relevant both for C and C++
COMMON_WARNING_FLAGS = -Wall -Werror=all \
	-Wno-error=unused-function \
	-Wno-error=unused-variable \
	-Wno-error=deprecated-declarations \
	-Wextra \
	-Wno-unused-parameter -Wno-sign-compare

ifdef CONFIG_WARN_WRITE_STRINGS
COMMON_WARNING_FLAGS += -Wwrite-strings
endif #CONFIG_WARN_WRITE_STRINGS

# Flags which control code generation and dependency generation, both for C and C++
COMMON_FLAGS = \
	-ffunction-sections -fdata-sections \
	-fstrict-volatile-bitfields

ifndef IS_BOOTLOADER_BUILD
# stack protection (only one option can be selected in menuconfig)
ifdef CONFIG_STACK_CHECK_NORM
COMMON_FLAGS += -fstack-protector
endif
ifdef CONFIG_STACK_CHECK_STRONG
COMMON_FLAGS += -fstack-protector-strong
endif
ifdef CONFIG_STACK_CHECK_ALL
COMMON_FLAGS += -fstack-protector-all
endif
endif

# Optimization flags are set based on menuconfig choice
ifdef CONFIG_OPTIMIZATION_LEVEL_RELEASE
OPTIMIZATION_FLAGS = -Os
else
OPTIMIZATION_FLAGS = -Og
endif

ifdef CONFIG_OPTIMIZATION_ASSERTIONS_DISABLED
CPPFLAGS += -DNDEBUG
endif

# Enable generation of debugging symbols
# (we generate even in Release mode, as this has no impact on final binary size.)
DEBUG_FLAGS ?= -ggdb

# List of flags to pass to C compiler
# If any flags are defined in application Makefile, add them at the end.
CFLAGS ?=
CFLAGS := $(strip \
	-std=gnu99 \
	$(DEBUG_FLAGS) \
	$(COMMON_WARNING_FLAGS) \
	$(CFLAGS))
# List of flags to pass to C++ compiler
# If any flags are defined in application Makefile, add them at the end.
CXXFLAGS ?=
EXTRA_CXXFLAGS ?=
CXXFLAGS := $(strip \
	-std=gnu++11 \
	-fno-rtti \
	$(OPTIMIZATION_FLAGS) $(DEBUG_FLAGS) \
	$(COMMON_FLAGS) \
	$(COMMON_WARNING_FLAGS) \
	$(CXXFLAGS) \
	$(EXTRA_CXXFLAGS))

ifdef CONFIG_CXX_EXCEPTIONS
CXXFLAGS += -fexceptions
else
CXXFLAGS += -fno-exceptions
endif

export CFLAGS CPPFLAGS CXXFLAGS

# Set default values that were not previously defined
CC ?= gcc
LD ?= ld
AR ?= ar
OBJCOPY ?= objcopy
SIZE ?= size

# Set host compiler and binutils
HOSTCC := $(CC)
HOSTLD := $(LD)
HOSTAR := $(AR)
HOSTOBJCOPY := $(OBJCOPY)
HOSTSIZE := $(SIZE)
export HOSTCC HOSTLD HOSTAR HOSTOBJCOPY SIZE

# Set target compiler. Defaults to whatever the user has
# configured as prefix + ye olde gcc commands
CC := $(call dequote,$(CONFIG_TOOLPREFIX))gcc
CXX := $(call dequote,$(CONFIG_TOOLPREFIX))c++
LD := $(call dequote,$(CONFIG_TOOLPREFIX))ld
AR := $(call dequote,$(CONFIG_TOOLPREFIX))ar
OBJCOPY := $(call dequote,$(CONFIG_TOOLPREFIX))objcopy
SIZE := $(call dequote,$(CONFIG_TOOLPREFIX))size
export CC CXX LD AR OBJCOPY SIZE

PYTHON=$(call dequote,$(CONFIG_PYTHON))

# the app is the main executable built by the project
APP:=$(BUILD_DIR_BASE)/$(PROJECT_NAME)
APP_ELF:=$(BUILD_DIR_BASE)/$(PROJECT_NAME).elf
APP_MAP:=$(APP_ELF:.elf=.map)
APP_BIN:=$(APP_ELF:.elf=.bin)

# Include any Makefile.projbuild file letting components add
# configuration at the project level
define includeProjBuildMakefile
$(if $(V),$$(info including $(1)/Makefile.projbuild...))
COMPONENT_PATH := $(1)
include $(1)/Makefile.projbuild
endef
$(foreach componentpath,$(COMPONENT_PATHS), \
	$(if $(wildcard $(componentpath)/Makefile.projbuild), \
		$(eval $(call includeProjBuildMakefile,$(componentpath)))))

# once we know component paths, we can include the config generation targets
include $(BSD_PATH)/make/project_config.mk

# ELF depends on the library archive files for COMPONENT_LIBRARIES
# the rules to build these are emitted as part of GenerateComponentTarget below
#
# also depends on additional dependencies (linker scripts & binary libraries)
# stored in COMPONENT_LINKER_DEPS, built via component.mk files' COMPONENT_ADD_LINKER_DEPS variable
COMPONENT_LINKER_DEPS ?=
$(APP_ELF): $(foreach libcomp,$(COMPONENT_LIBRARIES),$(BUILD_DIR_BASE)/$(libcomp)/lib$(libcomp).a) $(COMPONENT_LINKER_DEPS) $(COMPONENT_PROJECT_VARS)
	$(summary) LD $(patsubst $(PWD)/%,%,$@)
	$(CC) $(LDFLAGS) -o $@ -Wl,-Map=$(APP_MAP)

$(APP): $(foreach libcomp,$(COMPONENT_LIBRARIES),$(BUILD_DIR_BASE)/$(libcomp)/lib$(libcomp).a)
	$(summary) LD $(patsubst $(PWD)/%,%,$@)
	$(CC) $(LDFLAGS) $^ -o $@
	
app: $(APP) $(APP_ELF)
	@echo "App built..."


$(BUILD_DIR_BASE):
	mkdir -p $(BUILD_DIR_BASE)

# Macro for the recursive sub-make for each component
# $(1) - component directory
# $(2) - component name only
#
# Is recursively expanded by the GenerateComponentTargets macro
define ComponentMake
+$(MAKE) -C $(BUILD_DIR_BASE)/$(2) -f $(BSD_PATH)/make/component_wrapper.mk COMPONENT_MAKEFILE=$(1)/component.mk COMPONENT_NAME=$(2)
endef

# Generate top-level component-specific targets for each component
# $(1) - path to component dir
# $(2) - name of component
#
define GenerateComponentTargets
.PHONY: component-$(2)-build component-$(2)-clean

component-$(2)-build: check-submodules $(call prereq_if_explicit, component-$(2)-clean) | $(BUILD_DIR_BASE)/$(2)
	$(call ComponentMake,$(1),$(2)) build

component-$(2)-clean: | $(BUILD_DIR_BASE)/$(2) $(BUILD_DIR_BASE)/$(2)/component_project_vars.mk
	$(call ComponentMake,$(1),$(2)) clean

$(BUILD_DIR_BASE)/$(2):
	@mkdir -p $(BUILD_DIR_BASE)/$(2)

# tell make it can build any component's library by invoking the -build target
# (this target exists for all components even ones which don't build libraries, but it's
# only invoked for the targets whose libraries appear in COMPONENT_LIBRARIES and hence the
# APP_ELF dependencies.)
$(BUILD_DIR_BASE)/$(2)/lib$(2).a: component-$(2)-build
	$(details) "Target '$$^' responsible for '$$@'" # echo which build target built this file

# add a target to generate the component_project_vars.mk files that
# are used to inject variables into project make pass (see matching
# component_project_vars.mk target in component_wrapper.mk).
#
# If any component_project_vars.mk file is out of date, the make
# process will call this target to rebuild it and then restart.
#
$(BUILD_DIR_BASE)/$(2)/component_project_vars.mk: $(1)/component.mk $(COMMON_MAKEFILES) $(SDKCONFIG_MAKEFILE) | $(BUILD_DIR_BASE)/$(2)
	$(call ComponentMake,$(1),$(2)) component_project_vars.mk
endef

$(foreach component,$(COMPONENT_PATHS),$(eval $(call GenerateComponentTargets,$(component),$(notdir $(component)))))
$(foreach component,$(TEST_COMPONENT_PATHS),$(eval $(call GenerateComponentTargets,$(component),$(lastword $(subst /, ,$(dir $(component))))_test)))

app-clean: $(addprefix component-,$(addsuffix -clean,$(notdir $(COMPONENT_PATHS))))
	$(summary) RM $(APP_ELF)
	rm -f $(APP_ELF) $(APP_BIN) $(APP_MAP) $(APP)
	
build-clean:
	$(summary) RM $(BUILD_DIR_BASE)
	rm -rf $(BUILD_DIR_BASE)

# NB: this ordering is deliberate (app-clean & bootloader-clean before
# _config-clean), so config remains valid during all component clean
# targets
config-clean: app-clean
clean: app-clean config-clean
distclean: clean build-clean

# phony target to check if any git submodule listed in COMPONENT_SUBMODULES are missing
# or out of date, and exit if so. Components can add paths to this variable.
#
# This only works for components inside BSD_PATH
check-submodules:
# Check if .gitmodules exists, otherwise skip submodule check, assuming flattened structure
ifneq ("$(wildcard ${BSD_PATH}/.gitmodules)","")

# Dump the git status for the whole working copy once, then grep it for each submodule. This saves a lot of time on Windows.
GIT_STATUS := $(shell cd ${BSD_PATH} && git status --porcelain --ignore-submodules=dirty)

# Generate a target to check this submodule
# $(1) - submodule directory, relative to BSD_PATH
define GenerateSubmoduleCheckTarget
check-submodules: $(BSD_PATH)/$(1)/.git
$(BSD_PATH)/$(1)/.git:
	@echo "WARNING: Missing submodule $(1)..."
	[ -e ${BSD_PATH}/.git ] || ( echo "ERROR: Build System Kit must be cloned from git to work."; exit 1)
	[ -x $$(which git) ] || ( echo "ERROR: Need to run 'git submodule init $(1)' in Build System Kit root directory."; exit 1)
	@echo "Attempting 'git submodule update --init $(1)' in Build System Kit root directory..."
	cd ${BSD_PATH} && git submodule update --init $(1)

# Parse 'git status' output to check if the submodule commit is different to expected
ifneq ("$(filter $(1),$(GIT_STATUS))","")
$$(info WARNING: Build System Kit git submodule $(1) may be out of date. Run 'git submodule update' in BSD_PATH dir to update.)
endif
endef

# filter/subst in expression ensures all submodule paths begin with $(BSD_PATH), and then strips that prefix
# so the argument is suitable for use with 'git submodule' commands
$(foreach submodule,$(subst $(BSD_PATH)/,,$(filter $(BSD_PATH)/%,$(COMPONENT_SUBMODULES))),$(eval $(call GenerateSubmoduleCheckTarget,$(submodule))))
endif # End check for .gitmodules existence


# PHONY target to list components in the build and their paths
list-components:
	$(info $(call dequote,$(SEPARATOR)))
	$(info COMPONENT_DIRS (components searched for here))
	$(foreach cd,$(COMPONENT_DIRS),$(info $(cd)))
	$(info $(call dequote,$(SEPARATOR)))
	$(info COMPONENTS (list of component names))
	$(info $(COMPONENTS))
	$(info $(call dequote,$(SEPARATOR)))
	$(info EXCLUDE_COMPONENTS (list of excluded names))
	$(info $(if $(EXCLUDE_COMPONENTS),$(EXCLUDE_COMPONENTS),(none provided)))	
	$(info $(call dequote,$(SEPARATOR)))
	$(info COMPONENT_PATHS (paths to all components):)
	$(foreach cp,$(COMPONENT_PATHS),$(info $(cp)))
