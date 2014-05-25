%{
  #include <stdlib.h>   /* utilise par les free de bison */
  #include <stdio.h>
  #include <string.h>
  #include <unistd.h>
  #include <glib.h>
  #include <stdbool.h>
  #include <sys/stat.h>
  #include <fcntl.h>
  
  #include "vm_instr.h"
  
  int asprintf( char **strp, const char *fmt, ... ); 

  typedef enum { entier, fonction, pointeur } Type;
  
  typedef struct __fonction {
    GList *variables; /* Liste des variables déclarée dans le block */

    int label;        /* Label à CALL */

    /* Dans le cas d'un block simple, nb_arguments = 0 et isvoid = true; */
    int nb_arguments; /* Nombre d'arugments                   */
    bool isvoid;      /* true si la fonction ne retourne rien */
    Type *arguments;  /* Tableaux des types des arguments     */
    Type retour;      /* Type de retour si isvoid == false    */
  } FonctionData;

  typedef struct __unamed_block {
    GList *variables; /* Liste des variables déclarée dans le block */

    int label;        /* Label à CALL */

    /* Dans le cas d'un block simple, nb_arguments = 0 et isvoid = true; */
    int nb_arguments; /* Nombre d'arugments                   */
    bool isvoid;      /* true si la fonction ne retourne rien */
    Type *arguments;  /* Tableaux des types des arguments     */
    Type retour;      /* Type de retour si isvoid == false    */
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

  int yyerror( char* );
  int yylex();
  int mode_declaratif = 0;

  FILE* yyin;
  int jump_label = 0;
  int encapsule;

  void comment( const char * );

  GList *actual_variable;

  VariableData *get_variable( const char *name );
  int get_addr( VariableData * );
  bool update_variable( VariableData *var, int value );
  bool update_variable_pop( VariableData *var );
  VariableData *create_fonction( const char *name, int nb_arguments, bool isvoid, ... );
  VariableData *create_variable( const char *name, int size, Type type );

  void call_function( VariableData * );
  void end_block();
  void call_block( VariableData *var );

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
%right ADR /* Pointeur */ ADDSUB_UNAIRE

%token <comparator>  COMP
%token <operator>    ADDSUB
%token <num>         NUM
%token <ident>       IDENT ADR

%type <num>   Exp NombreSigne
%type <adr> Variable

%type <num> FIXIF FIXELSE WHILESTART WHILETEST

%type <num> EnTeteFonct Type

%token DIV STAR MOD
%token MALLOC FREE PRINT READ MAIN
%token VRG PV EGAL RETURN
%token IF ELSE WHILE
%token LPAR RPAR LACC RACC LSQB RSQB
%token VOID VAR ENTIER CONST

%nonassoc ELSE

%%

prog: Fixprog DeclConst DeclVar DeclFonct DeclMain       { end_program(); }
  ;
Fixprog:                                                 { start_program(); }
  ;
DeclConst: DeclConst CONST ListConst PV                  {}
  | /* epsi */
  ;
ListConst: ListConst VRG IDENT EGAL NombreSigne          {}
  | IDENT EGAL NombreSigne                               {}
  ;
NombreSigne: NUM                                         { $$ = $1; }
  | ADDSUB NombreSigne %prec ADDSUB_UNAIRE               { $$ = $1 == sub ? -$2 : $2; }
  | NombreSigne ADDSUB NombreSigne                       { $$ = $1 == sub ? $1 - $3 : $1 + $3; }
  | NombreSigne STAR NombreSigne                         { $$ = $1 * $3; }
  | NombreSigne DIV NombreSigne                          { $$ = $1 / $3; }
  | NombreSigne MOD NombreSigne                          { $$ = $1 % $3; }
  ;
DeclVar: DeclVar VAR FIXDeclVar ListVar PV               { mode_declaratif = 0; }
  | /* epsi */
  ;
FIXDeclVar:                                              { mode_declaratif = 1; }
  ;
ListVar: ListVar VRG Variable                            {}
  | Variable                                             {}
  ;
Variable: STAR Variable                                     {
    if ( mode_declaratif ) {
      ( (VariableData*) $2 )->type = pointeur;
    } else {
      vm_exec( vm_pop );
      vm_exec( vm_load );
      vm_exec( vm_push );
    }
    $$ = $2;
  }
  | IDENT                                                {
    VariableData *var;
    if ( mode_declaratif ) {
      var = create_variable( $1, 1, entier );
    } else {
      var = get_variable( $1 );
      vm_exec( vm_set, get_addr( var ) );
      vm_exec( vm_push );
    }
    $$ = var;
  }
  ;
DeclMain: EnTeteMain Corps                               {}
  ;
EnTeteMain: MAIN LPAR RPAR                               {
    comment( "MAIN" );
    create_fonction( "main", 0, true );
  }
  ;
DeclFonct: DeclFonct DeclUneFonct                        {}
  | /* epsi */
  ;
DeclUneFonct: EnTeteFonct Corps                          {
    if ( ! $1 ) {
      comment( "automatic return" );
      vm_exec( vm_return );
    }
  }
  ;
EnTeteFonct: Type IDENT LPAR Parametres RPAR             {
    vm_exec( vm_label, jump_label++ );
    $$ = $1;
  }
  ;
Type: ENTIER                                             { $$ = true;  }
  | VOID                                                 { $$ = false; }
  ;
Parametres: VOID                                         {}
  | ListVar                                              {}
  | /* epsi */                                 /* Élargit le langage */
  ;
Corps: LACC DeclConst DeclVar SuiteInstr RACC            { end_block(); }
  ;
SuiteInstr: Instr SuiteInstr                             {}
  | /* epsi */                                           {}
  ;
InstrComp: LACC SuiteInstr RACC                          { end_block(); }
  ;
Instr: IDENT EGAL Exp PV                                 {
    update_variable_pop( get_variable( $1 ) );
  }
  | STAR IDENT EGAL Exp PV                               {
    VariableData *var = get_variable( $2 );
    if ( var->type != pointeur ) {
      yyerror( "La variable n'est pas du bon type." );
    } else {
      vm_exec( vm_set, get_addr( get_variable( $2 ) ) );
      vm_exec( vm_loadr );
      vm_exec( vm_swap );
      vm_exec( vm_pop );
      vm_exec( vm_saver );
    }
  }
  | IDENT EGAL MALLOC LPAR Exp RPAR PV                   {
    VariableData *global = create_variable( "", $5, entier );
    update_variable( get_variable( $1 ), get_addr( global ) );
  }
  | FREE LPAR Exp RPAR PV                                { /* TODO */ }
  | IF LPAR Exp RPAR FIXIF Instr %prec ENDIF             {
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
    vm_exec( vm_set,  $2 );
    vm_exec( vm_return );
  }
  | RETURN PV                                            {
    vm_exec( vm_return );
  }
  | READ LPAR IDENT RPAR PV                              {
    VariableData *var = get_variable( $3 );
    if ( var->type != entier ) {
      yyerror( "Impossible de read une variable non entière." );
    } else {
      vm_exec( vm_set, get_addr( var ) );
      vm_exec( vm_swap );
      vm_exec( vm_read );
      vm_exec( vm_saver );
    }
  }
  | PRINT LPAR Exp RPAR PV                               {
    vm_exec( vm_pop );
    vm_exec( vm_write );
  }
  | IDENT LPAR Arguments RPAR PV                         { /* TODO */ }
  | PV                                                   {}
  | InstrComp                                            { /* TODO */ }
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
    vm_exec( vm_pop );
    vm_exec( vm_load );
    vm_exec( vm_push );
    $$ = get_addr( $1 );
  }
  | ADR Variable                                         {
    vm_exec( vm_pop );
    vm_exec( vm_set, get_addr( $2 ) ); 
    vm_exec( vm_push );
    $$ = get_addr( $2 );
  }
  | NUM                                                  {
    vm_exec( vm_set, $$ = $1 );
    vm_exec( vm_push );
  }
  | IDENT LPAR Arguments RPAR                            {
    VariableData *var = get_variable( $1 );
    call_block( var );
  }
;

FIXIF:                                                   {
    vm_exec( vm_jumpf, $$ = jump_label += 2 );
  } ;
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

int yyerror( char *s ) {
  fprintf( stderr, "%s\n", s );
  return 0;
}

void free_variable_data( gpointer pointer ) {
  void free_variables( GList *actual );
  VariableData *data;;
  if ( pointer != NULL ) {
    data = pointer;
    free_variables( data->data.fonction.variables );
    free( data );
  }
}

void free_variables( GList *actual ) {
 /* g_list_free_full( actual, free_variable_data );*/
}

gint compare_data( gconstpointer data1, gconstpointer data2 ) {
  return strcmp( (char*)((VariableData*)data1)->name, (char*)((VariableData*)data2)->name );
}

VariableData *create_variable_outofrange( const char *name, int size, Type type ) {
  VariableData * data;
  if ( NULL == ( data = (VariableData*) malloc( sizeof(VariableData) ) ) ) {
    exit( EXIT_FAILURE );
  }
  if ( NULL == ( data->name = (char*) malloc( sizeof(char) * strlen( name ) ) ) ) {
    exit( EXIT_FAILURE );
  }
  strcpy( data->name, name );
  data->type = type;
  data->size = size;
  data->parent = actual_variable;

  return data;
}

void insert_variable( VariableData *data ) {
  GList *current_variables =
    ( (VariableData*) actual_variable->data )->data.fonction.variables;
  VariableData *last;

  if ( current_variables == NULL ) {
    data->addr = 0;
  } else {
    last = ( (VariableData*) g_list_last( current_variables )->data );
    data->addr = last->addr + last->size;
  }
  ( (VariableData*) actual_variable->data )->data.fonction.variables =
    g_list_append( current_variables, data );

  if ( data->size ) {
    vm_exec( vm_alloc, data->size );
  }
}

VariableData *create_variable( const char *name, int size, Type type ) {
  VariableData * data = create_variable_outofrange( name, size, type );
  insert_variable( data );
  comment("Variable inséré");
  comment( name );
  return data;
}

VariableData *create_fonction_outofrange(
    const char *name,
    int nb_arguments,
    bool isvoid,
    ...
    /* Le premier argument supplémentaire est le type de retour */
    /* les reste est le type de chacun des arguments */
  ) {
  va_list argp;
  int i;
  VariableData *var = create_variable_outofrange( name, 0, fonction );

  va_start( argp, isvoid );

  /* Gestion du typage */
  if ( isvoid ) {
    var->data.fonction.isvoid = true;
  } else {
    var->data.fonction.isvoid = false;
    var->data.fonction.retour = va_arg( argp, Type );
  }

  /* Gestion des listes */
  var->data.fonction.variables = NULL;
  var->parent = actual_variable;
  actual_variable = g_list_last( actual_variable );

  /* Gestion des arguments */
  var->data.fonction.nb_arguments = nb_arguments;
  for ( i = 0; i < nb_arguments; i++ ) {
    insert_variable( va_arg( argp, VariableData* ) );
  }

  va_end( argp );

  return var;
}

void insert_fonction( VariableData *fonction ) {
  static int fonction_label = 0;
  fonction->data.fonction.label = --fonction_label;
  vm_exec( vm_label, fonction_label );
}

VariableData *create_fonction(
    const char *name,
    int nb_arguments,
    bool isvoid,
    ...
    /* Le premier argument supplémentaire est le type de retour */
    /* les reste est le type de chacun des arguments */
  ) {
    VariableData *fonction = create_fonction_outofrange( name, nb_arguments, isvoid );
    insert_fonction( fonction );
    return fonction;
}

VariableData *create_block(
    int label,
    int nb_arguments,
    bool isvoid,
    ...
    /* Le premier argument supplémentaire est le type de retour */
    /* les reste est le type de chacun des arguments */
  ) {
    return create_fonction( "", label, nb_arguments, isvoid );
}

bool update_variable( VariableData *var, int value ) {
  if ( var->type == fonction ) {
    yyerror( "Impossible de modifier une fonction." );
  } else {
    vm_exec( vm_set, get_addr( var ) );
    vm_exec( vm_swap );
    vm_exec( vm_set, value );
    vm_exec( vm_saver );
  }
  return var;
}

int get_addr( VariableData *var ) {
  return var->addr;
}

bool update_variable_pop( VariableData *var ) {
  if ( var->type == fonction ) {
    yyerror( "Impossible de modifier une fonction." );
  } else {
    vm_exec( vm_set, get_addr( var ) );
    vm_exec( vm_swap );
    vm_exec( vm_pop );
    vm_exec( vm_saver );
  }
  return var;
}

void call_block( VariableData *var ) {
  if ( var->type != fonction ) {
    yyerror( "L'identifiant n'est pas un block.");
  } else {
    vm_exec( vm_call, get_addr( var ) );
    if ( ! var->data.fonction.isvoid ) {
      vm_exec( vm_push ); /* Car la valeur de retour est stockée dans reg1 */
    }
  }
}

void end_block() {
  GList *list = actual_variable;
  while ( list != NULL ) {
    if ( ( (VariableData*) list->data )->type == fonction ) {
      actual_variable = list;
      return;
    }
  }
  comment( "Auto return." );
  vm_exec( vm_return );
}

VariableData *get_variable( const char *name ) {
  char *com;
  GList *list =
    g_list_last( ( (VariableData*) actual_variable->data )->data.fonction.variables );

  while ( NULL != list ) {
    if ( strcmp( ((VariableData*) list->data)->name, name ) == 0 ) {
      return (VariableData*) list->data;
    }
    list = g_list_previous( list );
  }

  yyerror( "syntax error: variable non déclarée." );
  if ( -1 != asprintf( &com, "Déclaration implicite de \"%s\"", name ) ) {
    comment( com );
    free( com );
  }

  return create_variable( name, 1, entier );
}

void comment( const char *s ) {
  vm_exec( vm_comment, s );
}

void end_program() {
  vm_exec( vm_halt );
  vm_flush();
  free_variables( actual_variable );
}

void start_program() {
  VariableData *program = create_fonction_outofrange( "", 0, true );
  actual_variable = g_list_prepend( NULL, program );
}

int main( int argc, const char *argv[] ) {
  char extension[5];
  int size = 0, i;  
  char* argument = NULL;
  int out;
  int j = 0;
  char fin_ext[5];

  if ( 2 == argc || 3 == argc ) {
    size = strlen ( argv[1] );
    argument = ( char* ) malloc ( ( size - 4 ) * sizeof ( char ) );

    for ( i = 0 ; i < size - 4 ; i++ ) {
      argument [i] = argv[1][i];
    }
    for (; i <= size ; i++ ) {
      extension[i-4] = argv[1][i];
      fin_ext[j] = extension[i-4];
      j++;
    }
    if ( strcmp ( fin_ext, ".tpc" ) != 0 ) {
      fprintf ( stderr, "Erreur extension, le fichier doit être du type .tpc\n" );
      return 1;
    }
    if ( NULL == ( yyin = fopen( argv[1], "r" ) ) ) {
      fprintf ( stderr, "Erreur ouverture du fichier %s \n", argv[1] );
      return 1;
    }
    if ( argc == 3 && strcmp( argv[2], "-o") == 0 ){
      strcat ( argument, ".vm" );
      
      if ( -1 == ( out = open ( argument, O_CREAT | O_RDWR ) ) ) {
        perror ( "open" );
        exit( EXIT_FAILURE );
      } else if ( -1 == dup2( STDOUT_FILENO, out ) ) {
        perror ( "dup2" );
        exit( EXIT_FAILURE );
      }
    }
  } else if ( 1 == argc ){
    yyin = stdin;
  } else {
    fprintf( stderr, "usage: %s [src]\n", argv[0] );
    exit( EXIT_FAILURE );
  }
  yyparse();
  return 0;
}
