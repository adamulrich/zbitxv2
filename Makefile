CC      = gcc
DEV_MODE ?= 0
CFLAGS  = -g $(shell pkg-config --cflags gtk+-3.0)
LDLIBS  = -lasound -lm -lfftw3 -lfftw3f -pthread -lncurses -lsqlite3 $(shell pkg-config --libs gtk+-3.0)

ifeq ($(DEV_MODE),1)
	CFLAGS += -DDEV_MODE -Idevshim
	DEV_OBJS = devshim/wiringpi_compat.o
else
	LDLIBS += -lwiringPi
endif

TARGET  = sbitx

SRCS = vfo.c si570.c sbitx_sound.c fft_filter.c sbitx_gtk.c sbitx_utils.c        i2cbb.c si5351v2.c ini.c hamlib.c queue.c modems.c logbook.c        modem_cw.c settings_ui.c oled.c hist_disp.c ntputil.c        telnet.c macros.c modem_ft8.c remote.c mongoose.c webserver.c $(TARGET).c

OBJS    = $(SRCS:.c=.o)
FT8_SRCS = ft8_lib/ft8/constants.c ft8_lib/ft8/encode.c ft8_lib/ft8/pack.c ft8_lib/ft8/text.c ft8_lib/common/wave.c ft8_lib/ft8/crc.c ft8_lib/fft/kiss_fftr.c ft8_lib/fft/kiss_fft.c ft8_lib/ft8/decode.c ft8_lib/ft8/ldpc.c ft8_lib/ft8/unpack.c
FT8_OBJS = $(FT8_SRCS:.c=.o)

.PHONY: all clean

all: audio data web data/sbitx.db $(TARGET)

FT8_DEPS = $(FT8_OBJS)

$(TARGET): $(OBJS) $(DEV_OBJS) $(FT8_DEPS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDLIBS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

audio data web:
	mkdir $@

data/sbitx.db: | data
	cd data && sqlite3 sbitx.db < create_db.sql

clean:
	rm -f $(OBJS) $(DEV_OBJS) $(FT8_OBJS) $(TARGET)
