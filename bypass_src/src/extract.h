/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#ifndef EXTRACT_H
#define EXTRACT_H

#include "parser.h"

/*
Scan through the list of items.  Extract out any references to
static libraries, and put the resulting objects in a file
named "output_name"
*/

int extract_static( struct function *list, char *output_name );

/*
Consider the list of items, and the output file that was
already created by extract_static.  If any items in the output
file need renaming, do it now.
*/

int extract_rename( struct function *list, char *output_name );

#endif
