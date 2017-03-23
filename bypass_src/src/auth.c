/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#include "auth.h"
#include "network.h"
#include "packet.h"
#include "external.h"
#include "pattern.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

struct auth_ops {
	char *type;
	int (*assert)( int fd, int debug );
	int (*accept)( int fd, char **subject, int debug );
	struct auth_ops *next;
};

static struct auth_ops *list=0;

static struct auth_ops * lookup( char *type )
{
	struct auth_ops *a;

	for(a=list;a;a=a->next) {
		if(!strcmp(a->type,type)) return a;
	}

	return 0;
}

static struct auth_ops * client_negotiate( int fd, int debug )
{
	struct packet *p=0;
	struct auth_ops *a;
	int response;
	int success;

	for( a=list; a; a=a->next ) {

		if(debug) {
			fprintf(stderr,"auth: requesting '%s' authentication\n",a->type);
		}

		p = packet_create(0);
		if(!p) break;

		success = external_string( p, EXTERNAL_OUT, &a->type, 0 );
		if(!success) break;

		success = packet_put( fd, p );
		if(!success) break;

		packet_delete(p);
		p = packet_get(fd);
		if(!p) break;

		success = external( p, EXTERNAL_IN, &response );
		if(!success) break;

		if(response) {
			if( debug ) {
				fprintf(stderr,"auth: peer agrees to '%s'\n",a->type);
			}
			packet_delete(p);
			return a;
		} else {
			if( debug ) {
				fprintf(stderr,"auth: peer refuses '%s'\n",a->type);
			}
		}

		packet_delete(p);
	}

	if(p) packet_delete(p);
	return 0;
}

static struct auth_ops * server_negotiate( int fd, int debug )
{
	struct packet *p;
	struct auth_ops *a;
	char *type;
	int response=0;
	int success;

	while(1) {
		p = packet_get(fd);
		if(!p) break;

		type=0;
		success = external_string( p, EXTERNAL_IN, &type, 0 );
		if(!success) break;

		if(debug) {
			fprintf(stderr,"auth: peer requests '%s' authentication\n",type);
		}

		a = lookup( type );
		if(a) {
			if(debug) {
				fprintf(stderr,"auth: I agree to '%s' \n",type);
			}
			response=1;
		} else {
			if(debug) {
				fprintf(stderr,"auth: I do not agree to '%s' \n",type);
			}
			response=0;
		}

		packet_delete(p);
		p = packet_create(0);
		if(!p) return 0;

		success = external( p, EXTERNAL_OUT, &response );
		if(!success) break;

		success = packet_put( fd, p );
		if(!success) break;

		packet_delete(p);
		p=0;

		if(response) {
			return a;
		}
	}

	if(p) packet_delete(p);
	return 0;
}

extern "C" int auth_assert( int fd, int debug )
{
	struct auth_ops *a;

	a = client_negotiate( fd, debug );
	if(!a) return 0;

	return a->assert(fd,debug);
}

extern "C" int auth_accept( int fd, char **name, int debug )
{
	struct auth_ops *a;

	a = server_negotiate( fd, debug );
	if(!a) return 0;

	return a->accept(fd,name,debug);
}

extern "C" int auth_register( char *type, int (*assert)(int,int), int (*accept)(int,char**,int) )
{
	struct auth_ops *a;

	a = (struct auth_ops *) malloc(sizeof(struct auth_ops));
	if(!a) return 0;

	a->type = type;
	a->assert = assert;
	a->accept = accept;
	a->next = list;
	list = a;

	return 1;
}

extern "C" int auth_lookup( char *subject, char *authfile )
{
	char line[AUTH_SUBJECT_MAX];
	int length;
	FILE *f;

	f = fopen(authfile,"r");
	if(!f) return 0;

	while(fgets( line, AUTH_SUBJECT_MAX, f )) {

		if( line[0]=='#' ) continue;

		length = strlen(line);

		if( length>0 && line[length-1]=='\n' ) {
			line[length-1] = 0;
		}

		if(pattern_match(line,subject)) {
			fclose(f);
			return 1;
		}
	}

	fclose(f);
	return 0;
}

