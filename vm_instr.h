#ifndef __VM_INSTR
#define __VM_INSTR

typedef enum {
  vm_neg,
  vm_add,
  vm_sub,
  vm_div,
  vm_mod,
  vm_low,
  vm_leq,
  vm_geq,
  vm_pop,
  vm_none,
  vm_push,
  vm_mult,
  vm_swap,
  vm_halt,
  vm_read,
  vm_load,
  vm_save,
  vm_saver,
  vm_loadr,
  vm_equal,
  vm_noteq,
  vm_great,
  vm_write,
  vm_readch,
  vm_return,
  vm_writech,
  vm_set,
  vm_call,
  vm_jump,
  vm_free,
  vm_label,
  vm_jumpf,
  vm_alloc,
  vm_comment
} vm_instr;

void vm_exec( vm_instr instr, ... );
void vm_flush();

#endif
