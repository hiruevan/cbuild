NAME = CNAME
DESCRIPTION = CDESC

TARGET = CTAR
SRCDIR = CSRCDIR
SRCS = CSRCFILES

CFLAGS = -Wall -Wextra -O2 -ICINCDIR
LIBS = graphx keypadc fileioc tice

BINDIR = CBINDIR/cal
OBJDIR = CBUILDDIR/cal

LTO = NO

include $(CEDEV)/meta/makefile.mk
