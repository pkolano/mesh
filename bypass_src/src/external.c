/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#include "packet.h"
#include "external.h"

#include <netinet/in.h>
#include <string.h>
#include <errno.h>

#define EXTERNAL_INT_SIZE 8

static int needs_reverse()
{
	return ntohl(1)!=1;
}

int external_int( struct packet *pkt, int dir, char *p, int bytes, int unsgned )
{
	char data[EXTERNAL_INT_SIZE];
	char fill;
	int offset;
	int convert_errno;
	int i;

	offset = EXTERNAL_INT_SIZE-bytes;

	if(dir==EXTERNAL_IN) {
		convert_errno = ERANGE;
	} else {
		convert_errno = EDOM;
	}
 
	if( offset<0 ) {
		errno = convert_errno;
		return 0;
	}

	if( dir==EXTERNAL_IN ) {
		if(!packet_read( pkt, data, EXTERNAL_INT_SIZE )) return 0;

		if( data[offset]&0x80 ) {
			if( unsgned ) {
				errno = convert_errno;
				return 0;
			}
			fill = 0xff;
		} else {
			fill = 0x00;
		}

		for( i=0; i<offset; i++ ) {
			if( data[i]!=fill ) {
				errno = convert_errno;
				return 0;
			}
		}

		if( needs_reverse() ) {
			for( i=offset; i<EXTERNAL_INT_SIZE; i++ ) {
				p[bytes-1-(i-offset)] = data[i];
			}
		} else {
			for( i=offset; i<EXTERNAL_INT_SIZE; i++ ) {
				p[i-offset] = data[i];
			}
		}
	} else {
		if( needs_reverse() ) {
			for( i=offset; i<EXTERNAL_INT_SIZE; i++ ) {
				data[i] = p[bytes-1-(i-offset)];
			}
		} else {
			for( i=offset; i<EXTERNAL_INT_SIZE; i++ ) {
				data[i] = p[i-offset];
			}
		}

		if( data[offset]&0x80 ) {
			fill = 0xff;
		} else {
			fill = 0x00;
		}

		for( i=0; i<offset; i++ ) {
       			data[i]=fill;
		}

		if(!packet_write( pkt, data, EXTERNAL_INT_SIZE )) return 0;
	}

	return 1;

}

int external( struct packet *pkt, int dir, short *x )
{
	return external_int( pkt, dir, (char*)x, sizeof(*x), 0 );
}

int external( struct packet *pkt, int dir, int *x )
{
	return external_int( pkt, dir, (char*)x, sizeof(*x), 0 );
}

int external( struct packet *pkt, int dir, long *x )
{
	return external_int( pkt, dir, (char*)x, sizeof(*x), 0 );
}

int external( struct packet *pkt, int dir, long long *x )
{
        return external_int( pkt, dir, (char*)x, sizeof(*x), 0 );
}

int external( struct packet *pkt, int dir, unsigned short *x )
{
	return external_int( pkt, dir, (char*)x, sizeof(*x), 1 );
}

int external( struct packet *pkt, int dir, unsigned int *x )
{
	return external_int( pkt, dir, (char*)x, sizeof(*x), 1 );
}

int external( struct packet *pkt, int dir, unsigned long *x )
{
	return external_int( pkt, dir, (char*)x, sizeof(*x), 1 );
}

int external( struct packet *pkt, int dir, unsigned long long *x )
{
        return external_int( pkt, dir, (char*)x, sizeof(*x), 1 );
}

/* When sending a void, just send the bit pattern. */

int external( struct packet *pkt, int dir, void **x )
{
	return external_int( pkt, dir, (char*)x, sizeof(*x), 1 );
}

int external( struct packet *pkt, int dir, double *x )
{
	/* Everyone is using IEEE format now. */
	/* However, we could do better... */

	if( dir==EXTERNAL_IN ) {
		return packet_read( pkt, (char*)x, sizeof(*x) );
	} else {
		return packet_write( pkt, (char*)x, sizeof(*x) );
	}
}

int external( struct packet *pkt, int dir, char *x, int length )
{
	if( dir==EXTERNAL_IN ) {
		return packet_read( pkt, x, length );
	} else {
		return packet_write( pkt, x, length );
	}
}

int external_opaque( struct packet *p, int dir, char **x, int length )
{
	int actual;
	int convert_errno;

       	if( dir==EXTERNAL_IN ) {
		convert_errno = ERANGE;
	} else {
		actual = length;
		convert_errno = EDOM;
	}

	if(!external(p,dir,&actual)) return 0;

	if( dir==EXTERNAL_IN && !*x) {
		*x = packet_alloc( p, actual );
		if(!*x) return 0;
	} else {	
		if(actual!=length) {
			errno = EIO;
			return 0;
		}
	}

	return external( p, dir, *x, actual );
}

int external_string( struct packet *p, int dir, char **x, int maxlength )
{
	int length;
	int convert_errno;

       	if( dir==EXTERNAL_IN ) {
		convert_errno = ERANGE;
	} else {
		length=strlen(*x)+1;
		convert_errno = EDOM;
	}

	if(!external(p,dir,&length)) return 0;

	if( length<0 ) {
		errno = EIO;
		return 0;
	}

	if( dir==EXTERNAL_IN && !*x) {
		if( !*x ) {
			*x = packet_alloc( p, length );
			if(!*x) return 0;
		} else {
			if( length>maxlength ) {
				errno = convert_errno;
				return 0;
			}
		}
	}
	
	return external( p, dir, *x, length );
}

