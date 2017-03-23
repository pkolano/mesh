/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include "packet.h"
#include "external.h"
#include "external_unix.h"

int external( struct packet *p, int dir, struct stat *x )
{
	if( dir==EXTERNAL_IN ) memset( x, 0, sizeof(*x) );

	return
		external( p, dir, &x->st_dev ) &&
		external( p, dir, &x->st_ino ) &&
		external( p, dir, &x->st_mode ) &&
		external( p, dir, &x->st_nlink ) &&
		external( p, dir, &x->st_uid ) &&
		external( p, dir, &x->st_gid ) &&
		external( p, dir, &x->st_rdev ) &&
		external( p, dir, &x->st_size) &&
		external( p, dir, &x->st_atime ) &&
		external( p, dir, &x->st_mtime ) &&
		external( p, dir, &x->st_ctime ) &&
		external( p, dir, &x->st_blksize ) &&
		external( p, dir, &x->st_blocks )
		;
}

int external( struct packet *p, int dir, struct statfs *x )
{
	if( dir==EXTERNAL_IN ) memset( x, 0, sizeof(*x) );

	return
		external( p, dir, &x->f_bsize ) &&
		external( p, dir, &x->f_blocks ) &&
		external( p, dir, &x->f_bfree ) &&
		external( p, dir, &x->f_files ) &&
		external( p, dir, &x->f_ffree ) &&
		#if defined(sun) || defined(sgi)
			external( p, dir, &x->f_bfree )
		#else
			external( p, dir, &x->f_bavail )
		#endif
		;
}

int external( struct packet *p, int dir, struct rusage *x )
{
	if( dir==EXTERNAL_IN ) memset( x, 0, sizeof(*x) );

	return
		external( p, dir, &x->ru_utime ) &&
		external( p, dir, &x->ru_stime ) &&
		external( p, dir, &x->ru_maxrss ) &&
		external( p, dir, &x->ru_ixrss ) &&
		external( p, dir, &x->ru_idrss ) &&
		external( p, dir, &x->ru_isrss ) &&
		external( p, dir, &x->ru_minflt ) &&
		external( p, dir, &x->ru_majflt ) &&
		external( p, dir, &x->ru_nswap ) &&
		external( p, dir, &x->ru_inblock ) &&
		external( p, dir, &x->ru_oublock ) &&
		external( p, dir, &x->ru_msgsnd ) &&
		external( p, dir, &x->ru_msgrcv ) &&
		external( p, dir, &x->ru_msgrcv ) &&
		external( p, dir, &x->ru_nsignals ) &&
		external( p, dir, &x->ru_nvcsw ) &&
		external( p, dir, &x->ru_nivcsw )
		;
}

int external( struct packet *p, int dir, struct timezone *x )
{
	if( dir==EXTERNAL_IN ) memset( x, 0, sizeof(*x) );

	return
        	external( p, dir, &x->tz_minuteswest ) &&
        	external( p, dir, &x->tz_dsttime )
		;
}

int external( struct packet *p, int dir, struct timeval *x )
{
	if( dir==EXTERNAL_IN ) memset( x, 0, sizeof(*x) );

	return
        	external( p, dir, &x->tv_sec ) &&
        	external( p, dir, &x->tv_usec )
        	;
} 

int external( struct packet *p, int dir, struct utimbuf *x )
{
	if( dir==EXTERNAL_IN ) memset( x, 0, sizeof(*x) );

	return
        	external( p, dir, &x->actime ) &&
        	external( p, dir, &x->modtime )
        	;
}
int  external( struct packet *p, int dir, struct rlimit *x )
{
	if( dir==EXTERNAL_IN ) memset( x, 0, sizeof(*x) );

	return
        	external( p, dir, &x->rlim_cur ) &&
        	external( p, dir, &x->rlim_max )
        	;
}

int external( struct packet *p, int dir, struct utsname *x )
{
	int result=1;
	char *temp;

	if( dir==EXTERNAL_IN ) memset( x, 0, sizeof(*x) );

	temp = x->sysname;
	result &= external_string( p, dir, &temp, SYS_NMLN );

	temp = x->nodename;
	result &= external_string( p, dir, &temp, SYS_NMLN );

	temp = x->release;
	result &= external_string( p, dir, &temp, SYS_NMLN );

	temp = x->version;
	result &= external_string( p, dir, &temp, SYS_NMLN );

	temp = x->machine;
	result &= external_string( p, dir, &temp, SYS_NMLN );

	return result;
}

int external( struct packet *p, int dir, struct dirent *x )
{
	int result;
	int offset=0;
	char *temp = x->d_name;

	if( dir==EXTERNAL_IN ) memset( x, 0, sizeof(*x) );

	result =
		external( p, dir, &x->d_ino ) &&
		#if defined(__osf__) || defined(hpux)
			external( p, dir, &offset ) &&
		#else
			external( p, dir, &x->d_off ) &&
		#endif
		external( p, dir, &x->d_reclen ) &&
		#if defined(MAXNAMLEN)
			external_string( p, dir, &temp, MAXNAMLEN );
		#elif defined(NAME_MAX)
			external_string( p, dir, &temp, NAME_MAX );
		#else
			#error Need either MAXNAMLEN or NAME_MAX
		#endif


	#ifdef __osf__
		if(dir==EXTERNAL_IN && result) {
			x->d_namlen = strlen(x->d_name);
		}
	#endif

	return result;
}

int external( struct packet *p, int dir, struct flock *x )
{
	if( dir==EXTERNAL_IN ) memset( x, 0, sizeof(*x) );

	return
		external( p, dir, &x->l_type ) &&
		external( p, dir, &x->l_whence ) &&
		external( p, dir, &x->l_start ) &&
		external( p, dir, &x->l_len ) &&
		external( p, dir, &x->l_pid );
}

int external( struct packet *p, int dir, struct pollfd *x )
{
	if( dir==EXTERNAL_IN ) memset( x, 0, sizeof(*x) );

	return
		external( p, dir, &x->fd ) &&
		external_poll_map( p, dir, &x->events ) &&
		external_poll_map( p, dir, &x->revents );
}

/*
A DIR * is an opaque structure, so don't decode it
Just send it as an integer.
*/

int external( struct packet *p, int dir, DIR **x )
{
	return external_int(p,dir,(char*)x,sizeof(*x),1);
}

struct integer_map {
	int internal;
	int external;
    // PZK 1/3/12: changed name to const to avoid warnings
	const char *name;
};

static int external_special_bitmap( struct packet *p, int dir, int *x, struct integer_map *m )
{
	int i;
	long r;

	if( dir==EXTERNAL_OUT ) {
		r = 0;
		for( i=0; m[i].name; i++ ) {
			if( m[i].internal & *x ) {
				r |= m[i].external;
			}
		}
	}

	if(!external( p, dir, &r )) return 0;

	if( dir==EXTERNAL_IN ) {
		*x = 0;
		for( i=0; m[i].name; i++ ) {
			if( m[i].external & r ) {
				*x |= m[i].internal;
			}
		}
	}
	return 1;
}

static int external_special_int( struct packet *p, int dir, int *x, struct integer_map *m )
{
	int i;
	long r;

	if( dir==EXTERNAL_OUT ) {
		r = 0;
		for( i=0; m[i].name; i++ ) {
			if( m[i].internal == *x ) {
				r = m[i].external;
				break;
			}
		}
	}

	if(!external( p, dir, &r )) return 0;

	if( dir==EXTERNAL_IN ) {
		*x = 0;
		for( i=0; m[i].name; i++ ) {
			if( m[i].external == r ) {
				*x = m[i].internal;
				break;
			}
		}
	}

	return 1;
}

#include "open_map.c"

int external_open_map( struct packet *p, int dir, int *x )
{
	return external_special_bitmap( p, dir, x, open_map );
}

#include "fcntl_map.c"

int external_fcntl_map( struct packet *p, int dir, int *x )
{
	return external_special_int( p, dir, x, fcntl_map );
}

#include "errno_map.c"

int external_errno_map( struct packet *p, int dir, int *x )
{
	return external_special_int( p, dir, x, errno_map );
}

#include "signal_map.c"

int external_signal_map( struct packet *p, int dir, int *x )
{
	return external_special_int( p, dir, x, signal_map );
}

#include "poll_map.c"

int external_poll_map( struct packet *p, int dir, short *x )
{
	int temp, result;
	temp = (int) *x;
	result = external_special_bitmap( p, dir, &temp, poll_map );
	*x = (short) temp;
	return result;
}

