/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#ifndef STRINGTOOLS_H
#define STRINGTOOLS_H

#include "parser.h"

/*
N.B. Each of these functions malloc()s new data.
it is up to the caller to free() that data.
*/

/*
The constant string size to allocate.  
The arg* and param* functions allocate multiples of this constant.
*/

#define STRING_BUFFER_SIZE 256

/* Add the Bypass library path to this name */
char * complete_filename( char *name );

/* Return this filename, minus a trailing .  */
char * remove_suffix( char *filename );

/* Return an uppercase version of this string */
char * upper_string( char *lower );

/* Return a string representation of this type object */
char * type_string( struct type *t );

/* Same as above, but ignore any "const" */
char * type_string_noconst( struct type *t );

/* Same as above, but dereference one pointer level */
char * type_string_deref( struct type *t );

/* Return a string representation of a pointer to this function type */
char * ftype_string( struct function *t );

/* Return a string listing these parameters as arguments */
char * arg_string( struct param *p );

/* Same as above, but ignore any "const" */
char * arg_string_noconst( struct param *p );

/* Return a string listing these parameters */
char * param_string( struct param *p );

/* Same as above, but ignore any "const" */
char * param_string_noconst( struct param *p );

/* Return true if this is a plain void type (not even void*) */
int is_void( struct type *t );

#endif
