%{
/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#include <stdlib.h>
#include <string.h>

#include "parser.h"
#include "parser.tab.h"

char yyfilename[80] = "input";
int yyline=1;
YYSTYPE	yylval;

static int grab( int type, int remove );
static void count_newlines();
static void process_cpp_line();
static void scanner_error();

/* PZK 6/8/06: changed kill to killa so can intercept kill() system call */
%}

%START			C_Comment
ALPHA			[a-zA-Z_]
ALPHANUM		[a-zA-Z0-9_]
BRACE			"}"
NOTBRACE		[^\}]
ONEBRACE		({BRACE}{NOTBRACE})
STAR			"*"
NOTSTAR			[^\*]
NOTSLASH		[^\/]
NOTEND			({STAR}{NOTSLASH})
%%

"/*"({NOTSTAR}|{NOTEND})*"*/"	count_newlines();
"//".*			;
[\t ]*			;
#.*\n			process_cpp_line();
\n			count_newlines();
const			return grab( CONST, 0 );
struct			return grab( STRUCT, 0 );
unsigned		return grab( UNSIGNED, 0 );
in			return grab( IN, 0 );
out			return grab( OUT, 0 );
string			return grab( STRING, 0 );
array			return grab( ARRAY, 0 );
opaque			return grab( OPAQUE, 0 );
killa			return grab( KILL, 0 );
entry			return grab( ENTRY, 0 );
libcall			return grab( LIBCALL, 0 );
library			return grab( LIBRARY, 0 );
syscall			return grab( SYSCALL, 0 );
plain			return grab( PLAIN, 0 );
agent_prologue		return grab( AGENT_PROLOGUE, 0 );
agent_action		return grab( AGENT_ACTION, 0 );
shadow_prologue		return grab( SHADOW_PROLOGUE, 0 );
shadow_action		return grab( SHADOW_ACTION, 0 );
not_supported		return grab( NOT_SUPPORTED, 0 );
file_table_name		return grab( FILE_TABLE_NAME, 0 );
local_name		return grab( LOCAL_NAME, 0 );
remote_name		return grab( REMOTE_NAME, 0 );
options			return grab( OPTIONS, 0 );
switch_code		return grab( SWITCH_CODE, 0 );
external		return grab( EXTERNAL, 0 );
instead			return grab( INSTEAD, 0 );
indirect		return grab( INDIRECT, 0 );
also			return grab( ALSO, 0 );
"{{"({ONEBRACE}|{NOTBRACE})*"}}" return grab( BIG_CODE, 2 );
"("			return grab( LPAREN, 0 );
")"			return grab( RPAREN, 0 );
"["			return grab( LBRACKET, 0 );
"]"			return grab( RBRACKET, 0 );
","			return grab( COMMA, 0 );
"*"			return grab( STAR, 0 );
";"			return grab( SEMICOLON, 0 );
{ALPHA}{ALPHANUM}*	return grab( SYMBOL, 0 );
\"[^"]*\"		return grab( CODE, 1 );
.			scanner_error(yytext);
%%

int yywrap()
{
        yyline = 0;
        strcpy(yyfilename,"input");
	return feof(yyin);
}

void count_newlines()
{
	char * p;
	for(p=yytext;*p;p++)
		if( *p=='\n' )
			yyline++;
}

void process_cpp_line()
{
	sscanf(yytext,"# %d %s",&yyline,yyfilename);
}

int grab( int type, int remove )
{
	int i;

	if(yyleng>MAX_TOKEN_SIZE) {
		scanner_error("code fragment is awfully big...");
		scanner_error("(perhaps you should use @include?)");
		exit(-1);
	}

	yylval.token = malloc(sizeof(struct token));
	if(!yylval.token) {
		scanner_error("out of memory\n");
		exit(-1);
	}

	yylval.token->text = malloc(yyleng+1);
	yylval.token->type = type;
	if(!yylval.token->text) {
		scanner_error("out of memory");
		exit(-1);
	}

	strcpy(yylval.token->text,&yytext[remove]);
	yylval.token->text[yyleng-remove*2] = 0;

	yylval.token->line = yyline;
	yylval.token->file = yyfilename;

	for( i=0; i<(yyleng-remove*2); i++ ) {
		if( yylval.token->text[i]=='@' ) {
			yylval.token->text[i]='#';
		}
		if( yylval.token->text[i]=='\n' ) {
			yyline++;
		}
	}

	return type;
}

void scanner_error( char *text )
{
	fprintf(stderr,"*** %s, line %d: %s\n",yyfilename,yyline,text);
}
