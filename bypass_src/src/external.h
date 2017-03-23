/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#ifndef EXTERNAL_H
#define EXTERNAL_H

#define EXTERNAL_IN	0
#define EXTERNAL_OUT	1

int external_int( struct packet *pkt, int dir, char *p, int bytes, int unsgned );

int external( struct packet *p, int dir, short *x );
int external( struct packet *p, int dir, int *x );
int external( struct packet *p, int dir, long *x );
int external( struct packet *p, int dir, long long *x );

int external( struct packet *p, int dir, unsigned short *x );
int external( struct packet *p, int dir, unsigned int *x );
int external( struct packet *p, int dir, unsigned long *x );
int external( struct packet *p, int dir, unsigned long long *x );
int external( struct packet *p, int dir, void **x );

int external( struct packet *p, int dir, double *x );
int external( struct packet *p, int dir, char *data, int length );

int external_opaque( struct packet *p, int dir, char **x, int length );
int external_string( struct packet *p, int dir, char **x, int length );

template <class T>
int external_array( struct packet *p, int dir, T **x, int items )
{
	int i;

	if(!external(p,dir,&items)) return 0;
	if(items<=0) return 0;

	if( dir==EXTERNAL_IN && !*x ) {
		*x = (T*) packet_alloc( p, sizeof(*x)*items );
		if(!*x) return 0;
	}

	for( i=0; i<items; i++ ) {
		if(!external(p,dir,&(*x)[i])) return 0;
	}

	return 1;
}

template <class T>
int external( struct packet *p, int dir, T **x )
{
	if( !*x ) {
		*x = (T*) packet_alloc(p,sizeof(T));
		if(!*x) return 0;
	}

	return external(p,dir,*x);
}

#endif
