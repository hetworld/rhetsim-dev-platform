SDK_ROOT ?= ../../..
MUSL_GCC = $(SDK_ROOT)/toolchain/sysroot/bin/musl-gcc
CC = $(MUSL_GCC)
CFLAGS ?= -march=rv64ima -mabi=lp64 -O2 -static

.PHONY: all clean

all: hello

hello: main.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f hello
