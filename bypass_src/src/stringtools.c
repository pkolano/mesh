/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "stringtools.h"

char * complete_filename( char *name )
{
	char *s,*d;

	s = malloc(STRING_BUFFER_SIZE);
	if(!s) return 0;

	d = getenv("BYPASS_LIBRARY_DIR");
	if(!d) {
		fprintf(stderr,"bypass: installation problem: BYPASS_LIBRARY_DIR is not defined.\n");
		exit(-1);
	}

	sprintf(s,"%s/%s",d,name);

	return s;
}


char * remove_suffix( char *filename )
{
	char *lastdot,*s;
	int size;

	lastdot = strrchr(filename,'.');
	if(!lastdot) return filename;

	size = lastdot-filename;
	if(size<2) return filename;

	s = malloc(size+1);
	if(!s) return 0;

	strncpy(s,filename,size);
	s[size] = 0;

	return s;
}

int replace_string( char *buffer, int size, char *old_string, char *new_string )
{
	int replace_count = 0;
	int matches=0;
	int length = strlen(old_string)+1;
	int i;

	for( i=0; i<size; i++ ) {
		if(buffer[i]==old_string[matches]) {
			matches++;
			if(matches==length) {
				strcpy(&buffer[i-length-1],new_string);
				matches = 0;
				replace_count++;
			}
		} else {
			matches = 0;
		}
	}

	return replace_count;
}

char * upper_string( char *in )
{
	char *buffer = malloc(STRING_BUFFER_SIZE);
	char *out;

	for(out=buffer;*in;in++,out++)
		*out = toupper((int)*in);

	*out = 0;

	return buffer;
}

char * type_string( struct type *t )
{
	struct star *s;
	char *buffer = malloc(STRING_BUFFER_SIZE);

	sprintf(buffer,"%s%s%s%s",
		t->is_unsigned ? "unsigned " : "",
		t->is_const ? "const " : "",
		t->is_struct ? "struct " : "",
		t->name->text);

	for( s=t->stars; s; s=s->next ) {
		if(s->is_const) strcat(buffer,"const ");
		strcat(buffer,"*");
	}

	return buffer;
}


char * ftype_string( struct function *f )
{
	char *buffer = malloc(STRING_BUFFER_SIZE*10);

	sprintf(buffer,"%s (*)(%s)",
		type_string(f->type),
		param_string(f->params));

	return buffer;
}

char * type_string_noconst( struct type *t )
{
	struct star *s;

	char *buffer = malloc(STRING_BUFFER_SIZE);

	sprintf(buffer,"%s%s%s",
		t->is_unsigned ? "unsigned " : "",
		t->is_struct ? "struct " : "",
		t->name->text);

	for( s=t->stars; s; s=s->next ) {
		strcat(buffer,"*");
	}

	return buffer;
}

char * type_string_deref( struct type *t )
{
	struct star *s;
	char *buffer = malloc(STRING_BUFFER_SIZE);

	sprintf(buffer,"%s%s%s",
		t->is_unsigned ? "unsigned " : "",
		t->is_struct ? "struct " : "",
		t->name->text);

	s=t->stars;
	if(s) s=s->next;

	for( ; s; s=s->next ) {
		if(s->is_const) strcat(buffer,"const ");
		strcat(buffer,"*");
	}

	return buffer;
}

char * arg_string( struct param *p )
{
	char *buffer = malloc(STRING_BUFFER_SIZE*10);

	for( buffer[0]=0; p!=0; p=p->next) {
		strcat(buffer,p->name->text);
		if(p->next) strcat(buffer,", ");
	}

	return buffer;
}

char * arg_string_noconst( struct param *p )
{
	char *buffer = malloc(STRING_BUFFER_SIZE*10);

	for( buffer[0]=0; p!=0; p=p->next) {
		/* If the arg is usually const, cast it away */
		if( p->type->is_const ) {
			strcat(buffer,"(");
			strcat(buffer,type_string_noconst(p->type));
			strcat(buffer,")");
		}
		strcat(buffer,p->name->text);
		if(p->next) strcat(buffer,", ");
	}

	return buffer;
}

char *param_string( struct param *p )
{
	char *buffer = malloc(STRING_BUFFER_SIZE*10);

	if(!p) {
		strcpy(buffer,"void");
		return buffer;
	}

	for( buffer[0]=0; p!=0; p=p->next) {
		strcat(buffer,type_string(p->type));
		strcat(buffer," ");
		strcat(buffer,p->name->text);
		if(p->next) {
			strcat(buffer,", ");
			if(p->next->is_vararg) {
				strcat(buffer,"...");
				break;
			}
		}
	}

	return buffer;
}

char *param_string_noconst( struct param *p )
{
	char *buffer = malloc(STRING_BUFFER_SIZE*10);

	if(!p) {
		strcpy(buffer,"void");
		return buffer;
	}

	for( buffer[0]=0; p!=0; p=p->next) {
		strcat(buffer,type_string_noconst(p->type));
		strcat(buffer," ");
		strcat(buffer,p->name->text);
		if(p->next) {
			strcat(buffer,", ");
			if(p->next->is_vararg) {
				strcat(buffer,"...");
				break;
			}
		}
	}

	return buffer;
}

int is_void( struct type *t )
{
	return !strcmp(t->name->text,"void") && (t->stars==0);
}
