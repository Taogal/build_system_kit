#
# "main" pseudo-component makefile.
#
# (Uses default behaviour of compiling all source files in directory, adding 'include' to include path.)



SDL_DIR_INC =/work/software/SDL-2.0.9-12272/tmp
SDL_DIR_LIB =/work/software/SDL-2.0.9-12272/tmp

FFMPEG_DIR_INC =/work/software/ffmpeg-4.0.2/tmp
FFMPEG_DIR_LIB =/work/software/ffmpeg-4.0.2/tmp

 
CFLAGS += -I $(SDL_DIR_INC)/include -I $(FFMPEG_DIR_INC)/include

COMPONENT_ADD_LDFLAGS += -L$(SDL_DIR_LIB)/lib -L$(FFMPEG_DIR_LIB)/lib
COMPONENT_ADD_LDFLAGS += -lSDL2 -lavcodec -lavformat -lswresample -lavdevice -lavutil  -lswscale -lavfilter -lpostproc