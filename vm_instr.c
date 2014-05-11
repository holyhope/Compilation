#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdbool.h>

#include "vm_instr.h"

int vm_nb_arg( vm_instr instr ) {
  switch ( instr ) {
    default:
      return 0;
    case vm_set:
    case vm_call:
    case vm_jump:
    case vm_free:
    case vm_label:
    case vm_jumpf:
    case vm_alloc:
    case vm_comment:
      return 1;
  }
  return -1;
}

static char *vm_command( vm_instr instr, va_list argp ) {
  int asprintf( char **strp, const char *fmt, ... );
  char *instruction;
  int tmp;

  switch ( instr ) {
    default:         tmp = asprintf( &instruction, ""              ); break;
    case vm_neg:     tmp = asprintf( &instruction, "%s", "NEG"     ); break;
    case vm_add:     tmp = asprintf( &instruction, "%s", "ADD"     ); break;
    case vm_sub:     tmp = asprintf( &instruction, "%s", "SUB"     ); break;
    case vm_div:     tmp = asprintf( &instruction, "%s", "DIV"     ); break;
    case vm_mod:     tmp = asprintf( &instruction, "%s", "MOD"     ); break;
    case vm_low:     tmp = asprintf( &instruction, "%s", "LOW"     ); break;
    case vm_leq:     tmp = asprintf( &instruction, "%s", "LEQ"     ); break;
    case vm_geq:     tmp = asprintf( &instruction, "%s", "GEQ"     ); break;
    case vm_pop:     tmp = asprintf( &instruction, "%s", "POP"     ); break;
    case vm_push:    tmp = asprintf( &instruction, "%s", "PUSH"    ); break;
    case vm_mult:    tmp = asprintf( &instruction, "%s", "MULT"    ); break;
    case vm_swap:    tmp = asprintf( &instruction, "%s", "SWAP"    ); break;
    case vm_halt:    tmp = asprintf( &instruction, "%s", "HALT"    ); break;
    case vm_read:    tmp = asprintf( &instruction, "%s", "READ"    ); break;
    case vm_load:    tmp = asprintf( &instruction, "%s", "LOAD"    ); break;
    case vm_save:    tmp = asprintf( &instruction, "%s", "SAVE"    ); break;
    case vm_saver:   tmp = asprintf( &instruction, "%s", "SAVER"   ); break;
    case vm_loadr:   tmp = asprintf( &instruction, "%s", "LOADR"   ); break;
    case vm_equal:   tmp = asprintf( &instruction, "%s", "EQUAL"   ); break;
    case vm_noteq:   tmp = asprintf( &instruction, "%s", "NOTEQ"   ); break;
    case vm_great:   tmp = asprintf( &instruction, "%s", "GREAT"   ); break;
    case vm_write:   tmp = asprintf( &instruction, "%s", "WRITE"   ); break;
    case vm_readch:  tmp = asprintf( &instruction, "%s", "READCH"  ); break;
    case vm_return:  tmp = asprintf( &instruction, "%s", "RETURN"  ); break;
    case vm_writech: tmp = asprintf( &instruction, "%s", "WRITECH" ); break;
    case vm_set:     tmp = asprintf( &instruction, "%s %d", "SET",   va_arg( argp, int   ) ); break;
    case vm_call:    tmp = asprintf( &instruction, "%s %u", "CALL",  va_arg( argp, int   ) ); break;
    case vm_jump:    tmp = asprintf( &instruction, "%s %u", "JUMP",  va_arg( argp, int   ) ); break;
    case vm_free:    tmp = asprintf( &instruction, "%s %d", "FREE",  va_arg( argp, int   ) ); break;
    case vm_label:   tmp = asprintf( &instruction, "%s %u", "LABEL", va_arg( argp, int   ) ); break;
    case vm_jumpf:   tmp = asprintf( &instruction, "%s %u", "JUMPF", va_arg( argp, int   ) ); break;
    case vm_alloc:   tmp = asprintf( &instruction, "%s %d", "ALLOC", va_arg( argp, int   ) ); break;
    case vm_comment: tmp = asprintf( &instruction, "%s%s",  "#",     va_arg( argp, char* ) ); break;
  }

  if ( tmp == -1 ) {
    perror( "asprintf" );
    exit( EXIT_FAILURE );
  }

  return instruction;
}

#ifdef VM_OPTIMIZE
static enum { both, none, first, second } is_usefull(
    vm_instr instr1,
    vm_instr instr2
  ) {
  if ( instr1 == vm_none || instr1 == vm_comment ) {
    if ( instr2 == vm_none || instr2 == vm_comment ) {
      return none;
    }
    return second;
  } else if ( instr2 == vm_none || instr2 == vm_comment ) {
    return first;
  }
  if ( instr1 == vm_push && instr2 == vm_pop ) {
    return none;
  }
  if ( instr1 == vm_set && instr2 == vm_set ) {
    return second;
  }
  if ( instr1 == vm_swap && instr2 == vm_swap ) {
    return none;
  }
  if (
      instr2 != vm_label &&
      (
        instr1 == vm_return ||
        instr1 == vm_jump   ||
        instr1 == vm_halt
      )
    ) {
    return first;
  }
  return both;
}

static vm_instr previous_command = vm_none;
static char *previous_exec = NULL;

void vm_exec( vm_instr instr, ... ) {
  va_list argp;

  switch ( is_usefull( previous_command, instr ) ) {
    case both:
      printf( "%s\n", previous_exec );
    case second:
      free( previous_exec );
      previous_command = instr;

      va_start( argp, instr );
      previous_exec = vm_command( instr, argp );
      va_end( argp );
    break;
    case none:
      previous_command = vm_none;
      free( previous_exec );
      previous_exec = NULL;
    break;
    case first: break;
  }
}

void vm_flush() {
  if ( previous_command != vm_none ) {
    printf( "%s\n", previous_exec );
    free( previous_exec );
    previous_command = vm_none;
  }
}
#else
void vm_exec( vm_instr instr, ... ) {
  char *exec;
  va_list argp;
  va_start( argp, instr );
  exec = vm_command( instr, argp );
  printf( "%s\n", exec );
  free( exec );
  va_end( argp );
}

void vm_flush() {
}
#endif
