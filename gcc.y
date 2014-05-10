%{
  #include <stdlib.h>   /* utilise par les free de bison */
  #include <stdio.h>
  #include <string.h>
  #include <unistd.h>
  #include <glib.h>
  #include <stdbool.h>
  #include <sys/stat.h>
  #include <fcntl.h>

  #define MAX_MALLOC 1000

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

    /* Données supplémentaires */
    union {
      FonctionData *fonction; /* Dans le cas d'une fonction */
      UnamedBlockData *block; /* Dans le cas d'un block */
    } data;
  } VariableData;

  int yyerror( char* );
  int yylex();
  int mode_declaratif = 0;

  FILE* yyin;
  int jump_label = 1;
  int variable_global = 0;
  int variable_local = MAX_MALLOC;
  int encapsule;

  void inst( const char * );
  void instarg( const char *, int );
  void comment( const char * );

  GList *actual_variable;

  VariableData *get_variable( const char *name );
  int get_addr( VariableData * );
  bool is_local( VariableData *var );
  bool is_global( VariableData *var );
  bool update_variable( VariableData *var, int value );
  bool update_variable_pop( VariableData *var );
  VariableData *create_fonction( const char *name, int nb_arguments, bool isvoid, ... );
  VariableData *create_variable( const char *name, int size, Type type );

  void inst( const char *s );
  void instarg( const char *s, int n );
  void call_function( VariableData * );
  void endProgram();

  void end_block();

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

prog: Fixprog DeclConst DeclVar DeclFonct DeclMain       { endProgram(); }
  ;
Fixprog:                                                 { instarg( "ALLOC", MAX_MALLOC ); }
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
Variable: STAR IDENT                                     {
    VariableData *var;
    if ( mode_declaratif ) {
      var = create_variable( $2, 1, pointeur );
    } else {
      var = get_variable( $2 );
      if ( var->type != pointeur ) {
        yyerror( "la variable n'est pas un pointeur." );
      } else {
        inst( "POP" );
        inst( "LOADR" );
        inst( "PUSH" );
      }
    }
    $$ = var;
  }
  | IDENT                                                {
    VariableData *var;
    if ( mode_declaratif ) {
      var = create_variable( $1, 1, entier );
    } else {
      var = get_variable( $1 );
      instarg( "SET", get_addr( var ) );
      inst( "PUSH" );
    }
    $$ = var;
  }
  ;
DeclMain: EnTeteMain Corps                               {}
  ;
EnTeteMain: MAIN LPAR RPAR                               { instarg( "LABEL", 0 );
  create_fonction( "main", 0, true );
  }
  ;
DeclFonct: DeclFonct DeclUneFonct                        {}
  | /* epsi */
  ;
DeclUneFonct: EnTeteFonct Corps                          { if ( ! $1 ) inst( "RETURN" );       }
  ;
EnTeteFonct: Type IDENT LPAR Parametres RPAR             { instarg( "LABEL", jump_label++ ); $$ = $1;   }
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
      instarg( "SET", get_addr( get_variable( $2 ) ) );
      inst( "LOADR" );
      inst( "SWAP" );
      inst( "POP" );
      inst( "SAVER" );
    }
  }
  | IDENT EGAL MALLOC LPAR Exp RPAR PV                   {
    VariableData *global = create_variable( "", $5, entier );
    update_variable( get_variable( $1 ), get_addr( global ) );
  }
  | FREE LPAR Exp RPAR PV                                { /* TODO */ }
  | IF LPAR Exp RPAR FIXIF Instr %prec ENDIF             { instarg( "LABEL", $5 ); } 
  | IF LPAR Exp RPAR FIXIF Instr  ELSE FIXELSE Instr     { instarg( "LABEL", $8 ); }
  | WHILE WHILESTART LPAR Exp RPAR WHILETEST Instr       { instarg( "JUMP", $2 ); instarg( "LABEL", $6 ); }
  | RETURN Exp PV                                        { instarg( "SET",  $2 ); inst( "RETURN" ); }
  | RETURN PV                                            { inst( "RETURN" ); }
  | READ LPAR IDENT RPAR PV                              {
    VariableData *var = get_variable( $3 );
    if ( var->type != entier ) {
      yyerror( "Impossible de read une variable non entière." );
    } else {
      instarg( "SET", get_addr( var ) );
      inst( "SWAP" );
      inst( "READ" );
      inst( "SAVER" );
    }
  }
  | PRINT LPAR Exp RPAR PV                               {
    inst( "POP" );
    inst( "WRITE" );
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
    inst( "POP" );
    inst("SWAP");
    inst( "POP" );
    if ( $2 == add ) 
          inst( "ADD" ); 
    else 
          inst( "SUB" );
    inst( "PUSH" );
  }
  | Exp STAR Exp                                         {
    inst( "POP" );
    inst("SWAP");
    inst( "POP" );
    inst("MULT");
    inst("PUSH");
  }
  | Exp DIV Exp                                          { inst( "POP" ); inst("SWAP"); inst( "POP" ); inst( "DIV" ); inst( "PUSH" ); $$ = $1 / $3; }
  | Exp MOD Exp                                          { inst( "POP" ); inst("SWAP"); inst( "POP" ); inst( "MOD" ); inst( "PUSH" ); $$ = $1 % $3; }
  | Exp COMP Exp                                         {
    instarg( "SET", $3 ); 
    inst( "SWAP" ); 
    instarg( "SET", $1 );
    switch( $2 ) {
      case lt:  inst( "LOW"   ); $$ = $1 <  $2; break;
      case gt:  inst( "GREAT" ); $$ = $1 >  $2; break;
      case eq:  inst( "EQUAL" ); $$ = $1 == $2; break;
      case lte: inst( "LEQ"   ); $$ = $1 <= $2; break;
      case gte: inst( "GEQ"   ); $$ = $1 >= $2; break;
      case neq: inst( "NOTEQ" ); $$ = $1 != $2; break;
      default: exit( EXIT_FAILURE );
    }
    inst("WRITE");
  }
  | ADDSUB Exp %prec ADDSUB_UNAIRE                       { if ( $1 == sub ) $$ = -$2; else $$ = $2; }
  | LPAR Exp RPAR                                        { $$ = $2; }
  | Variable                                             { inst( "POP" ); inst( "LOAD" ); inst( "PUSH" ); $$ = get_addr( $1 ); }
  | ADR Variable                                         {}
  | NUM                                                  { instarg( "SET", $$ = $1 ); inst( "PUSH" ); }
  | IDENT LPAR Arguments RPAR                            {
    VariableData *var = get_variable( $1 );
    call_function( var );
  }
  ;

FIXIF:                                                   { instarg( "JUMPF", $$ = jump_label += 2 ); } ;
FIXELSE:                                                 { instarg( "JUMP",  $$ = jump_label++    ); instarg( "LABEL", $$=$<num>-3 ); } ;
WHILESTART:                                              { instarg( "LABEL", $$ = jump_label++    ); } ;
WHILETEST:                                               { instarg( "JUMPF", $$ = jump_label++    ); } ;

%%

int yyerror( char *s ) {
  fprintf( stderr, "%s\n", s );
  return 0;
}

void free_variable( GList *actual );

void free_variable_data( VariableData *data ) {
  free_variable( data->data.fonction->variables );
  free( data );
}

void free_variable( GList *actual ) {
  GList **variables = &( (VariableData*) actual->data )->data.fonction->variables;
  while ( *variables != NULL ) {
    free_variable_data( (*variables)->data );
    g_list_free_1( *variables );
  }
  g_list_free_1( actual );
}

void free_variables() {
  GList *variables = g_list_first( actual_variable ), *tmp;
  while ( NULL == ( tmp = g_list_next( variables ) ) ) {
    free_variable( tmp );
  }
  free_variable( variables );
}

void endProgram() {
  printf( "HALT\n" );
  free_variables();
}

void inst( const char *s ) {
  printf( "%s\n", s );
}

void instarg( const char *s, int n ) {
  printf( "%s\t%d\n", s, n );
}

gint compare_data( gconstpointer data1, gconstpointer data2 ) {
  return strcmp( (char*)((VariableData*)data1)->name, (char*)((VariableData*)data2)->name );
}

VariableData *create_variable_outofrange( const char *name, int size, Type type ) {
  VariableData * data;
  GList **local_variables;
  if ( NULL == ( data = (VariableData*) malloc( sizeof(VariableData) ) ) ) {
    exit( EXIT_FAILURE );
  }
  if ( NULL == ( data->name = (char*) malloc( sizeof(char) * strlen( name ) ) ) ) {
    exit( EXIT_FAILURE );
  }
  strcpy( data->name, name );
  data->type = type;
  data->size = size;

  local_variables = &( (VariableData*) actual_variable->data )->data.fonction->variables;
  if ( local_variables == NULL ) {
    data->addr = 0;
  } else {
    data->addr = ( (VariableData*) (*local_variables)->data )->addr +
      ( (VariableData*) (*local_variables)->data )->size;
  }

  return data;
}

void insert_variable( VariableData *data ) {
  actual_variable = g_list_append( actual_variable, data );
  instarg( "ALLOC", data->size );
}

VariableData *create_variable( const char *name, int size, Type type ) {
  VariableData * data = create_variable_outofrange( name, size, type );
  insert_variable( data );
  return data;
}

VariableData *create_fonction(
    const char *name,
    int nb_arguments,
    bool isvoid,
    ...
    /* Le premier argument supplémentaire est le type de retour */
    /* les reste est le type de chacun des arguments */
  ) {
  va_list argp;
  int i;
  VariableData *var = create_variable( name, 1, fonction );

  va_start( argp, isvoid );

  /* Gestion du typage */
  if ( isvoid ) {
    var->data.fonction->isvoid = true;
  } else {
    var->data.fonction->isvoid = false;
    var->data.fonction->retour = va_arg( argp, Type );
  }

  /* Gestion des listes */
  var->data.fonction->variables = NULL;
  actual_variable = g_list_last( actual_variable );

  /* Gestion des arguments */
  var->data.fonction->nb_arguments = nb_arguments;
  for ( i = 0; i < nb_arguments; i++ ) {
    insert_variable( va_arg( argp, VariableData* ) );
  }

  va_end( argp );


  return var;
}

bool update_variable( VariableData *var, int value ) {
  if ( var->type == fonction ) {
    yyerror( "Impossible de modifier une fonction." );
  } else {
    instarg( "SET", get_addr( var ) );
    inst( "SWAP" );
    instarg( "SET", value );
    if ( is_local( var ) ) {
      inst( "SAVER" );
    } else {
      inst( "SAVE" );
    }
  }
  return var;
}

bool is_global( VariableData *var ) {
  return var->addr < MAX_MALLOC;
}

bool is_local( VariableData *var ) {
  return ! is_global( var );
}

int get_addr( VariableData *var ) {
  return is_global( var ) ? var->addr : var->addr - MAX_MALLOC;
}

bool update_variable_pop( VariableData *var ) {
  if ( var->type == fonction ) {
    yyerror( "Impossible de modifier une fonction." );
  } else {
    instarg( "SET", get_addr( var ) );
    inst( "SWAP" );
    inst( "POP" );
    if ( is_local( var ) ) {
      inst( "SAVER" );
    } else {
      inst( "SAVE" );
    }
  }
  return var;
}

void call_function( VariableData *var ) {
  if ( var->type != fonction ) {
    yyerror( "L'identifiant n'est pas une fonction.");
  } else {
    instarg( "CALL", get_addr( var ) );
    if ( ! var->data.fonction->isvoid ) {
      inst( "PUSH" ); /* Car la valeur de retour est stockée dans reg1 */
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
}

VariableData *get_variable( const char *name ) {
  GList *list = ( (VariableData*) actual_variable->data )->data.fonction->variables;
  while ( NULL != list ) {
    if ( strcmp( ((VariableData*) list->data)->name, name ) == 0 ) {
      return (VariableData*) list->data;
    }
    list = g_list_previous( list );
  }
  yyerror( "syntax error: variable non déclarée." );
  exit( EXIT_FAILURE );
}

void comment( const char *s ) {
  printf( "#%s\n", s );
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
  } else if ( 1 == argc ){
    yyin = stdin;
  } else {
    fprintf( stderr, "usage: %s [src]\n", argv[0] );
    exit( EXIT_FAILURE );
  }
  yyparse();
  return 0;
}
