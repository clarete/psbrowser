CC=gcc

RM=rm -rf

CPPFLAGS=$(shell pkg-config --cflags taningia libbitu)

LIBS=$(shell pkg-config --libs taningia libbitu) -lreadline

PROGRAM=psbrowser

all:
	$(CC) $(CPPFLAGS) $(LIBS) -o $(PROGRAM) main.c hashtable-utils.c hashtable.c

clean:
	$(RM) $(PROGRAM) *~
