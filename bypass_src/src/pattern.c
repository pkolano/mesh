/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#include "pattern.h"
#include <string.h>
#include <stdlib.h>

int pattern_match( char *pattern, char *text )
{
	char *w;
	int headlen, taillen;

	w = strchr( pattern, PATTERN_WILDCARD );
	if(!w) return !strcmp(pattern,text);

	headlen = w-pattern;
	taillen = strlen(pattern)-headlen-1;

	return !strncmp(pattern,text,headlen) && !strcmp(&pattern[headlen+1],&text[strlen(text)-taillen]);
}

char *pattern_complete( char *pattern, char *text )
{
	char *w, *r;
	int headlen;

	if(!pattern) return 0;

	w = strchr( pattern, PATTERN_WILDCARD );
	if(!w) return pattern;

	headlen = w-pattern;

	r = (char *) malloc(strlen(pattern)+strlen(text));
	if(!r) return 0;

	strncpy(r,pattern,headlen);
	r[headlen]=0;

	strcat(r,text);
	strcat(r,&pattern[headlen+1]);

	return r;
}

int pattern_match_list( char *pattern_list, char *str )
{
	char *work_list;
	char *pattern;
	int success;

	success = 0;
	work_list = strdup(pattern_list);
	pattern = strtok(work_list," ,\t\n");
	while(pattern) {
		if(pattern_match(pattern,str)) {
			success=1;
			break;
		}
		pattern = strtok(0," ,\t\n");
	}
	free(work_list);

	return success;	
}

