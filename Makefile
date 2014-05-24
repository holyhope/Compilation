CC=gcc
CFLAGS=-Wall -pedantic -ansi `pkg-config --cflags glib-2.0` -g
LDFLAGS=`pkg-config --libs glib-2.0` #-lfl
OUT_EXEC=tcompil
EXEC=gcc
SRC = sources
TMP = tmp

all: $(TMP)/$(EXEC).o $(TMP)/lex.yy.o $(TMP)/vm_instr.o
	$(CC) -o $(OUT_EXEC) $^ $(LDFLAGS)

$(SRC)/$(EXEC).c: $(SRC)/$(EXEC).y $(SRC)/$(EXEC).h
	bison -d -o $@ $< -v

$(SRC)/lex.yy.c: $(SRC)/$(EXEC).lex
	flex -o $@ --header-file=$(SRC)/$(EXEC).h $<

$(SRC)/$(EXEC).h: $(SRC)/lex.yy.c

$(TMP)/%.o: $(SRC)/%.c
	$(CC) -o $@ -c $< $(CFLAGS)

clean:
	rm -f $(TMP)/* $(SRC)/lex.yy.c $(SRC)/$(EXEC).[hc]

mrproper: clean
	rm -f $(EXEC)
