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
%}

%union {
  void*                                       adr;
  unsigned int                                num;
  char*                                       ident;
  enum { gte, gt, lt, lte, eq, neq  }         comparator;
  enum { add, sub, time, divi, modu }         operator;
  enum { vrg, pv }                            separator;
  enum { lpar, rpar, lacc, racc, lsqb, rsqb } block;
}

%left "<" ">" "<=" "=>" "==" "!="  /* Comparateurs                */
%left "+" "-"                      /* additions / soustractions   */
%left "*" "/"                      /* multiplications / divisions */
%left UMINUS                       /* Moins unaire                */
%right PTR ADR                     /* Pointeur                    */

%token <comp>        COMP
%token <operator>    DIV ADDSUB STAR OPERATOR
%token <num>         NUM
%token <ident>       IDENT
%token <ident>       ADR

%token IF ELSE MAIN WHILE VRG PV EGAL PRINT READ
%token LPAR RPAR LACC RACC LSQB RSQB
%token VOID ENTIER POINTEUR

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%
prog: DeclConst DeclVar DeclFonct DeclMain
  ;
DeclConst: DeclConst CONST ListConst PV
  |
  ;
ListConst: ListConst VRG IDENT EGAL NombreSigne
  | IDENT EGAL NombreSigne
  ;
NombreSigne: NUM
  | ADDSUB NUM
  ;
DeclVar: DeclVar VAR ListVar PV                                         
  |
  ;
ListVar: ListVar VRG Variable
  | Variable
Variable: STAR Variable
  | IDENT
  ;
DeclMain: EnTeteMain Corps
  ;
EnTeteMain: MAIN LPAR RPAR
  ;
DeclFonct: DeclFonct DeclUneFonct
  | 
  ;
DeclUneFonct: EnTeteFonct Corps
  ;
EnTeteFonct: Type IDENT LPAR Parametres RPAR
  ;
Type: ENTIER
  | VOID
  ;
Parametres: VOID
  | ListVar
  |
  ;
Corps: LACC DeclConst DeclVar SuiteInstr RACC
  ;
SuiteInstr: SuiteInstr Instr
  |
  ;
InstrComp: LACC SuiteInstr RACC
  ;
Instr: IDENT EGAL Exp PV
  | STAR IDENT EGAL Exp PV
  | IDENT EGAL MALLOC LPAR Exp RPAR PV
  | FREE LPAR Exp RPAR PV
  | IF LPAR Exp RPAR Instr %prec LOWER_THAN_ELSE
  | IF LPAR Exp RPAR Instr ELSE Instr
  | WHILE LPAR Exp RPAR Instr
  | RETURN Exp PV
  | RETURN PV
  | IDENT LPAR Arguments RPAR PV
  | READ LPAR IDENT RPAR PV
  | PRINT LPAR Exp RPAR PV
  | PV
  | InstrComp
  ;
Arguments: ListExp
  |
  ;
ListExp: ListExp VRG Exp
  | Exp
  ;
Exp: Exp ADDSUB Exp                                                    
  | Exp STAR Exp
  | Exp DIV Exp
  | Exp COMP Exp
  | ADDSUB Exp
  | LPAR Exp RPAR
  | Variable
  | ADR Variable
  | NUM                                                                 { printf("%d\n", $1) ; }
  | IDENT LPAR Arguments RPAR                                           { }
  ;


VAR: ENTIER
  | POINTEUR
  ;
%%

int yyerror(char* s) {
  fprintf(stderr,"%s\n",s);
  return 0;
}

void endProgram() {
  printf("HALT\n");
}

void inst(const char *s){
  printf("%s\n",s);
}

void instarg(const char *s,int n){
  printf("%s\t%d\n",s,n);
}


void comment(const char *s){
  printf("#%s\n",s);
}

int main(int argc, char** argv) {
  if(argc==2){
    yyin = fopen(argv[1],"r");
  }
  else if(argc==1){
    yyin = stdin;
  }
  else{
    fprintf(stderr,"usage: %s [src]\n",argv[0]);
    return 1;
  }
  yyparse();
  endProgram();
  return 0;
}
