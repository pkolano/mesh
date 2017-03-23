/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/


#include "packet.h"
#include "network.h"
#include "int_sizes.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <netinet/in.h>

#define PACKET_MAX_DEFAULT 1024

struct packet_mem {
       char *data;
       struct packet_mem *next;
};

struct packet {
	int pos;
	int max;
	int error;
	char *data;
	struct packet_mem *mem_list;
};

struct packet * packet_create( int length )
{
	struct packet *p;

	p = malloc(sizeof(struct packet));
	if(!p) return 0;

	if( length<=0 ) length=PACKET_MAX_DEFAULT;

	p->pos = 0;
	p->max = length;
	p->data = malloc(p->max);
	p->mem_list = 0;

	if(!p->data) {
		free(p);
		return 0;
	}

	return p;
}

void packet_delete( struct packet *p )
{
	if(p) {
		struct packet_mem *m, *n;
		m = p->mem_list;

		while(m) {
			n = m->next;
			free(m->data);
			free(m);
			m = n;
		}

		free(p->data);
		free(p);
	}
}

int packet_put( int fd, struct packet *p )
{
	INT32_T length;

	length = htonl(p->pos);

	if(!network_write( fd, (char*) &length, sizeof(length) )) {
		return 0;
	}

	if(!network_write( fd, p->data, p->pos )) {
		return 0;
	}

	return 1;
}

struct packet * packet_get( int fd )
{
	struct packet *p;
	INT32_T length;
	int result;

	result = network_read( fd, (char*) &length, sizeof(length) );
	if(!result) return 0;

	length = ntohl(length);

	p = packet_create(length);
	if(!p) return 0;

	result = network_read( fd, p->data, length );
	if(!result) return 0;

	return p;
}

static int packet_expand( struct packet *p, int newsize )
{
	char *newdata;

	newdata = malloc(newsize);
	if(!newdata) return 0;

	memcpy( newdata, p->data, p->pos );
	free( p->data );

	p->data = newdata;
	p->max = newsize;

	return 1;
}


int packet_write( struct packet *p, char *data, int length )
{
	if( p->max <= (p->pos+length) ) {
		if(!packet_expand(p,(p->pos+length)*2)) {
			return 0;
		}
	}

	memcpy( &p->data[p->pos], data, length );
	p->pos += length;

	return 1;
}

int packet_read( struct packet *p, char *data, int length )
{
	if( p->pos+length > p->max ) {
		errno = EIO;
		return 0;
	}
	memcpy( data, &p->data[p->pos], length );
	p->pos += length;
	return 1;
}

char * packet_alloc( struct packet *p, int bytes )
{
	struct packet_mem *m;

	m = malloc(sizeof(struct packet_mem));
	if(!m) return 0;

	m->data = malloc( bytes );
	if(!m->data) {
		free(m);
		return 0;
	}

	m->next = p->mem_list;
	p->mem_list = m;

	return m->data;
}
