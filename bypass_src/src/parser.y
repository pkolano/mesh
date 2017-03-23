/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

%token CONST
%token STRUCT
%token UNSIGNED
%token IN 
%token OUT
%token STRING
%token ARRAY
%token OPAQUE
%token KILL 
%token ENTRY
%token LIBCALL
%token LIBRARY
%token SYSCALL
%token PLAIN 
%token AGENT_PROLOGUE
%token AGENT_ACTION
%token SHADOW_PROLOGUE
%token SHADOW_ACTION
%token NOT_SUPPORTED
%token FILE_TABLE_NAME
%token LOCAL_NAME
%token REMOTE_NAME
%token OPTIONS
%token SWITCH_CODE
%token EXTERNAL
%token INSTEAD
%token INDIRECT
%token ALSO
%token CODE
%token BIG_CODE
%token LPAREN
%token RPAREN
%token LBRACKET
%token RBRACKET
%token COMMA
%token STAR
%token SEMICOLON
%token SYMBOL

%type <param> opt_param_list param_list param
%type <type> type
%type <control> opt_control control_mode
%type <token> CONST STRUCT UNSIGNED IN  OUT STRING ARRAY OPAQUE KILL ENTRY LIBCALL LIBRARY SYSCALL PLAIN  AGENT_PROLOGUE AGENT_ACTION SHADOW_PROLOGUE SHADOW_ACTION NOT_SUPPORTED FILE_TABLE_NAME LOCAL_NAME REMOTE_NAME OPTIONS SWITCH_CODE EXTERNAL INSTEAD INDIRECT CODE BIG_CODE LPAREN RPAREN LBRACKET RBRACKET COMMA STAR SEMICOLON SYMBOL symbol opt_agent_action opt_shadow_action
%type <number> opt_unsigned opt_const opt_struct
%type <star> star_list
%type <entry> entry
%type <external> external
%type <option> option_list

%{

#define YYERROR_VERBOSE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "parser.h"
#include "parser.tab.h"

static void add_to_list( struct block **list, struct block *item );
static struct star *make_star( int, struct star * );
static struct type *make_type( int, int, int, struct token *, struct star * );
static struct control *make_control( int, int, int, struct token * );
static struct param *make_param( struct control *, struct type *, struct token * );
static struct entry *make_entry( struct token *name, struct entry *next );
static struct option *make_option();
static struct option_rule *make_option_rule( struct token *name, struct option *o, struct option_rule *next );
static struct function *make_function( struct type *, struct token *, struct param *, struct token *, struct token *, struct function * );
static struct block *make_block( int type, struct token *code, struct block * );
static struct external *make_external( struct token *name, struct external *next );

struct option_rule *option_rule_list=0;
struct function *function_list=0;
struct block *block_list=0;

/* keep track of the latest symbol for error reporting */
struct token *latest_symbol=0;

/* kill warnings in bison */
int yyerror( char *str );
int yylex();

%}

%%

item_list
	: item item_list
	| /* nothing */
	;

item
	: option_rule
	| function_rule
	| block_rule
	;

option_rule
	: OPTIONS CODE option_list SEMICOLON
		{ option_rule_list = make_option_rule($2,$3,option_rule_list); }
	;

function_rule
	: type symbol LPAREN opt_param_list RPAREN opt_agent_action opt_shadow_action SEMICOLON
		{ function_list = make_function($1,$2,$4,$6,$7,function_list); }
	;

block_rule
	: AGENT_PROLOGUE BIG_CODE SEMICOLON
		{ add_to_list( &block_list, make_block(BLOCK_TYPE_AGENT,$2,0)); }
	| SHADOW_PROLOGUE BIG_CODE SEMICOLON
		{ add_to_list( &block_list, make_block(BLOCK_TYPE_SHADOW,$2,0)); }
	;

opt_agent_action
	: AGENT_ACTION BIG_CODE
		{ $$ = $2; }
	| /* nothing */
		{ $$ = 0; }
	;

opt_shadow_action
	: SHADOW_ACTION BIG_CODE
		{ $$ = $2; }
	| /* nothing */
		{ $$ = 0; }
	;

option_list
	: KILL option_list
		{ $2->kill = 1; $$ = $2; }
	| ENTRY entry option_list
		{ $3->entrys = $2; $$=$3; }
	| LIBCALL option_list
		{ $2->linkage = OPTION_LINKAGE_LIBCALL; $$=$2; }
	| SYSCALL option_list
		{ $2->linkage = OPTION_LINKAGE_SYSCALL; $$ = $2; }
	| PLAIN option_list
		{ $2->linkage = OPTION_LINKAGE_PLAIN; $$ = $2; }
	| LIBRARY CODE option_list
		{ $3->library = $2; $$=$3; }
	| NOT_SUPPORTED option_list
		{ $2->not_supported = 1; $$ = $2; }
	| FILE_TABLE_NAME CODE option_list
		{ $3->file_table_name = $2; $$ = $3; }
	| REMOTE_NAME CODE option_list
		{ $3->remote_name = $2; $$ = $3; }
	| LOCAL_NAME CODE option_list
		{ $3->local_name = $2; $$ = $3; }
	| SWITCH_CODE BIG_CODE option_list
		{ $3->switch_code = $2; $$ = $3; }
	| EXTERNAL external option_list
		{ $3->external = $2; $$=$3; }
	| INSTEAD function_rule option_list
		{ $3->instead = function_list; $$=$3; 
		  function_list = function_list->next; }
	| INDIRECT CODE option_list
		{ $3->indirect = $2; $$=$3; }
	| ALSO BIG_CODE option_list
		{ $3->also = $2; $$ = $3; }
	| /* nothing */
		{ $$=make_option(); }
	;

entry
	: CODE entry
		{ $$=make_entry($1,$2); }
	| /* nothing */
		{ $$=0; }
	;	

external
	: CODE external
		{ $$=make_external($1,$2); }
	| /* nothing */
		{ $$=0; }
	;	

opt_param_list
	: /* nothing */
		{ $$=0; }
	| param_list
		{ $$=$1; }
	;

param_list
	: param
		{ $$=$1; }
	| param COMMA param_list
		{ $1->next = $3; $$=$1; }
	;

param
	: opt_control type symbol
		{ $$=make_param($1,$2,$3); }
	| LBRACKET param RBRACKET
		{ $2->is_vararg=1; $$=$2; }
	;

type
	: opt_unsigned opt_const opt_struct symbol star_list
		{ $$=make_type($1,$2,$3,$4,$5); }
	;

opt_control
	: /* nothing */
		{ $$=make_control(1,0,CONTROL_TYPE_SINGLE,0); }
	| IN control_mode
		{ $$=$2; $$->in=1; }
	| OUT control_mode
		{ $$=$2; $$->out=1; }
	| IN OUT control_mode 
		{ $$=$3; $$->in=1; $$->out=1; }
	;

control_mode
	: /* nothing */
		{ $$=make_control(0,0,CONTROL_TYPE_SINGLE,0); }
	| ARRAY CODE
		{ $$=make_control(0,0,CONTROL_TYPE_ARRAY,$2); }
	| STRING
		{ $$=make_control(0,0,CONTROL_TYPE_STRING,0); }
	| STRING CODE
		{ $$=make_control(0,0,CONTROL_TYPE_STRING,$2); }
	| OPAQUE CODE
		{ $$=make_control(0,0,CONTROL_TYPE_OPAQUE,$2); }
	| CODE
		{
			yyerror( "the use of a length expression without 'array' or 'string' or 'opaque' is deprecated in bypass 2.0.  You probably mean to use 'opaque \"expr\"'." );
			$$ = make_control(0,0,CONTROL_TYPE_OPAQUE,$1);
		}	
	;

opt_unsigned
	: /* nothing */
		{ $$=0; }
	| UNSIGNED
		{ $$=1; }
	;
opt_const
	: /* nothing */
		{ $$=0; }
	| CONST
		{ $$=1; }
	;

opt_struct
	: /* nothing */
		{ $$=0; }
	| STRUCT
		{ $$=1; }
	;

star_list
	: /* nothing */
		{ $$=0; }
	| opt_const STAR star_list
		{ $$=make_star($1,$3); }
	;

symbol
	: SYMBOL
		{ $$=$1; latest_symbol=$1; }
	;
%%

int yyerror( char *text )
{
	if(latest_symbol) {
		fprintf(stderr,"*** %s, near line %d: ",latest_symbol->file,latest_symbol->line);
	} else {
		fprintf(stderr,"*** near beginning: ");
	}

	fprintf(stderr,"%s\n",text);
	return 0;
}

static void add_to_list( struct block **list, struct block *item )
{
	if(!*list) {
		*list = item;
	} else {
		add_to_list( &((*list)->next), item );
	}
}

static struct star *make_star( int is_const, struct star *next )
{
	struct star *s;
	s = malloc(sizeof(struct star));
	if(!s) {
		fprintf(stderr,"parser: out of memory!");
		exit(-1);
	}

	s->is_const = is_const;
	s->next = next;

	return s;
}

static struct type *make_type( int is_unsigned, int is_const, int is_struct, struct token *name, struct star *stars )
{
	struct type *t;
	t = malloc(sizeof(struct type));
	if(!t) {
		fprintf(stderr,"parser: out of memory!");
		exit(-1);
	}
	t->is_unsigned = is_unsigned;
	t->is_const = is_const;
	t->is_struct = is_struct;
	t->name = name;
	t->stars = stars;

	return t;
}

static struct control *make_control( int in, int out, int type, struct token *code )
{
	struct control *c;
	c = malloc(sizeof(struct control));
	if(!c) {
		fprintf(stderr,"parser: out of memory!");
		exit(-1);
	}
	c->in = in;
	c->out = out;
	c->type = type;
	c->code = code;

	return c;
}

static struct param *make_param( struct control *control, struct type *type, struct token *name )
{
	struct param *p;

	p = malloc(sizeof(struct param));
	if(!p) {
		fprintf(stderr,"parser: out of memory!");
		exit(-1);
	}

	p->control = control;
	p->type = type;
	p->name = name;
	p->next = 0;
	p->is_vararg = 0;

	return p;
}

static struct external *make_external( struct token *name, struct external *next )
{
	struct external *e;
	e = malloc(sizeof(struct external));
	if(!e) {
		fprintf(stderr,"parser: out of memory!\n");
		exit(-1);
	}

	e->name = name;
	e->next = next;

	return e;
}

static struct option *make_option()
{
	struct option *o;

	o = malloc(sizeof(struct option));
	if(!o) {
		fprintf(stderr,"parser: out of memory!");
		exit(-1);
	}

	o->linkage = OPTION_LINKAGE_UNKNOWN;
	o->kill = 0;
	o->not_supported = 0;
	o->library = 0;
	o->remote_name = 0;
	o->local_name = 0;
	o->file_table_name = 0;
	o->entrys = 0;
	o->switch_code = 0;
	o->external = 0;
	o->instead = 0;
	o->indirect = 0;
	o->also = 0;

	return o;
}

static struct entry * make_entry( struct token *name, struct entry *next ) {
	struct entry *c;

	c = malloc(sizeof(struct option));
	if(!c) {
		fprintf(stderr,"parser: out of memory!");
		exit(-1);
	}

	c->name = name;
	c->next = next;

	return c;
}

static struct option_rule *make_option_rule( struct token *name, struct option *options, struct option_rule *next )
{
	struct option_rule *r;
	r = malloc(sizeof(struct option_rule));
	if(!r) {
		fprintf(stderr,"parser: out of memory!");
		exit(-1);
	}

	r->name = name;
	r->options = options;
	r->next = next;

	return r;
}

static struct function *make_function( struct type *type, struct token *name, struct param *params, struct token *agent_action, struct token *shadow_action, struct function *next )
{
	struct function *f;

	f = malloc(sizeof(struct function));
	if(!f) {
		fprintf(stderr,"parser: out of memory!");
		exit(-1);
	}

	f->type = type;
	f->name = name;
	f->params = params;
	f->agent_action = agent_action;
	f->shadow_action = shadow_action;
	f->next = next;
	f->options = make_option();

	return f;
}

static struct block *make_block( int type, struct token *code, struct block *next )
{
	struct block *b;
	b = malloc(sizeof(struct block));
	if(!b) {
		fprintf(stderr,"parser: out of memory!\n");
		exit(-1);
	}

	b->type = type;
	b->code = code;
	b->next = next;

	return b;
}


