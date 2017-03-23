/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#ifndef HASHTABLE_H
#define HASHTABLE_H

// PZK 8/7/07: include for intptr_t type
#include <stdint.h>

struct hashtable * hashtable_create( int buckets );
// PZK 8/7/07: changed int to intptr_t for 64-bit compatibility
void * hashtable_lookup( struct hashtable *h, intptr_t key );
int hashtable_insert( struct hashtable *h, intptr_t key, void *value );

#endif
