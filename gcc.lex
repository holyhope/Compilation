%{
  #include "gcc.h"
  #include <stdio.h>
  #include <stdlib.h>
  #include <string.h>
  int asprintf( char **strp, const char *fmt, ... );
  int fileno( FILE* );
%}

%option noyywrap
/* evite d'utiliser -lfl */

%%

"\n"            { return NEW_LINE; }
"="             { return EGAL; }

"<"             { yylval.comparator = lt;  return COMP; }
">"             { yylval.comparator = gt;  return COMP; }
"=="            { yylval.comparator = eq;  return COMP; }
"<="            { yylval.comparator = lte; return COMP; }
">="            { yylval.comparator = gte; return COMP; }
"!="            { yylval.comparator = neq; return COMP; }

"+"             { yylval.operator = add;  return ADDSUB;   }
"-"             { yylval.operator = sub;  return ADDSUB;   }

"*"             { return STAR; }
"/"             { return DIV;  }
"%"             { return MOD;  }

";"             { return PV;       }
","             { return VRG;      }
"&"             { return ADR;      }
"("             { return LPAR;     }
")"             { return RPAR;     }
"{"             { return LACC;     }
"}"             { return RACC;     }
"["             { return LSQB;     }
"]"             { return RSQB;     }
"if"            { return IF;       }
"var"           { return VAR;      }
"else"          { return ELSE;     }
"main"          { return MAIN;     }
"void"          { return VOID;     }
"read"          { return READ;     }
"free"          { return FREE;     }
"const"         { return CONST;    }
"print"         { return PRINT;    }
"while"         { return WHILE;    }
"entier"        { return ENTIER;   }
"malloc"        { return MALLOC;   }
"return"        { return RETURN;   }

[0-9]+                 { yylval.num   = atoi( yytext ); return NUM; }

[a-zA-Z][a-zA-Z0-9_]*  { asprintf( &yylval.ident, "%s", yytext ); return IDENT; }

[ \t\r]+        {}

. { return yytext[0]; }

%%
