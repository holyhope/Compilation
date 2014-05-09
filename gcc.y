%{
  #include <stdlib.h>   /* utilise par les free de bison */
  #include <stdio.h>
  #include <string.h>
  #include <unistd.h>
  #include <glib.h>

  typedef struct {
    char *name;
    int addr;
  } Variable;

  int yyerror( char* );
  int yylex();
  int mode_declaratif = 0;

  FILE* yyin;
  int jump_label = 0;
  int jump_global = 0;
  void inst( const char * );
  void instarg( const char *, int );
  void comment( const char * );

  GList *list_variables;

  int create_variable( const char *name, int size );
  int get_addr( const char *name );

  void inst( const char *s );
  void instarg( const char *s, int n );
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

%type <num>   Exp NombreSigne Variable Instr

%type <num>   FIXIF FIXELSE WHILESTART WHILETEST ENDFUNCTION

%token DIV STAR MOD
%token MALLOC FREE PRINT READ MAIN
%token VRG PV EGAL RETURN
%token IF ELSE WHILE
%token LPAR RPAR LACC RACC LSQB RSQB
%token VOID ENTIER POINTEUR CONST

%nonassoc ELSE

%%

prog: DeclConst DeclVar DeclFonct DeclMain               {}
  ;
DeclConst: DeclConst CONST ListConst PV                  {}
  | /* epsi */
  ;
ListConst: ListConst VRG IDENT EGAL NombreSigne          {}
  | IDENT EGAL NombreSigne                               {}
  ;
NombreSigne: NUM                                         { $$ =  $1; }
  | ADDSUB NUM %prec ADDSUB_UNAIRE                       { if ( $1 == sub ) $$ = -$2; else $$ = $2; }
  ;
DeclVar: DeclVar VAR FIXDeclVar ListVar PV               { mode_declaratif = 0; }
  | /* epsi */
  ;
FIXDeclVar:                                              { mode_declaratif = 1; }
  ;
ListVar: ListVar VRG Variable                            {}
  | Variable                                             {}
  ;
Variable: STAR Variable                                 {
    if ( ! mode_declaratif ) {
      instarg( "SET", $2 );
      inst( "LOADR" );
      inst( "LOADR" );
      inst( "PUSH" );
    }
    $$ = $2;
  }
  | IDENT                                                {
    int addr;
    if ( mode_declaratif ) {
      addr = create_variable( $1, 1 );
    } else {
      addr = get_addr( $1 );
    }
    $$ = addr;
  }
  ;
DeclMain: EnTeteMain Corps                               {}
  ;
EnTeteMain: MAIN LPAR RPAR                               { instarg( "LABEL", 0 ); }
  ;
DeclFonct: DeclFonct DeclUneFonct                        {}
  | /* epsi */
  ;
DeclUneFonct: EnTeteFonct Corps ENDFUNCTION              { instarg( "JUMP", $3 );                 }
  ;
ENDFUNCTION:                                             { instarg( "LABEL", $$ = jump_label++ ); }
;
EnTeteFonct: Type IDENT LPAR Parametres RPAR             { instarg( "LABEL", jump_label++ );      }
  ;
Type: ENTIER
  | VOID
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
    instarg( "SET", get_addr( $1 ) );
    inst( "SWAP" );
    inst( "POP" );
    inst( "SAVER" );
    $$ = $3;
  }
  | STAR IDENT EGAL Exp PV                               {
    instarg( "SET", get_addr( $2 ) );
    inst( "LOAD" );
    inst( "SWAP" );
    inst( "POP" );
    inst( "SAVER" );
    $$ = $4;
  }
  | IDENT EGAL MALLOC LPAR Exp RPAR PV                   {
    int value = create_variable( $1, $5 );
    int addr = create_variable( $1, 1 );
    instarg( "SET", addr );
    inst( "SWAP" );
    instarg( "SET", value );
    inst( "SAVER" );
  }
  | FREE LPAR Exp RPAR PV                                { /* TODO */ }
  | IF LPAR Exp RPAR FIXIF Instr %prec ENDIF             { instarg( "LABEL", $5 ); } 
  | IF LPAR Exp RPAR FIXIF Instr  ELSE FIXELSE Instr     { instarg( "LABEL", $8 ); }
  | WHILE WHILESTART LPAR Exp RPAR WHILETEST Instr       { instarg( "JUMP", $2 ); instarg( "LABEL", $6 ); }
  | RETURN Exp PV                                        { instarg( "SET",  $2 ); inst( "RETURN" ); /* TODO: A vérifier */ }
  | RETURN PV                                            { inst( "RETURN" ); }
  | READ LPAR IDENT RPAR PV                              { inst( "READ" ); inst( "PUSH" ); }
  | PRINT LPAR Exp RPAR PV                               { inst( "POP" ); inst( "WRITE" ); }
  | IDENT LPAR Arguments RPAR PV                         { /* TODO */ }
  | PV                                                   { }
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
  | Exp DIV Exp                                          { inst( "POP" ); inst("SWAP"); inst( "POP" ); inst("DIV"); inst("PUSH"); $$ = $1 / $3; }
  | Exp MOD Exp                                          { inst( "POP" ); inst("SWAP"); inst( "POP" ); inst("MOD"); inst("PUSH"); $$ = $1 % $3; }
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
  | Variable                                             { inst( "POP" ); inst( "PUSH" ); $$ = $1; }
  | ADR Variable                                         { instarg( "SET", $2 ); inst( "PUSH" ); $$ = $2; }
  | NUM                                                  { instarg( "SET", $1 ); inst( "PUSH" ); $$ = $1; }
  | IDENT LPAR Arguments RPAR                            {}
  ;

VAR: ENTIER
  | POINTEUR
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
  return strcmp( (char*)((Variable*)data1)->name, (char*)((Variable*)data2)->name );
}

int create_variable( const char *name, int size ) {
  Variable * data;
  if ( NULL == ( data = (Variable*) malloc( sizeof(Variable) ) ) ) {
    exit( EXIT_FAILURE );
  }
  if ( NULL == ( data->name = (char*) malloc( sizeof(char) * strlen( name ) ) ) ) {
    exit( EXIT_FAILURE );
  }
  strcpy( data->name, name );
  data->addr = jump_global;
  list_variables = g_list_insert_sorted( list_variables, (gpointer)data, compare_data );

  instarg( "SET", data->addr );
  inst( "SWAP" );
  instarg( "SET", 0 );
  instarg( "ALLOC", size );
  inst( "SAVER" );

  jump_global += size;
  return data->addr;
}

int get_addr( const char *name ) {
  GList *list = g_list_first( list_variables );
  int result;
  while ( NULL != list ) {
    result = strcmp( ((Variable*) list->data)->name, name );
    if ( result == 0 ) {
      return ((Variable*) list->data)->addr;
    }
    list = g_list_next( list );
  }
  yyerror( "syntax error: variable non déclarée." );
  exit( EXIT_FAILURE );
}

void free_variables() {
  /* TODO */
}

void comment( const char *s ){
  printf( "#%s\n", s );
}

int main( int argc, const char *argv[] ) {
  char extension[5];
  int size = 0, i;  
  char* argument = NULL;

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
    if ( argc == 3 && strcmp(argv[2], "-o") == 0 ){
      strcat ( argument, ".vm" );
      if ( NULL == ( stdout = fopen ( argument,"w" ) ) ) {
        fprintf ( stderr, "Erreur ouverture fichier %s \n", argv[1] );
        return 1;
      }
    }

  } else if ( 1 == argc ){
    yyin = stdin;
  } else {
    fprintf( stderr, "usage: %s [src]\n", argv[0] );
    return 1;
  }
  yyparse();
  endProgram();
  return 0;
}
