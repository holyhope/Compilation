CC=colorgcc
############################# DEBUG FLAGS ##############################
CFLAGS=-Wall -ansi `pkg-config --cflags glib-2.0` -g -lmcheck
LDFLAGS=`pkg-config --libs glib-2.0`
########################## PRODUCTION FLAGS ############################
#CFLAGS=`pkg-config --cflags glib-2.0` -DNDEBUG -O2 -DVM_OPTIMIZE
#LDFLAGS=`pkg-config --libs glib-2.0`
########################################################################
OUT_EXEC=tcompil
EXEC=gcc

all: clear $(OUT_EXEC) clean

clear:
	clear && clear

$(OUT_EXEC): $(EXEC).o lex.yy.o vm_instr.o
	$(CC)  -o $@ $^ $(LDFLAGS)

$(EXEC).c: $(EXEC).y
	bison -d -o $(EXEC).c $(EXEC).y -v

$(EXEC).h: $(EXEC).c

lex.yy.c: $(EXEC).lex $(EXEC).h
	flex $(EXEC).lex

%.o: %.c
	$(CC) -o $@ -c $< $(CFLAGS)

clean:
	rm -f *.o lex.yy.c $(EXEC).[ch]

mrproper: clean
	rm -f $(OUT_EXEC)
