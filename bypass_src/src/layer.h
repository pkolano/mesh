/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#ifndef LAYER_H
#define LAYER_H

#ifdef __cplusplus
extern "C" {
#endif

// PZK 8/7/07: include for intptr_t type
#include <stdint.h>

/*
These functions are provided by the layer object
for tracking the state of the process and its layers.
*/

// PZK 11/3/11: changed name to const to avoid warnings
int   layer_register( const char *library_name, int is_agent);
// PZK 11/3/11: changed names to const to avoid warnings
// PZK 8/7/07: changed int to intptr_t for 64-bit compatibility
void* layer_lookup( const char *name, const char *standard_name, intptr_t key );
int   layer_is_agent();
void  layer_descend();
void  layer_ascend();
void  layer_top();
void  layer_bottom();

void  layer_fatal( char *str, ... );
void  layer_dump();
void  layer_debug( char *str );

struct layer_entry * layer_get();
void                 layer_set( struct layer_entry *layer );

/*
These functions are not provided by the layer object,
but must be defined elsewhere in the program.
They provide the threading tools, depending on whether
the user really wants thread-safe code.
*/

void layer_pthread_mutex_lock();
void layer_pthread_mutex_unlock();
// PZK 8/7/07: changed int to intptr_t for 64-bit compatibility
intptr_t layer_pthread_self();

#ifdef __cplusplus
}
#endif

#endif
