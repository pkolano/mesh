/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#ifndef EXTERNAL_UNIX_H
#define EXTERNAL_UNIX_H

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/resource.h>
#include <sys/utsname.h>
#include <sys/time.h>
#include <sys/poll.h>

#if defined(linux) || defined(hpux)
	#include <sys/vfs.h>
#elif defined(__osf__)
	#include <sys/mount.h>
#else
	#include <sys/statfs.h>
#endif

#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <utime.h>
#include <dirent.h>

int external( struct packet *p, int flags, struct stat *x );
int external( struct packet *p, int flags, struct statfs *x );
int external( struct packet *p, int flags, struct rusage *x );
int external( struct packet *p, int flags, struct timezone *x );
int external( struct packet *p, int flags, struct timeval *x );
int external( struct packet *p, int flags, struct utimbuf *x );
int external( struct packet *p, int flags, struct rlimit *x );
int external( struct packet *p, int flags, struct utsname *x );
int external( struct packet *p, int flags, struct dirent *x );
int external( struct packet *p, int flags, struct flock *x );
int external( struct packet *p, int flags, struct pollfd *x );
int external( struct packet *p, int flags, DIR **x );

int external_open_map( struct packet *p, int flags, int *x );
int external_fcntl_map( struct packet *p, int flags, int *x );
int external_signal_map( struct packet *p, int flags, int *x );
int external_errno_map( struct packet *p, int flags, int *x );
int external_poll_map( struct packet *p, int flags, short *x );

#endif
