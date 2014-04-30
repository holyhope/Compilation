%{
  #include <stdlib.h>   /* utilise par les free de bison */
  #include <stdio.h>
  #include <string.h>
  #include <unistd.h>
  int yyerror( char* );
  int yylex();

  FILE* yyin;
  int jump_label = 0;
  void inst( const char * );
  void instarg( const char *, int );
  void comment( const char * );

  void create_variable( const char *name, int value ) {
    
  }
%}

%union {
  void*                                       adr;
  unsigned int                                num;
  char*                                       ident;
  enum { gte, gt, lt, lte, eq, neq  }         comparator;
  enum { add, sub }                           operator;
}

%left "<" ">" "<=" "=>" "==" "!="  /* Comparateurs                */
%left "+" "-"                      /* additions / soustractions   */
%left "*" "/"                      /* multiplications / divisions */
%left UMINUS                       /* Moins unaire                */
%right PTR ADR                     /* Pointeur                    */

%token <comparator>  COMP
%token <operator>    ADDSUB
%token <num>         NUM
%token <ident>       IDENT ADR

%type <num>   Exp NombreSigne

%type <num>   FIXIF FIXELSE WHILESTART WHILETEST ENDFUNCTION

%token DIV STAR MOD
%token MALLOC FREE PRINT READ
%token IF ELSE MAIN WHILE VRG PV EGAL RETURN
%token LPAR RPAR LACC RACC LSQB RSQB
%token VOID ENTIER POINTEUR CONST

%nonassoc ELSE

%%

prog: DeclConst DeclVar DeclFonct DeclMain
  ;
DeclConst: DeclConst CONST ListConst PV
  | /* epsi */
  ;
ListConst: ListConst VRG IDENT EGAL NombreSigne
  | IDENT EGAL NombreSigne
  ;
NombreSigne: NUM                                         { $$ =  $1; }
  | ADDSUB NUM                                           { $$ = -$2; }
  ;
DeclVar: DeclVar VAR ListVar PV
  | /* epsi */
  ;
ListVar: ListVar VRG Variable                            {}
  | Variable                                             {}
  ;
Variable: STAR Variable                                  { /* TODO: pointeur */ }
  | IDENT LSQB ENTIER RSQB                               { /* TODO: tableau taille $3 */ }
  | IDENT                                                { /* TODO: créer variable $1 */ }
  ;
DeclMain: EnTeteMain Corps                               {}
  ;
EnTeteMain: MAIN LPAR RPAR                               { instarg( "LABEL", 0 ); }
  ;
DeclFonct: DeclFonct                                     {}
  | /* epsi */
  ;
DeclUneFonct: EnTeteFonct Corps ENDFUNCTION              { instr( "JUMP", $3 );                    }
  ;
ENDFUNCTION:                                             { instrarg( "LABEL", $$ = jump_label++ ); }
;
EnTeteFonct: Type IDENT LPAR Parametres RPAR             { instarg( "LABEL", jump_label++ );       }
  ;
Type: ENTIER
  | VOID
  ;
Parametres: VOID                                         {}
  | ListVar                                              {}
  | /* epsi */                                 /* Élargit le langage */
  ;
Corps: LACC DeclConst DeclVar SuiteInstr RACC
  ;
SuiteInstr: SuiteInstr Instr                             {}
  | /* epsi */                                           {}
  ;
InstrComp: LACC SuiteInstr RACC                          {}
  ;
Instr: IDENT EGAL Exp PV                                 { /* TODO */ instarg( "ALLOC", 1 ); /* Récupérer la variable $1 */ instarg( "SET", $3 ); inst( "PUSH" ); }
  | STAR IDENT EGAL Exp PV                               { /* TODO */ }
  | IDENT EGAL MALLOC LPAR Exp RPAR PV                   { /* TODO */ }
  | FREE LPAR Exp RPAR PV                                { /* TODO */ }
  | IF LPAR Exp RPAR FIXIF Instr %prec ENDIF             { instarg( "LABEL", $5 ); } 
  | IF LPAR Exp RPAR FIXIF Instr  ELSE FIXELSE Instr     { instarg( "LABEL", $8 ); }
  | WHILE WHILESTART LPAR Exp RPAR WHILETEST Instr       { instarg( "JUMP", $2 ); instarg( "LABEL", $6 ); }
  | RETURN Exp PV                                        { instarg( "SET",  $2 ); inst( "RETURN" ); }
  | RETURN PV                                            { inst( "RETURN" ); }
  | IDENT LPAR Arguments RPAR PV                         { /* TODO */ }
  | READ LPAR IDENT RPAR PV                              { inst("READ"); inst("PUSH"); }
  | PRINT LPAR Exp RPAR PV                               { inst("POP");  inst("WRITE"); }
  | PV                                                   { }
  | InstrComp                                            { /* TODO */ }
  ;
Arguments: ListExp
  | /* epsi */
  ;
ListExp: ListExp VRG Exp
  | Exp
  ;
Exp: Exp ADDSUB Exp { instarg("SET", $3);
    inst("SWAP");
    instarg("SET", $1); 
    if ($2==add) 
          inst("ADD"); 
    else 
          inst("SUB");
    inst("PUSH"); 
  }
  | Exp STAR Exp                                         { instarg("SET", $3 ); inst("SWAP"); instarg( "SET", $1 ); inst("MULT"); inst("PUSH"); }
  | Exp DIV Exp                                          { instarg("SET", $3 ); inst("SWAP"); instarg( "SET", $1 ); inst("DIV"); inst("PUSH"); }
  | Exp MOD Exp  { instarg("SET", $3); inst("SWAP"); instarg("SET", $1); inst("MOD"); inst("PUSH"); }
  | Exp COMP Exp {
                  instarg("SET", $3); 
                  inst("SWAP"); 
                  instarg("SET", $1);
                  switch( $2 ) {
                    case eq: inst("EQUAL"); break;
                    case neq:inst("NOTEQ"); break;
                    case lt: inst("LOW");   break;
                    case gt: inst("GREAT"); break;
                    case lte: inst("LEQ");  break;
                    case gte: inst("GEQ");  break;
                    default: inst("UNDEFINED COMPARATOR");
                  }
  inst("WRITE");
  }
  | ADDSUB Exp                                           { if($1==sub) $$=($2); else $$=$2; } /* TODO ######### */
  | LPAR Exp RPAR                                        { $$ = $2; }
  | Variable                                             { }
  /*| ADR Variable ################ */
  | NUM { instarg("SET",$$=$1); }
  | IDENT LPAR Arguments RPAR                            {  }
  ;

VAR: ENTIER
  | POINTEUR
  ;

FIXIF:                                                   { instarg( "JUMPF", $$ = jump_label += 2 ); } ;
FIXELSE:                                                 { instarg( "JUMP",  $$ = jump_label      ); instarg( "LABEL", jump_label - 1 ); } ;
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


void comment( const char *s ){
  printf( "#%s\n", s );
}

int main( int argc, const char *argv[] ) {
  if ( 2 == argc ) {
    yyin = fopen( argv[1], "r" );
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
