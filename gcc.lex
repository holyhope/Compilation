%{
#include "gcc.h"
#include <stdio.h>
#include <stdlib.h>
  int fileno ( FILE *stream );                  /*non ansi*/
  enum{ booleen, entier, none } declaration;
%}
%option noyywrap
/* evite d'utiliser -lfl */
%%

[ \t]+ ;
"="             { return EGAL; }

"<"             { yylval.comparator = lt;  return COMP; }
">"             { yylval.comparator = gt;  return COMP; }
"=="            { yylval.comparator = eq;  return COMP; }
"<="            { yylval.comparator = lte; return COMP; }
">="            { yylval.comparator = gte; return COMP; }
"!="            { yylval.comparator = neq; return COMP; }

"+"             { yylval.comparator = add;  return ADDSUB;   }
"-"             { yylval.comparator = sub;  return ADDSUB;   }

"*"             { yylval.comparator = time; return OPERATOR; }
"/"             { yylval.comparator = divi; return OPERATOR; }
"%"             { yylval.comparator = modu; return OPERATOR; }

";"             { return PV;     }

[0-9]+                      { yylval.num   = atoi( yytext ); return NUM; }
\*[a-zA-Z][a-zA-Z0-9_]+     { yylval.ident = yytext + 1;     return ADR; }

"("        {return LPAR;     }
")"        {return RPAR;     }
"{"        {return LACC;     }
"}"        {return RACC;     }
"["        {return LSQB;     }
"]"        {return RSQB;     }
","        {return VRG;      }
"if"       {return IF;       }
"else"     {return ELSE;     }
"main"     {return MAIN;     }
"void"     {return VOID;     }
"read"     {return READ;     }
"free"     {return FREE;     }
"const"    {return CONST;    }
"print"    {return PRINT;    }
"while"    {return WHILE;    }
"entier"   {return ENTIER;   }
"malloc"   {return MALLOC;   }
"return"   {return RETURN;   }
"pointeur" {return POINTEUR; }

[a-zA-Z][a-zA-Z0-9_]*      { yylval.ident = yytext;   return IDENT;  }

.|\n return yytext[0];
%%
