/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include <stdlib.h>

#include "extract.h"
#include "stringtools.h"

#ifdef __osf__
	#define EXTRACT_LINK_COMMAND "ld -r "
#else
	#define EXTRACT_LINK_COMMAND "ld -r -dn "
#endif

#define BUFFER_SIZE 4096

static int replace_in_file( FILE *file, char *old_name, char *new_name );

int extract_static( struct function *list, char *output_name )
{
	char command[BUFFER_SIZE];
	char libraries[BUFFER_SIZE];

	struct function *f;

	strcpy(command,EXTRACT_LINK_COMMAND);

	libraries[0] = 0;

	for( f=list; f; f=f->next ) {
		if(f->options->linkage==OPTION_LINKAGE_LIBCALL) {
			strcat(command," -u ");
			strcat(command,f->name->text);
			if(!strstr(libraries,f->options->library->text)) {
				strcat(libraries,f->options->library->text);
				strcat(libraries,".a ");
			}
		}
	}

	if(libraries[0]) {
		strcat(command," -o ");
		strcat(command,output_name);
		strcat(command," ");
		strcat(command,libraries);

		fprintf(stderr,"\t%s\n",command);

		return(!system(command));
	} else {
		fprintf(stderr,"\tnothing to extract\n");
		return 1;
	}
}

int extract_rename( struct function *list, char *output_name )
{
	struct function *f;
	struct option *o;
	FILE *file;
	int count;

	file = fopen(output_name,"r+");
	if(!file) {
		fprintf(stderr,"\tnothing to rename\n");
		return 0;
	}

	for( f=list; f; f=f->next ) {
		o = f->options;

		fprintf(stderr,"\t%s\t",f->name->text);

		if(o->linkage==OPTION_LINKAGE_LIBCALL) {
			char *old_name = f->name->text;
			char *new_name = upper_string(f->name->text);
			fprintf(stderr,"%s\t%s -> %s\t",o->library->text,old_name,new_name);
			count = replace_in_file(file,old_name,new_name);
			fprintf(stderr,"(%d instances)",count);
		}

		fprintf(stderr,"\n");
	}

	fclose(file);

	return 1;
}

static int replace_in_file( FILE *file, char *old_name, char *new_name )
{
	int replace_count=0;
	int matches=0;
	int length;
	char data;

	length = strlen(old_name)+1;

	fseek(file,0,SEEK_SET);

	while(1) {
		data = fgetc(file);
		if(feof(file)) break;
		if(ferror(file)) break;

		if(data==old_name[matches]) {
			matches++;
			if(matches==length) {
				fseek(file,-length,SEEK_CUR);
				fwrite(new_name,length,1,file);

				/* This seek kills performance, but stdio
				   seems to get confused otherwise... */

				fseek(file,0,SEEK_SET);
				matches=0;
				replace_count++;
			}
		} else {
			matches=0;
		}
	}

	return replace_count;
}



