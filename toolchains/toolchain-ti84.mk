NAME = CNAME
DESCRIPTION = CDESC

TARGET = CTAR
SRCDIR = CSRCDIR

EXTRA_C_SOURCES += CBUILDDIR/cal/input.c

CFLAGS = -Wall -Wextra -O2 -ICINCDIR -ICBUILDDIR/cal
LIBS = graphx keypadc fileioc tice

BINDIR = CBINDIR/cal
OBJDIR = CBUILDDIR/cal

LTO = NO

include $(CEDEV)/meta/makefile.mk