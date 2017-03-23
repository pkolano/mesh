/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

/*
Main program for the bypass code generator.

This program looks at the command line options, parses the
input, uses the extract_* functions to fill in any missing
defaults, and then generates code using the generate_* functions.
*/

#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>

#include "parser.h"
#include "generate.h"
#include "extract.h"
#include "stringtools.h"
#include "pattern.h"

static char version[] = "release 2.5.3 7-August-2002, http://www.cs.wisc.edu/condor/bypass";

/* Buffer size to use when copying data or creating a filename */

#define COPY_BUFFER_SIZE 4096
#define FILENAME_BUFFER_SIZE 256
#define PREPROCESS_COMMAND "gcc -E -x c-header -P %s"

/* Global variables representing the command line options */

static int make_shadow = 0;
static int extract_is_static = 0;
static char *input_filename = 0;

/* Exit the program, displaying and error and the various options. */

void quit_on_error( char *name, char *error )
{
	fprintf(stderr,"%s: %s\n",name,error);
	fprintf(stderr,"Use: %s [options] <input-file>\n",name);
	fprintf(stderr,"Options:\n");
	fprintf(stderr,"\t-agent    Build code for an agent.\n");
	fprintf(stderr,"\t-shadow   Build code for a shadow.\n");
	fprintf(stderr,"\t-static   Do static extraction.\n");
	fprintf(stderr,"\t-dynamic  Do dynamic extraction.\n");
	fprintf(stderr,"\t-version  Show version information.\n");
	exit(-1);
}

/* Go through the options and fill in the global variables accordingly */

void process_options( int argc, char *argv[] )
{
	int i;

	for(i=1;i<argc;i++) {
		if(!strcmp(argv[i],"-agent")) {
			/* */
		} else if(!strcmp(argv[i],"-shadow")) {
			make_shadow = 1;
		} else if(!strcmp(argv[i],"-static")) {
			extract_is_static = 1;
		} else if(!strcmp(argv[i],"-dynamic")) {
			extract_is_static = 0;
		} else if(!strcmp(argv[i],"-version")) {
			quit_on_error(argv[0],version);
		} else {
			if(i!=(argc-1)) {
				quit_on_error(argv[0],"Unknown option.");
			} else {
				input_filename = argv[i];
			}
		}
	}

	if(!input_filename) {
		quit_on_error(argv[0],"You must supply an input file.\n");
	}
}

FILE * open_and_preprocess( char *name )
{
	char command[FILENAME_BUFFER_SIZE];
	FILE *result;

	sprintf(command,PREPROCESS_COMMAND,name);
	result = popen( command, "r" );

	if(!result) {
		fprintf(stderr,"bypass: Unable to execute \"%s\"!\n",command);
		exit(-1);
	}

	return result;
}


FILE * open_or_quit( char *base, char *ext, char *mode )
{
	FILE *result;
	char name[FILENAME_BUFFER_SIZE];

	sprintf(name,"%s%s",base,ext);

	result = fopen(name,mode);
	if(!result) {
		fprintf(stderr,"bypass: Unable to open %s\n",name);
		exit(-1);
	}	

	return result;
}


void copy_stream( FILE *source, FILE *target )
{
	char buffer[COPY_BUFFER_SIZE];
	int length;

	do {
		length = fread(buffer,1,COPY_BUFFER_SIZE,source);
		fwrite(buffer,1,length,target);
	} while(length==COPY_BUFFER_SIZE);
}

void copy_file( char *name, FILE *target )
{
	FILE *source;

	source = open_or_quit( complete_filename(name), "", "r" );
	copy_stream(source,target);
}

/* If any field in a is unset, replace with a field in b */

static void option_combine( struct option *a, struct option *b )
{
	if(!a->linkage) a->linkage = b->linkage;
	if(!a->kill) a->kill = b->kill;
	if(!a->not_supported) a->not_supported = b->not_supported;
	if(!a->library) a->library = b->library;
	if(!a->remote_name) a->remote_name = b->remote_name;
	if(!a->local_name) a->local_name = b->local_name;
	if(!a->file_table_name) a->file_table_name = b->file_table_name;
	if(!a->switch_code) a->switch_code = b->switch_code;
	if(!a->external) a->external = b->external;
	if(!a->entrys) a->entrys = b->entrys;
	if(!a->instead) a->instead = b->instead;
	if(!a->indirect) a->indirect = b->indirect;
	if(!a->also) a->also = b->also;
}

void lookup_options( struct function *f )
{
	struct option_rule *o;

	for( o=option_rule_list; o; o=o->next ) {

		if( pattern_match( o->name->text, f->name->text ) ) {

			/* If it matches, copy the options */
			option_combine( f->options, o->options );

			/* If this has an "instead" entry, look up those, too */
			if( o->options->instead ) {
				lookup_options( o->options->instead );
			}
		}
	}
}

int main( int argc, char *argv[] )
{
	FILE   *agent=0, *shadow=0, *global=0;
	char   *filename_stem;

	struct function *f;
	struct block *b;

	int call_count = 0;

	process_options(argc,argv);

	/* First read all the standard options */

	yyin = open_and_preprocess( complete_filename("bypass_knowledge") );
	if(yyparse()) return -1;

	/* Now read from the user's data */

	yyin = open_and_preprocess( input_filename );
	filename_stem = remove_suffix(input_filename);

	fprintf(stderr,"bypass: input file      : %s\n",
		input_filename );
	fprintf(stderr,"bypass: components      : %s\n",
		make_shadow ? "agent and shadow" : "agent only" );
	fprintf(stderr,"bypass: extract mode    : %s\n",
		extract_is_static ? "static" : "dynamic" );
	fprintf(stderr,"bypass: parsing input\n");

	/* Parse the input into a list of items */

	if(yyparse()) return -1;

	/* Scan the list of functions, matching each to an option entry. */

	for( f=function_list; f; f=f->next ) {
		lookup_options( f );
	}

	/* Massage the list, extracting static modules */

	if(extract_is_static) {
		fprintf(stderr,"bypass: extracting library references\n");
		extract_static( function_list, "bypass_extract.o" );

		fprintf(stderr,"bypass: renaming library references\n");
		extract_rename( function_list, "bypass_extract.o" );
	}

	fprintf(stderr,"bypass: generating code\n");

	/* Open up the various output files */
	
	agent = open_or_quit(filename_stem,"_agent.C","w");
	global = open_or_quit(filename_stem,".h","w");

	if(make_shadow) {
		shadow = open_or_quit(filename_stem,"_shadow.C","w");
	}

	/* Now include the file named by the stem */

	fprintf(agent,"#include \"%s.h\"\n",filename_stem);
	if(make_shadow) fprintf(shadow,"#include \"%s.h\"\n",filename_stem);

	copy_file("bypass_agent.prologue1",agent);

	for( f=function_list; f; f=f->next ) {
		generate_switch_prototype(agent,f);
	}

	if(make_shadow) {
		for( f=function_list; f; f=f->next ) {
			generate_sender_prototype(agent,f);
		}
	}

	/* Now complete the necessary prologue code */

	copy_file("bypass_agent.prologue2",agent);
       	copy_file("bypass_global.prologue",global);

	if(make_shadow) {
		copy_file("bypass_agent.prologue_remote",agent);
		copy_file("bypass_shadow.prologue1",shadow );
	}

        /* Now throw in the user's prologues */

        for( b=block_list; b; b=b->next) {
                if( b->type==BLOCK_TYPE_AGENT ) {
                        fprintf(agent,"%s\n",b->code->text);
                }
                if( b->type==BLOCK_TYPE_SHADOW && make_shadow ) {
                        fprintf(shadow,"%s\n",b->code->text);
                }
        }

	/* And build the shadow actions before the big receiver */

       	if(make_shadow) {
		for( f=function_list; f; f=f->next )
			generate_switch_prototype(shadow,f);

		for( f=function_list; f; f=f->next )
			generate_shadow_action( shadow, f );

		copy_file("bypass_shadow.prologue2",shadow);
	}

	for( f=function_list; f; f=f->next ) {
		call_count++;

		if(make_shadow) {
			generate_sender(agent,f);
			generate_receiver(shadow,f);
		}

		generate_agent_action(agent,f);
		generate_switch(agent,f,extract_is_static);
		generate_number(global,f);
	}

	generate_last_number(global);

	copy_file("bypass_agent.epilogue",agent);
	copy_file("bypass_global.epilogue",global);
	if(make_shadow) copy_file("bypass_shadow.epilogue",shadow);

	/* Make one last pass to generate the list of call names */

	copy_file("bypass_names.prologue",agent);
	if(make_shadow) copy_file("bypass_names.prologue",shadow);

	for( f=function_list; f; f=f->next ) {
		generate_name(agent,f);
		if(make_shadow) generate_name(shadow,f);
	}

	copy_file("bypass_names.epilogue",agent);
	if(make_shadow) copy_file("bypass_names.epilogue",shadow);

	fclose(agent);
	fclose(global);
	if(make_shadow) fclose(shadow);
	
	fprintf(stderr,"bypass: built %d procedure calls\n",call_count);

	return 0;
}
