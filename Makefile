CC=gcc
CFLAGS=-Wall
LDFLAGS=#-lfl
OUT_EXEC=super_compilator
EXEC=gcc

all: $(OUT_EXEC) clean

$(OUT_EXEC): $(EXEC).o lex.yy.o
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
	rm -f $(EXEC)
