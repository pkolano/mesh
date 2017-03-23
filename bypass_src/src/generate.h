/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#ifndef GENERATE_H
#define GENERATE_H

#include <stdio.h>
#include "parser.h"

/*
Each of these functions generates a piece of the bypass code
on the given stream.  None of the pointed-to functions are
changed.

The abstract syntax tree should be completely parsed and the defaults
filled into the tree before these functions are called.
*/

void generate_switch_prototype( FILE* file, struct function *f );
void generate_sender_prototype( FILE* file, struct function *f );

void generate_switch( FILE* file, struct function *f, int do_static );
void generate_agent_action( FILE* file, struct function *f );
void generate_entry( FILE *file, struct function *f, char *entry );
void generate_sender( FILE *file, struct function *f );
void generate_receiver( FILE *file, struct function *f );
void generate_shadow_action( FILE* file, struct function *f );
void generate_number( FILE *file, struct function *f );
void generate_last_number( FILE *file );
void generate_name( FILE *file, struct function *f );

#endif

