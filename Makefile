CC=gcc
CFLAGS=-Wall `pkg-config --cflags glib-2.0` -g
LDFLAGS=`pkg-config --libs glib-2.0` #-lfl
OUT_EXEC=tcompil
EXEC=gcc
SRC = sources/

all: $(OUT_EXEC) clean

$(OUT_EXEC): $(SRC)$(EXEC).o lex.yy.o $(SRC)vm_instr.o
	$(CC)  -o $@ $^ $(LDFLAGS)

$(SRC)$(EXEC).c: $(SRC)$(EXEC).y
	bison -d -o $(SRC)$(EXEC).c $(SRC)$(EXEC).y -v

$(SRC)$(EXEC).h: $(SRC)$(EXEC).c

lex.yy.c: $(SRC)$(EXEC).lex $(SRC)$(EXEC).h
	flex $(SRC)$(EXEC).lex

$(SRC)%.o: $(SRC)%.c
	$(CC) -o $@ -c $< $(CFLAGS)

clean:
	rm -f *.o lex.yy.c $(SRC)$(EXEC).[ch]

mrproper: clean
	rm -f $(EXEC)
