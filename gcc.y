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
  
  typedef struct var {
    char *name;                               /* Nom de la variable                */
    Type type; /* Type de la variable               */
    int addr;                                 /* Adresse dans la machine virtuelle */

    /* Dans le cas d'une fonction */
    union {
      struct func {
        int nb_argument;
        Type *arguments;                     /* Arguments                          */
        bool isvoid;
        Type retour;                         /* Valeur de retour                   */
      } fonction;
      bool local;
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

  GList *list_variables;

  VariableData *create_variable_local( const char *name, int size, Type type );
  VariableData *create_variable_global( int size );
  VariableData *get_variable( const char *name );
  int get_addr( VariableData * );
  bool is_local( VariableData *var );
  bool is_global( VariableData *var );
  bool update_variable( VariableData *var, int value );
  bool update_variable_pop( VariableData *var );
  VariableData *create_fonction( const char *name, int nb_arguments, int isvoid, Type retour, ... );

  void inst( const char *s );
  void instarg( const char *s, int n );
  void endProgram();
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
      var = create_variable_local( $2, 1, pointeur );
    } else {
      var = get_variable( $2 );
      if ( var->type != pointeur ) {
        yyerror( "la variable n'est pas un pointeur." );
      } else {
        inst( "POP" );
        if ( var->data.local ) {
          inst( "LOADR" );
        } else {
          inst( "LOAD" );
        }
        inst( "PUSH" );
      }
    }
    $$ = var;
  }
  | IDENT                                                {
    VariableData *var;
    if ( mode_declaratif ) {
      var = create_variable_local( $1, 1, entier );
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
EnTeteMain: MAIN LPAR RPAR                               { instarg( "LABEL", 0 ); }
  ;
DeclFonct: DeclFonct DeclUneFonct                        {
    
  }
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
Corps: LACC DeclConst DeclVar SuiteInstr RACC            {}
  ;
SuiteInstr: Instr SuiteInstr                             {}
  | /* epsi */                                           {}
  ;
InstrComp: LACC SuiteInstr RACC                          {}
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
      if ( var->data.local ) {
        inst( "LOADR" );
      } else {
        inst( "LOAD" );
      }
      inst( "SWAP" );
      inst( "POP" );
      if ( var->data.local ) {
        inst( "SAVER" );
      } else {
        inst( "SAVE" );
      }
    }
  }
  | IDENT EGAL MALLOC LPAR Exp RPAR PV                   {
    VariableData *global = create_variable_global( $5 );
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
    if ( var->type != fonction ) {
      yyerror( "L'identifiant n'est pas une fonction.");
    } else {
      instarg( "CALL", get_addr( var ) );
      if ( ! var->data.fonction.isvoid ) {
        inst( "PUSH" ); /* Car la valeur de retour est stockée dans reg1 */
      }
    }
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

void endProgram() {
  printf( "HALT\n" );
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

VariableData *create_variable( const char *name, int size, int *index, Type type ) {
  VariableData * data;
  if ( NULL == ( data = (VariableData*) malloc( sizeof(VariableData) ) ) ) {
    exit( EXIT_FAILURE );
  }
  if ( NULL == ( data->name = (char*) malloc( sizeof(char) * strlen( name ) ) ) ) {
    exit( EXIT_FAILURE );
  }
  strcpy( data->name, name );
  data->addr = *index;
  data->type = type;
  list_variables = g_list_insert_sorted( list_variables, (gpointer)data, compare_data );

  *index += size;
  return data;
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

VariableData *create_variable_local( const char *name, int size, Type type ) {
  VariableData *var = create_variable( name, size, &variable_local, type );
  var->data.local = true;
  instarg( "ALLOC", size );
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

VariableData *create_variable_global( int size ) {
  VariableData *var = create_variable( "", size, &variable_global, entier );
  var->data.local = false;
  return var;
}

VariableData *create_fonction( const char *name, int nb_arguments, int isvoid, Type retour, ... ) {
  va_list argp;
  int i;
  VariableData *var = create_variable( name, 1, &variable_local, fonction );

  if ( isvoid ) {
    var->data.fonction.isvoid = true;
  } else {
    var->data.fonction.retour = retour;
  }

  va_start( argp, retour );
  for ( i = 0; i < nb_arguments; i++ ) {
    var->data.fonction.arguments[ i ] = va_arg( argp, Type );
  }
  va_end( argp );

  return var;
}

VariableData *get_variable( const char *name ) {
  GList *list = g_list_first( list_variables );
  while ( NULL != list ) {
    if ( strcmp( ((VariableData*) list->data)->name, name ) == 0 ) {
      return (VariableData*) list->data;
    }
    list = g_list_next( list );
  }
  yyerror( "syntax error: variable non déclarée." );
  exit( EXIT_FAILURE );
}

void free_variables() {
  /* TODO */
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
