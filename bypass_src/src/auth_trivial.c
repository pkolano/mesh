/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#include "auth.h"
#include "network.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <unistd.h>
#include <pwd.h>

static int auth_trivial_assert( int fd, int debug )
{
	struct passwd *p;

	p = getpwuid(getuid());
	if(!p) return 0;

	if(debug) {
		fprintf(stderr,"auth_trivial: sending username '%s'\n",p->pw_name);
	}

	return network_write( fd, p->pw_name, strlen(p->pw_name)+1 );
}

static int auth_trivial_accept( int fd, char **subject, int debug )
{
	network_address addr;
	char user[AUTH_SUBJECT_MAX];
	char host[AUTH_SUBJECT_MAX];
	int port;
	int i;

	for( i=0; i<(AUTH_SUBJECT_MAX-1); i++ ) {
		if(!network_read( fd, &user[i], 1 )) {
			return 0;
		}
		if( user[i]==0 ) break;
	}

	if( i>=(AUTH_SUBJECT_MAX-1) ) {
		return 0;
	}

	if(!network_address_remote( fd, &addr, &port )) return 0;
	if(!network_address_to_name( addr, host )) return 0;

	if( (strlen(host)+strlen(user)) >= AUTH_SUBJECT_MAX ) {
		return 0;
	}

	*subject = (char*) malloc(AUTH_SUBJECT_MAX);
	if(!*subject) return 0;

	sprintf(*subject,"%s@%s",user,host);

	if(debug) {
		fprintf(stderr,"auth_trivial: got username '%s' from host '%s'\n",user,host);
	}

	return 1;
}

int auth_trivial_register()
{
	return auth_register( "trivial", auth_trivial_assert, auth_trivial_accept );
}

