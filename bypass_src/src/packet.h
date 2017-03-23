/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#ifndef PACKET_H
#define PACKET_H

#include <errno.h>

#ifdef __cplusplus
extern "C" {
#endif

struct packet * packet_create( int length );
void            packet_delete( struct packet *p );

int             packet_put( int fd, struct packet *p );
struct packet * packet_get( int fd );

int             packet_write( struct packet *p, char *data, int length );
int             packet_read( struct packet *p, char *data, int length );
char *		packet_alloc( struct packet *p, int bytes );

#ifdef __cplusplus
}
#endif

#endif
