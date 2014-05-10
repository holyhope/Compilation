#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>

#include "vm_instr.h"

int asprintf( char **strp, const char *fmt, ... ); 

int vm_nb_arg( vm_instr instr ) {
  switch ( instr ) {
    case vm_neg:
    case vm_add:
    case vm_sub:
    case vm_div:
    case vm_mod:
    case vm_low:
    case vm_leq:
    case vm_geq:
    case vm_pop:
    case vm_ret:
    case vm_push:
    case vm_mult:
    case vm_swap:
    case vm_halt:
    case vm_read:
    case vm_load:
    case vm_save:
    case vm_saver:
    case vm_loadr:
    case vm_equal:
    case vm_noteq:
    case vm_great:
    case vm_write:
    case vm_readch:
    case vm_writech:
      return 0;
    case vm_set:
    case vm_call:
    case vm_jump:
    case vm_free:
    case vm_label:
    case vm_jumpf:
    case vm_alloc:
      return 1;
  }
  return -1;
}

char *vm_command( vm_instr instr, ... ) {
  #define MAX 2048
  va_list argp;
  va_start( argp, instr );
  char *instruction;
  switch ( instr ) {
    case vm_neg:     asprintf( &instruction, "%s", "NEG" );     break;
    case vm_add:     asprintf( &instruction, "%s", "ADD" );     break;
    case vm_sub:     asprintf( &instruction, "%s", "SUB" );     break;
    case vm_div:     asprintf( &instruction, "%s", "DIV" );     break;
    case vm_mod:     asprintf( &instruction, "%s", "MOD" );     break;
    case vm_low:     asprintf( &instruction, "%s", "LOW" );     break;
    case vm_leq:     asprintf( &instruction, "%s", "LEQ" );     break;
    case vm_geq:     asprintf( &instruction, "%s", "GEQ" );     break;
    case vm_pop:     asprintf( &instruction, "%s", "POP" );     break;
    case vm_ret:     asprintf( &instruction, "%s", "RETURN" );  break;
    case vm_push:    asprintf( &instruction, "%s", "PUSH" );    break;
    case vm_mult:    asprintf( &instruction, "%s", "MULT" );    break;
    case vm_swap:    asprintf( &instruction, "%s", "SWAP" );    break;
    case vm_halt:    asprintf( &instruction, "%s", "HALT" );    break;
    case vm_read:    asprintf( &instruction, "%s", "READ" );    break;
    case vm_load:    asprintf( &instruction, "%s", "LOAD" );    break;
    case vm_save:    asprintf( &instruction, "%s", "SAVE" );    break;
    case vm_saver:   asprintf( &instruction, "%s", "SAVER" );   break;
    case vm_loadr:   asprintf( &instruction, "%s", "LOADR" );   break;
    case vm_equal:   asprintf( &instruction, "%s", "EQUAL" );   break;
    case vm_noteq:   asprintf( &instruction, "%s", "NOTEQ" );   break;
    case vm_great:   asprintf( &instruction, "%s", "GREAT" );   break;
    case vm_write:   asprintf( &instruction, "%s", "WRITE" );   break;
    case vm_readch:  asprintf( &instruction, "%s", "READCH" );  break;
    case vm_writech: asprintf( &instruction, "%s", "WRITECH" ); break;
    case vm_set:   asprintf( &instruction, "%s %d", "SET",   va_arg( argp, int ) ); break;
    case vm_call:  asprintf( &instruction, "%s %d", "CALL",  va_arg( argp, int ) ); break;
    case vm_jump:  asprintf( &instruction, "%s %d", "JUMP",  va_arg( argp, int ) ); break;
    case vm_free:  asprintf( &instruction, "%s %d", "FREE",  va_arg( argp, int ) ); break;
    case vm_label: asprintf( &instruction, "%s %d", "LABEL", va_arg( argp, int ) ); break;
    case vm_jumpf: asprintf( &instruction, "%s %d", "JUMPF", va_arg( argp, int ) ); break;
    case vm_alloc: asprintf( &instruction, "%s %d", "ALLOC", va_arg( argp, int ) ); break;
  }
  va_end( argp );
  return instruction;
  #undef MAX
}

void vm_exec( vm_instr instr, ... ) {
  char *command = vm_command( instr );
  printf( "%s", command );
  free( command );
}
