# Automatically generated build file. Do not edit.
COMPONENT_INCLUDES += $(PROJECT_PATH)/main/include
COMPONENT_LDFLAGS += -L$(BUILD_DIR_BASE)/main -lmain -L/work/software/SDL-2.0.9-12272/tmp/lib -L/work/software/ffmpeg-4.0.2/tmp/lib -lSDL2 -lavcodec -lavformat -lswresample -lavdevice -lavutil  -lswscale -lavfilter -lpostproc
COMPONENT_LINKER_DEPS += 
COMPONENT_SUBMODULES += 
COMPONENT_LIBRARIES += main
component-main-build: 
