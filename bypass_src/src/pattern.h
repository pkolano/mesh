/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#ifndef PATTERN_H
#define PATTERN_H

#ifdef __cplusplus
extern "C" {
#endif

#define PATTERN_WILDCARD '*'

int pattern_match( char *pattern, char *text );
int pattern_match_list( char *pattern_list, char *text );
char *pattern_complete( char *pattern, char *text );

#ifdef __cplusplus
}
#endif

#endif
