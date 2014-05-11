%{
  #include <stdlib.h>   /* utilise par les free de bison */
  #include <stdio.h>
  #include <string.h>
  #include <unistd.h>
  #include <glib.h>
  #include <stdbool.h>
  #include <sys/stat.h>
  #include <fcntl.h>
  #include <assert.h>
  
  #include "vm_instr.h"

  int asprintf( char **strp, const char *fmt, ... );

  typedef enum { entier, fonction, none, pointeur, constante } Type;
  
  typedef struct __fonction {
    GList *variables; /* Liste des variables déclarée dans le block */

    int label;        /* Label à CALL */

    /* Dans le cas d'un block simple, nb_arguments = 0 et isvoid = true; */
    int nb_arguments; /* Nombre d'arugments                   */
    Type retour;      /* Type de retour si isvoid == false    */
  } FonctionData;

  typedef struct __unamed_block {
    GList *variables; /* Liste des variables déclarée dans le block */
    int label;        /* Label à CALL */
  } UnamedBlockData;
  
  typedef struct {
    char *name;             /* Nom de la variable                */
    Type type;              /* Type de la variable               */
    int addr;               /* Adresse dans la machine virtuelle */
    int size;               /* Taille de la variable             */
    GList *parent;          /* Adresse du block père             */

    /* Données supplémentaires */
    union {
      FonctionData fonction; /* Dans le cas d'une fonction */
      UnamedBlockData block; /* Dans le cas d'un block */
    } data;
  } VariableData;

  int yylex();
  int mode_declaratif = 0;
  int prog_line = 1;
  char *prog_name = NULL;

  void yyerror( const char *, ... );

  #define yyerror( ... ) {\
    if ( prog_name == NULL ) {\
      fprintf( stderr, __VA_ARGS__ );\
    } else {\
      fprintf( stderr, "%s:%d:", prog_name, prog_line );\
      fprintf( stderr, __VA_ARGS__ );\
    }\
    fprintf( stderr, "\n" );\
  }

  FILE* yyin;

  static int jump_label = 1;
  static GList *actual_variable;


  #ifndef NDEBUG
  void comment( const char *s ) {
    vm_exec( vm_comment, s );
  }
  #else
  #define comment(a)
  #endif

  void show_infos( const char * );

  VariableData *get_variable( const char *name );
  int get_addr( VariableData * );
  void get_value( VariableData * );
  bool update_variable( VariableData *var, int value );
  bool update_variable_pop( VariableData *var );
  VariableData *create_fonction();
  VariableData *create_variable( const char *name, int size, Type type );
  void set_fonction( VariableData *var, const char *name, int nb_arguments, Type retour );
  void call_function( VariableData * );
  void end_block();
  void start_block( const char * name );
  void call_block( VariableData *var );
  GList *get_list_elem( const char *name );

  void end_program();
  void start_program();

%}

%union {
  void*                                       adr;
  unsigned int                                num;
  char*                                       ident;
  enum { gte, gt, lt, lte, eq, neq }          comparator;
  enum { add, sub }                           operator;
}

%left "<" ">" "<=" "=>" "==" "!="  /* Comparateurs                */
%left "+" "-"                      /* additions / soustractions   */
%left "*" "/"                      /* multiplications / divisions */
%left UMINUS                       /* Moins unaire                */
%right ADR ADDSUB_UNAIRE

%token <comparator>  COMP
%token <operator>    ADDSUB
%token <num>         NUM
%token <ident>       IDENT ADR

%type <num> Exp NombreSigne
%type <num> Parametres ListVar
%type <adr> Variable FixEnTeteFonct EnTeteFonct EnTeteMain

%type <num> FIXIF FIXELSE WHILESTART WHILETEST

%type <num> Type

%token DIV STAR MOD
%token MALLOC FREE PRINT READ MAIN
%token VRG PV EGAL RETURN
%token IF ELSE WHILE
%token LPAR RPAR LACC RACC LSQB RSQB
%token VOID VAR ENTIER CONST
%token NEW_LINE

%nonassoc ELSE

%%

prog: COUNTLINE DeclConst COUNTLINE DeclVar FixProg COUNTLINE DeclFonct COUNTLINE DeclMain COUNTLINE ;
FixProg:                              {
    comment( "Appel de main" );
    vm_exec( vm_call, 0 );
    vm_exec( vm_halt );
  }
;
DeclConst: DeclConst CONST ListConst PV COUNTLINE
  |    /* epsi */                            {
    comment( "Constantes" );
  }
;
ListConst: ListConst VRG IDENT EGAL NombreSigne
  | IDENT EGAL NombreSigne                         {
    VariableData *variable = create_variable( $1, 0, entier );
    free( $1 );
    variable->addr = $3;
  }
;
NombreSigne: NUM                              { $$ = $1; }
  | ADDSUB NombreSigne %prec ADDSUB_UNAIRE    { $$ = $1 == sub ? -$2 : $2; }
  | NombreSigne ADDSUB NombreSigne            { $$ = $1 == sub ? $1 - $3 : $1 + $3; }
  | NombreSigne STAR NombreSigne              { $$ = $1 * $3; }
  | NombreSigne DIV NombreSigne               { $$ = $1 / $3; }
  | NombreSigne MOD NombreSigne               { $$ = $1 % $3; }
;
DeclVar: DeclVar VAR FIXDeclVar ListVar PV COUNTLINE   {
    mode_declaratif = 0;
    comment( "Fin de déclarations des variables." );
  }
  | /* epsi */
;
FIXDeclVar:                                   {
    mode_declaratif = 1;
    comment( "Déclaration des Variables" );
  }
;
ListVar: ListVar VRG Variable                 { $$ = $1 + 1; }
  | Variable                                  { $$ = 1; }
;
Variable: STAR Variable                       {
    if ( mode_declaratif ) {
      ( (VariableData*) $2 )->type = pointeur;
    } else {
      vm_exec( vm_pop );
      vm_exec( vm_load );
      vm_exec( vm_push );
    }
    $$ = $2;
  }
  | IDENT                                     {
    VariableData *var;
    if ( mode_declaratif ) {
      var = create_variable( $1, 1, entier );
    } else {
      var = get_variable( $1 );
      get_value( var );
      vm_exec( vm_push );
    }
    $$ = var;
    free( $1 );
  }
;
DeclMain: EnTeteMain Corps                    { end_block( $1 ); } ;
EnTeteMain: MAIN LPAR RPAR                    {
    const char *name = "main";
    VariableData *fonction_main = create_fonction();
    set_fonction( fonction_main, name, 0, none );
    vm_exec( vm_label, 0 );
    $$ = fonction_main;
  }
;
DeclFonct: DeclFonct DeclUneFonct                        {}
  | /* epsi */
;
DeclUneFonct: EnTeteFonct Corps                          {
    if ( ( (VariableData*) $1 )->data.fonction.retour == none ) {
      comment( "automatic return" );
      vm_exec( vm_return );
    }
    end_block( $1 );
  }
;
EnTeteFonct: FixEnTeteFonct Type IDENT LPAR Parametres RPAR        {
    set_fonction( $1, $3, $5, $2 );
    $$ = $1;
    mode_declaratif = 0;
    comment( "Fin de déclaration des paramètres" );
    free( $3 );
  }
;
FixEnTeteFonct:                        {
    $$ = create_fonction();
    mode_declaratif = 1;
    comment( "Déclaration des paramètres" );
  }
;
Type: ENTIER                  { $$ = true;  }
  | VOID                      { $$ = false; }
;
Parametres: VOID              { $$ = 0;  }
  | ListVar                   { $$ = $1; }
  | /* epsi */                { $$ = 0;  }
;
SuiteInstr: SuiteInstr Instr      |   /* epsi */   ;
InstrComp: LACC COUNTLINE SuiteInstr COUNTLINE RACC                    ;
Corps: LACC COUNTLINE DeclConst COUNTLINE DeclVar COUNTLINE SuiteInstr COUNTLINE RACC      ;
Instr: IDENT EGAL Exp PV                                 {
    update_variable_pop( get_variable( $1 ) );
  }
  | STAR IDENT EGAL Exp PV                               {
    VariableData *var = get_variable( $2 );
    if ( var->type != pointeur ) {
      yyerror( "variable %s expected to be a pointer.", var->name );
    } else {
      vm_exec( vm_set, get_addr( get_variable( $2 ) ) );
      vm_exec( vm_load );
      vm_exec( vm_swap );
      vm_exec( vm_pop );
      vm_exec( vm_save );
    }
  }
  | IDENT EGAL MALLOC LPAR Exp RPAR PV                   {
    VariableData *global = create_variable( "", $5, entier );
    update_variable( get_variable( $1 ), get_addr( global ) );
  }
  | FREE LPAR Exp RPAR PV                                { /* TODO */ }
  | IF LPAR Exp RPAR FIXIF Instr                        {
    vm_exec( vm_label, $5 );
  }
  | IF LPAR Exp RPAR FIXIF Instr ELSE FIXELSE Instr     {
    vm_exec( vm_label, $8 );
  }
  | WHILE WHILESTART LPAR Exp RPAR WHILETEST Instr       {
    vm_exec( vm_jump, $2 );
    vm_exec( vm_label, $6 );
  }
  | RETURN Exp PV                                        {
    vm_exec( vm_pop );
    vm_exec( vm_return );
  }
  | RETURN PV                                            {
    vm_exec( vm_return );
  }
  | READ LPAR IDENT RPAR PV                              {
    VariableData *var = get_variable( $3 );
    if ( var->type != entier ) {
      yyerror( "Can't read a non integer variable." );
    } else {
      vm_exec( vm_set, get_addr( var ) );
      vm_exec( vm_swap );
      vm_exec( vm_read );
      vm_exec( vm_save );
    }
  }
  | PRINT LPAR Exp RPAR PV                               {
    vm_exec( vm_pop );
    vm_exec( vm_write );
  }
  | IDENT LPAR Arguments RPAR PV                         {
    char *com;
    VariableData *var;
    if ( -1 == asprintf( &com, "Appel de %s", $1 ) ) {
      perror( "asprintf" );
      exit( EXIT_FAILURE );
    }
    comment( com );
    var = get_variable( $1 );
    call_block( var );
  }
  | PV                                                   {}
  | InstrComp                                            { /* TODO */ }
  | COUNTLINE
;
Arguments: ListExp
  | /* epsi */
;
ListExp: ListExp VRG Exp
  | Exp
;
Exp: Exp ADDSUB Exp                                      {
    vm_exec( vm_pop );
    vm_exec( vm_swap );
    vm_exec( vm_pop );
    if ( $2 == add ) 
          vm_exec( vm_add ); 
    else 
          vm_exec( vm_sub );
    vm_exec( vm_push );
  }
  | Exp STAR Exp                                         {
    vm_exec( vm_pop );
    vm_exec( vm_swap );
    vm_exec( vm_pop );
    vm_exec( vm_mult );
    vm_exec( vm_push );
  }
  | Exp DIV Exp                                          {
    vm_exec( vm_pop );
    vm_exec( vm_swap );
    vm_exec( vm_pop );
    vm_exec( vm_div );
    vm_exec( vm_push );
    $$ = $1 / $3;
  }
  | Exp MOD Exp                                          {
    vm_exec( vm_pop );
    vm_exec( vm_swap );
    vm_exec( vm_pop );
    vm_exec( vm_mod );
    vm_exec( vm_push );
    $$ = $1 % $3;
  }
  | Exp COMP Exp                                         {
    vm_exec( vm_set, $3 ); 
    vm_exec( vm_swap ); 
    vm_exec( vm_set, $1 );
    switch( $2 ) {
      case lt:  vm_exec( vm_low   ); $$ = $1 <  $2; break;
      case gt:  vm_exec( vm_great ); $$ = $1 >  $2; break;
      case eq:  vm_exec( vm_equal ); $$ = $1 == $2; break;
      case lte: vm_exec( vm_leq   ); $$ = $1 <= $2; break;
      case gte: vm_exec( vm_geq   ); $$ = $1 >= $2; break;
      case neq: vm_exec( vm_noteq ); $$ = $1 != $2; break;
      default: exit( EXIT_FAILURE );
    }
    vm_exec( vm_write );
  }
  | ADDSUB Exp %prec ADDSUB_UNAIRE                       {
    if ( $1 == sub ) {
      vm_exec( vm_pop );
      vm_exec( vm_neg );
      vm_exec( vm_push );
      $$ = -$2;
    } else {
      $$ = $2;
    }
  }
  | LPAR Exp RPAR                                        { $$ = $2; }
  | Variable                                             {
    $$ = get_addr( $1 );
  }
  | ADR Variable                                         {}
  | NUM                                                  {
    vm_exec( vm_set, $$ = $1 );
    vm_exec( vm_push );
  }
  | IDENT LPAR Arguments RPAR                            {
    char *com;
    VariableData *var;
    if ( -1 == asprintf( &com, "Appel de %s", $1 ) ) {
      perror( "asprintf" );
      exit( EXIT_FAILURE );
    }
    comment( com );
    var = get_variable( $1 );
    call_block( var );
  }
;
COUNTLINE: COUNTLINE NEW_LINE  { prog_line++; }
  |
;
FIXIF:                                                   {
    vm_exec( vm_jumpf, $$ = jump_label += 2 );
  }
;
FIXELSE:                                                 {
    vm_exec( vm_jump,  $$ = jump_label++    );
    vm_exec( vm_label, $$=$<num>-3 );
  } ;
WHILESTART:                                              {
    vm_exec( vm_label, $$ = jump_label++ ); } ;
WHILETEST:                                               {
    vm_exec( vm_jumpf, $$ = jump_label++ );
  }
;
%%

void free_variable_data( gpointer pointer ) {
  VariableData *data;

  if ( pointer != NULL ) {
    data = pointer;
    g_list_free_full( data->data.fonction.variables, free_variable_data );
    free( data->name );
    free( data );
  }
}

GList *get_root() {
  GList *root = g_list_first( actual_variable ), *tmp;

  while ( NULL !=  ( tmp = ( (VariableData*) root->data )->parent ) ) {
    root = tmp;
  }

  return root;
}

void free_variables() {
  g_list_free_full( get_root(), free_variable_data );
}

gint compare_data( gconstpointer data1, gconstpointer data2 ) {
  return strcmp(
    (char*) ( (VariableData*) data1 )->name,
    (char*) ( (VariableData*) data2 )->name
  );
}

VariableData *create_variable_outofrange(
    const char *name,
    int size,
    Type type
  ) {
  VariableData * data;

  if ( NULL == ( data = (VariableData*) malloc( sizeof( VariableData ) ) ) ) {
    perror( "malloc" );
    exit( EXIT_FAILURE );
  }
  if ( -1 == asprintf( &data->name, "%s", name ) ) {
    perror( "asprintf" );
    exit( EXIT_FAILURE );
  }
  data->type = type;
  data->size = size;
  data->parent = NULL;

  return data;
}

void insert_variable( VariableData *data ) {
  GList *current_variables_list;
  VariableData *last;
  assert( data != NULL );
  assert( actual_variable != NULL );
  assert( actual_variable->data != NULL );
  current_variables_list =
    ( (VariableData*) actual_variable->data )->data.fonction.variables;

  if ( current_variables_list == NULL ) {
    data->addr = 0;
  } else {
    last = ( (VariableData*) g_list_last( current_variables_list )->data );
    data->addr = last->addr + last->size;
  }

  data->parent = actual_variable;
  ( (VariableData*) actual_variable->data )->data.fonction.variables =
    g_list_append( current_variables_list, data );

  if ( data->size ) {
    vm_exec( vm_alloc, data->size );
  }
}

VariableData *create_variable( const char *name, int size, Type type ) {
  VariableData * data;
  char *com;
  if ( -1 == asprintf( &com, "Création de la variable \"%s\"", name ) ) {
    perror( "asprintf" );
    exit( EXIT_FAILURE );
  }
  comment( com );
  free( com );
  data = create_variable_outofrange( name, size, type );
  assert( data != NULL );
  if ( -1 == asprintf( &com, "Insertion de la variable \"%s\" dans %s", name, ( (VariableData*) actual_variable->data )->name ) ) {
    perror( "asprintf" );
    exit( EXIT_FAILURE );
  }
  comment( com );
  free( com );
  insert_variable( data );
  if ( -1 == asprintf( &com, "Variable créée \"%s\"", name ) ) {
    perror( "asprintf" );
    exit( EXIT_FAILURE );
  }
  comment( com );
  free( com );
  return data;
}

VariableData *create_block_outofrange() {
  VariableData *var = create_variable_outofrange( "", 0, fonction );
  assert( var != NULL );

  var->data.fonction.variables = NULL;
  var->data.fonction.retour = none;
  var->data.fonction.nb_arguments = 0;

  return var;
}

void insert_block( VariableData *fonction ) {
  static int fonction_label = 0;
  assert( fonction != NULL );
  assert( actual_variable != NULL );
  insert_variable( fonction );
  fonction->data.fonction.label = --fonction_label;
  fonction->parent = actual_variable;
  start_block( fonction->name );
}

VariableData *create_fonction() {
  VariableData *fonction;
  comment( "Création de fonction." );
  fonction = create_block_outofrange();
  assert( fonction != NULL );
  comment( "Insertion de la fonction." );
  insert_block( fonction );
  comment( "Fonction créée et insérée." );
  return fonction;
}

void set_fonction(
    VariableData *var,
    const char *name,
    int nb_arguments,
    Type retour
  ) {
  assert( var != NULL );

  comment( "Définition de fonction:" );
  free( var->name );
  comment( name );

  if ( -1 == asprintf( &var->name, "%s", name ) ) {
    perror( "asprintf" );
    exit( EXIT_FAILURE );
  }
  var->data.fonction.retour = retour;
  var->data.fonction.nb_arguments = nb_arguments;
}

VariableData *create_block() {
  return create_fonction();
}

bool update_variable( VariableData *var, int value ) {
  assert( var != NULL );
  switch ( var->type ) {
    case fonction:  yyerror( "Can't reassign function %s.", var->name ); break;
    case constante: yyerror( "Can't reassign constant %s.", var->name ); break;
    default:
      vm_exec( vm_set, get_addr( var ) );
      vm_exec( vm_swap );
      vm_exec( vm_set, value );
      vm_exec( vm_save );
    break;
  }
  return var;
}

int get_addr( VariableData *var ) {
  #define CALL_START 2

  int swipe = -CALL_START, i;
  GList *args;
  VariableData *parent = var->parent->data;

  assert( parent->type == fonction );
  args = parent->data.fonction.variables;
  assert( parent != NULL );
  do {
    swipe += CALL_START;
    for ( i = 0; i < parent->data.fonction.nb_arguments; i++ ) {
      assert( args != NULL );
      swipe += ( (VariableData*) args->data )->size;
      args = g_list_next( args );
    }
    if ( parent->parent != NULL ) {
      parent = parent->parent->data;
    } else {
      parent = NULL;
    }
  } while ( parent != NULL );

  assert( var != NULL );

  #undef CALL_START

  return var->addr + swipe;
}

bool update_variable_pop( VariableData *var ) {
  assert( var != NULL );
  switch ( var->type ) {
    case fonction:  yyerror( "Can't reassign function %s.", var->name ); break;
    case constante: yyerror( "Can't reassign constant %s.", var->name ); break;
    default:
      vm_exec( vm_set, get_addr( var ) );
      vm_exec( vm_swap );
      vm_exec( vm_pop );
      vm_exec( vm_save );
    break;
  }
  return var;
}

void call_block( VariableData *var ) {
  assert( var != NULL );
  if ( var->type != fonction ) {
    yyerror( "%s is not a block.", var->name );
  } else {
    vm_exec( vm_call, var->data.fonction.label );
    if ( var->data.fonction.retour != none ) {
      vm_exec( vm_push ); /* Car la valeur de retour est stockée dans reg1 */
    }
  }
}

void end_block() {
  VariableData *current;
  assert( actual_variable != NULL );
  assert( actual_variable->data != NULL );
  current = actual_variable->data;
  comment( "Auto return." );
  if ( strcmp( current->name, "" ) ) {
    vm_exec( vm_return );
  }
  actual_variable = current->parent;
}

void start_block( const char * name ) {
  comment( "Ouverture du block :" );
  comment( name );
  actual_variable = get_list_elem( name );
  assert( actual_variable != NULL );
  assert( actual_variable->data != NULL );
  vm_exec(
    vm_label,
    ( (VariableData*) actual_variable->data )->data.fonction.label
  );
}

void get_value( VariableData *variable ) {
  assert( variable != NULL );
  vm_exec( vm_set, get_addr( variable ) );
  if ( variable->type == entier ) {
    vm_exec( vm_load );
  }
}

void show_infos( const char *debug ) {
  printf( "%s\r", debug );
}

GList *get_list_elem( const char *name ) {
  char *com;
  GList *list;
  assert( actual_variable != NULL );
  assert( actual_variable->data != NULL );
  list = g_list_last(
    ( (VariableData*) actual_variable->data )->data.fonction.variables
  );

  while ( NULL != list ) {
    if ( strcmp( ((VariableData*) list->data)->name, name ) == 0 ) {
      return list;
    }
    if ( NULL == g_list_previous( list ) ) {
      list = ( (VariableData*) list->data )->parent;
    } else {
      list = g_list_previous( list );
    }
  }

  yyerror( "%s undeclared.", name );
  if ( -1 != asprintf( &com, "Déclaration implicite de \"%s\"", name ) ) {
    comment( com );
    free( com );
  }
  create_variable( name, 1, entier );

  return get_list_elem( name );
}

VariableData *get_variable( const char *name ) {
  GList *variable = get_list_elem( name );
  assert( variable != NULL );
  assert( variable->data != NULL );
  return variable->data;
}

void end_program() {
  vm_flush();
  free_variables();
}

void start_program() {
  VariableData *prog;
  comment( "Début du programme." );
  prog = create_block_outofrange();
  set_fonction( prog, "ROOT", 0, none );
  assert( prog != NULL );
  actual_variable = g_list_prepend( NULL, prog );
  assert( actual_variable != NULL );
  assert( actual_variable->data != NULL );
}

int main( int argc, const char *argv[] ) {
  char extension[5];
  int size = 0, i;  
  char* argument = NULL;
  int out;

  if ( 2 == argc || 3 == argc ) {
    size = strlen ( argv[1] );
    argument = ( char* ) malloc ( ( size - 4 ) * sizeof ( char ) );

    for ( i = 0 ; i < size - 4 ; i++ ) {
      argument [i] = argv[1][i];
    }
    for (; i <= size ; i++ ) {
      extension [i-4] = argv[1][i];
    }
    if ( strcmp ( extension, ".tpc" ) != 0 ) {
      fprintf ( stderr, "Erreur extension, le fichier doit être du type .tpc\n" );
      return 1;
    }
    if ( NULL == ( yyin = fopen( argv[1], "r" ) ) ) {
      fprintf ( stderr, "Erreur ouverture du fichier %s \n", argv[1] );
      return 1;
    }
    asprintf( &prog_name, "%s", argv[1] );
    if ( argc == 3 && strcmp( argv[2], "-o") == 0 ){
      strcat ( argument, ".vm" );
      if ( -1 == ( out = open ( argument, O_TRUNC | O_WRONLY ) ) ) {
        perror ( "open" );
        exit( EXIT_FAILURE );
      } else if ( -1 == dup2( STDOUT_FILENO, out ) ) {
        perror ( "dup2" );
        exit( EXIT_FAILURE );
      }
    }
    free( argument );
  } else if ( 1 == argc ) {
    yyin = stdin;
  } else {
    fprintf( stderr, "usage: %s [src]\n", argv[0] );
    exit( EXIT_FAILURE );
  }

  start_program();
  yyparse();
  end_program();

  free( prog_name );

  return 0;
}
