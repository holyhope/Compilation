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

[<>] {
	switch ( *yytext ) {
		case '<': yylval.comparator = lt; break;
		case '>': yylval.comparator = gt; break;
		default: exit( 1 );
	}
	return COMP;
}

[<=|>=|==|!=]       {
	switch ( *yytext ) {
		case '<': yylval.comparator = lte; break;
		case '>': yylval.comparator = gte; break;
		case '=': yylval.comparator = eq;  break;
		case '!': yylval.comparator = neq; break;
		default: exit( 1 );
	}
	return COMP;
}

[\-\+&\*/%]             {
	switch ( *yytext ) {
		case '+': yylval.operator = add; return ADDSUB;
		case '-': yylval.operator = sub; return ADDSUB;
		case '*': yylval.operator = time; return STAR;
		case '/': yylval.operator = divi; return DIV;
		case '%': yylval.operator = modu; return MOD;
		case '&': return ADR;
		default: exit( 1 );
	}
}

[a-zA-Z][a-zA-Z0-9_]* { yylval.ident = yytext;   return IDENT;  }
.|\n return yytext[0];
%%
