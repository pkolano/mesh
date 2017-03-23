/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#ifndef PARSER_H
#define PARSER_H

#include <stdio.h>

/*
If a token is larger than this many bytes, an error is flagged, because the user probably used #include instead of @include.
*/

#define MAX_TOKEN_SIZE 32768

/*
A simple scanner token, containing an integer type and a pointer
to the raw text, along with pointers to the source document. 
*/ 

struct token {
	int type;
	char *text;
	int line;
	char *file;
};

struct star {
	int is_const;
	struct star *next;
};

/*
A type object represents the subset of C++ types available to
the code generator.  Any number of *s may be specified, but
the generator is really only wise to zero or one. 
*/

struct type {
	int is_unsigned;
	int is_const;
	int is_struct;
	struct token *name;
	struct star *stars;
};

/*
A control object specifies the dataflow in a pointer parameter.
When "in" is set, data is to be copied into a procedure.
When "out" is set, data is to be copied out of the procedure.
Both may be set.
*/

#define CONTROL_TYPE_SINGLE 0
#define CONTROL_TYPE_STRING 1
#define CONTROL_TYPE_ARRAY 2
#define CONTROL_TYPE_OPAQUE 3

struct control {
	int in,out;
	int type;
	struct token *code;
};

/*
A param object represents one formal parameter to a function.
When is_vararg is set, it is implied that this and all further
params are implicitly extracted through the vararg mechanism.
*/

struct param {
	struct control *control;
	struct type *type;
	struct token *name;
	struct param *next;
	int is_vararg;
};

/*
A entry lists the set of functions that are to be generated in addition to the main switch.
*/

struct entry {
       struct token *name;
       struct entry *next;
};

/*
An external gives a list of type names to be used when serializing arguments.
*/

struct external {
	struct token *name;
	struct external *next;
};

/*
An option object contains all the special data needed for generating the many variations on stubs.
*/

struct option {
	int	linkage;
	int	kill;
	int	not_supported;
	struct token *library;
	struct token *remote_name;
	struct token *local_name;
	struct token *file_table_name;
	struct token *switch_code;
	struct external *external;
	struct entry *entrys;
	struct function *instead;
	struct token *indirect;
	struct token *also;
};

#define OPTION_LINKAGE_UNKNOWN 0
#define OPTION_LINKAGE_SYSCALL 1
#define OPTION_LINKAGE_LIBCALL 2
#define OPTION_LINKAGE_PLAIN 3

/*
An option rule specifies the standard options for a particular procedure name, without specifying the necessary code.
*/

struct option_rule {
	struct token *name;
	struct option *options;
	struct option_rule *next;
};

/*
A function represents a piece of code to be automatically generated.  The option field of this structure is not bound until all function and option entries have been read.
*/

struct function {
	struct type *type;
	struct token *name;
	struct param *params;
	struct token *agent_action;
	struct token *shadow_action;
	struct option *options;
	struct function *next;
};

/*
A block is a simply a large chunk of code.
A block must be marked as part of the agent or part of the shadow.
*/

struct block {
	int type;
	struct token *code;
	struct block *next;
};

#define BLOCK_TYPE_SHADOW 0
#define BLOCK_TYPE_AGENT 1

/*
yystype is the data type passed around by the parser and the scanner.
It is a union of all the types used in the syntax tree.
*/

union yystype {
	int number;
	struct token *token;
	struct star *star;
	struct type *type;
	struct control *control;
	struct param *param;
	struct entry *entry;
	struct external *external;
	struct option *option;
	struct function *function;
	struct block *block;
};

#define YYSTYPE union yystype

extern int yyparse();
extern FILE *yyin;

extern struct option_rule * option_rule_list;
extern struct function * function_list;
extern struct block * block_list;

#endif
