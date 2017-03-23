/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#ifndef AUTH_H
#define AUTH_H

#ifdef __cplusplus
extern "C" {
#endif

#define AUTH_SUBJECT_MAX 1024

int auth_assert( int fd, int debug );
int auth_accept( int fd, char **subject, int debug );
int auth_register( char *type, int (*assert)(int,int), int (*accept)(int,char**,int) );
int auth_lookup( char *subject, char *authfile );

int auth_trivial_register();

#ifdef __cplusplus
}
#endif

#endif
