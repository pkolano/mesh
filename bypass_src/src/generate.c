/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#include "generate.h"
#include "stringtools.h"
#include "pattern.h"

#include <ctype.h>
#include <stdlib.h>
#include <string.h>

void write_alloc_param( FILE *file, char *packet, struct param *p );
void write_param( FILE *file, char *packet, char *dir, struct param *p, struct external *e );
void write_vararg_decls(FILE *file, struct param *p);
void write_local_call( FILE *file, struct function *f, int do_static );
void write_system_call( FILE *file, struct function *f );
void write_dynamic_call( FILE *file, struct function *f );
void write_static_call( FILE *file, struct function *f );
void write_no_local_call( FILE *file, struct function *f );

void generate_switch_prototype( FILE *file, struct function *f )
{
	fprintf(file,"extern \"C\" %s %s( %s );\n",type_string(f->type),f->name->text,param_string(f->params));
}

void generate_sender_prototype( FILE *file, struct function *f )
{
	fprintf(file,"extern \"C\" %s bypass_shadow_%s( %s );\n",type_string(f->type),f->name->text,param_string_noconst(f->params));
}

void generate_switch( FILE *file, struct function *f, int do_static )
{
	struct entry *r;

	if( f->options->also ) {
		fprintf(file,"/* %s has additional code from 'also' statement */\n",f->name->text);
		fprintf(file,"%s\n",f->options->also->text);
	}

	if( f->options->instead ) {
		fprintf(file,"/* %s generated instead of %s */\n\n",f->options->instead->name->text,f->name->text);
		generate_switch( file, f->options->instead, do_static );
		return;
	}

	if( f->options->switch_code ) {
		fprintf(file,"/* manual switch code for %s */\n\n",f->name->text);
		fprintf(file,"%s\n\n",f->options->switch_code->text);
		return;
	}

	for( r=f->options->entrys; r; r=r->next ) {
		generate_entry(file,f,pattern_complete(r->name->text,f->name->text));
	}
}

void generate_entry( FILE *file, struct function *f, char *entry )
{
	fprintf(file,"extern \"C\" %s %s( %s )\n{\n",type_string(f->type),entry,param_string(f->params));

	fprintf(file,"\t%s (*fptr)(%s);\n",type_string(f->type),param_string(f->params));
	if(!is_void(f->type)) {
		fprintf(file,"\t%s result;\n",type_string(f->type));
	}
	write_vararg_decls( file, f->params );

	fprintf(file,"\tbypass_layer_init();\n");
    // PZK 8/7/07: changed int to intptr_t for 64-bit compatibility
	fprintf(file,"\tfptr = (%s(*)(%s)) layer_lookup( \"bypass_agent_action_%s\", \"%s\", (intptr_t) %s );\n",type_string(f->type),param_string(f->params),f->name->text,entry,entry);
	fprintf(file,"\tif(!fptr) fptr = %s;\n",entry);
	fprintf(file,"\tlayer_descend();\n");
	if(!is_void(f->type)) {
		fprintf(file,"\tresult = ");
	} else {
		fprintf(file,"\t");
	}
	fprintf(file,"(*fptr) ( %s );\n",arg_string(f->params));
	fprintf(file,"\tlayer_ascend();\n");
	if(!is_void(f->type)) {
		fprintf(file,"\treturn result;\n");
	}

	/* special case: a switch for _exit() or exit() must fall back on a fatal message */
	if(!strcmp(f->name->text,"exit") || !strcmp(f->name->text,"_exit") ) {
		fprintf(file,"\tbypass_fatal(\"exit() returned without exiting!\");\n");
	}
	fprintf(file,"}\n\n");
}

void generate_agent_action( FILE *file, struct function *f )
{
	fprintf(file,"extern \"C\" %s bypass_agent_action_%s( %s )\n{\n",type_string(f->type),f->name->text,param_string(f->params));
	
	write_vararg_decls(file,f->params);

	if(f->agent_action) {
		fprintf(file,"\t%s\n",f->agent_action->text );
	} else {

		if(!is_void(f->type)) {
			fprintf(file,"\treturn ");
		}

		fprintf(file,"bypass_shadow_%s( %s );\n",pattern_complete(f->options->remote_name->text,f->name->text),arg_string_noconst(f->params));
	}

	fprintf(file,"\n}\n\n");

	if( f->options->instead ) {
		generate_agent_action( file, f->options->instead );
	}
}

void generate_sender( FILE *file, struct function *f )
{
	struct param *p;
	char *fail_string;
	struct external *e;

	/* Create an appropriate exception handler */

	if(f->type->stars) {
		fail_string="0";
	} else if(!is_void(f->type)) {
		fail_string="-1";
	} else {
		fail_string="";
	}

	/* Write the function header */

	fprintf(file,"extern \"C\" %s bypass_shadow_%s( %s )\n{\n",type_string(f->type),f->name->text,param_string_noconst(f->params));

	/* Declare private bypass values */

	fprintf(file,"\tstruct packet *bypass_packet=0;\n");
	fprintf(file,"\tint bypass_errno=0;\n");
	fprintf(file,"\tint bypass_number = BYPASS_CALL_%s;\n",f->name->text);

	if(!is_void(f->type)) {
		fprintf(file,"%s result;\n",type_string(f->type));
	}

	write_vararg_decls(file,f->params);

	/* If the connection has not been made, do it now. */
	fprintf(file,"\tif(!bypass_rpc_init()) goto fail;\n");

	/* Start up a new packet */

	fprintf(file,"\tTRY(bypass_packet = packet_create(0));\n");

	/* Send the number of this call */
	
	fprintf(file,"\tTRY(external(bypass_packet,EXTERNAL_OUT,&bypass_number));\n");

	/* Send the params */

	e = f->options->external;
	for( p=f->params; p; p=p->next ) {
		if( p->control->in ) {
			write_param( file, "bypass_packet", "EXTERNAL_OUT", p, e );
		}
		if(e) e=e->next;
	}

	/* Finally, fire off the packet */

	fprintf(file,"\tTRY(packet_put(bypass_rpc_fd_get(),bypass_packet));\n");
	fprintf(file,"\tpacket_delete(bypass_packet);\n");
	fprintf(file,"\tbypass_packet=0;\n\n");

	/* Grab the result packet */

	fprintf(file,"\tTRY(bypass_packet = packet_get(bypass_rpc_fd_get()));\n");

	/* Get errno, then result, then out parameters */

	fprintf(file,"\tTRY(external_errno_map(bypass_packet,EXTERNAL_IN,&bypass_errno));\n");
	if(!is_void(f->type)) {
		fprintf(file,"\t\tTRY(external(bypass_packet,EXTERNAL_IN,&result));\n");
	}

	e = f->options->external;
	for( p=f->params; p; p=p->next ) {
		if( p->control->out ) {
			write_param( file, "bypass_packet", "EXTERNAL_IN", p, e );
		}
		if(e) e=e->next;
	}

	fprintf(file,"\tpacket_delete(bypass_packet);\n");
	fprintf(file,"\terrno = bypass_errno;\n");

	if(!is_void(f->type)) {
		fprintf(file,"\treturn result;\n");
	} else {
		fprintf(file,"\treturn;\n");
	}

	fprintf(file,"\n");

	/* In the event of a network failure, clean up, and close the connection */

	fprintf(file,"\tfail:\n");
	fprintf(file,"\tbypass_errno = errno;\n");
	fprintf(file,"\tif(bypass_packet) packet_delete(bypass_packet);\n");
	fprintf(file,"\tbypass_rpc_close();\n");

	/* If retries are turned on, put a message and sleep */

	fprintf(file,"\tchar message[1024];\n");
	fprintf(file,"\tsprintf(message,\"couldn't execute %%s: %%s\\n\",bypass_call_string(bypass_number),strerror(bypass_errno));\n");
	fprintf(file,"\tif(bypass_failure_passthrough) {\n");
	fprintf(file,"\t\tbypass_debug(message);\n");
	fprintf(file,"\t} else {\n");
	fprintf(file,"\t\tbypass_fatal(message);\n");
	fprintf(file,"\t}\n");
	fprintf(file,"\terrno = bypass_errno;\n");
	fprintf(file,"\treturn %s;\n",fail_string);
	fprintf(file,"}\n\n");
}

void generate_receiver( FILE *file, struct function *f )
{
	struct param *p;
	struct external *e;

	if( strcmp(f->name->text,pattern_complete(f->options->remote_name->text,f->name->text)) ) {
		fprintf(file,"\t\t/* %s uses the same receiver as %s */\n\n",f->name->text,pattern_complete(f->options->remote_name->text,f->name->text));
		return;
	}

	fprintf(file,"\t\tcase BYPASS_CALL_%s:\n",f->name->text);
	fprintf(file,"\t\t{\n");
	if(!is_void(f->type)) {
		fprintf(file,"\t\t%s result;\n",type_string(f->type));
	}

	/* Declare all the params */

	for( p=f->params; p; p=p->next ) {
		fprintf(file,"\t\t%s %s=0;\n",type_string_noconst(p->type),p->name->text);
	}

	/* Get the params */

	e=f->options->external;
	for( p=f->params; p; p=p->next ) {
		if( p->control->in ) {
			write_param( file, "bypass_packet", "EXTERNAL_IN", p, e );
		}
		if(e) e=e->next;
	}

	/* Allocate space for any out-only parameters */

	for( p=f->params; p; p=p->next ) {
		if( p->control->out && !p->control->in ) {
			write_alloc_param( file, "bypass_response", p );
		}
	}

	fprintf(file,"\t\terrno = 0;\n");

	/* If the function is not supported, send back an error. */
	/* Otherwise, invoke the shadow action */

	if( f->options->not_supported ) {
		fprintf(file,"\t\terrno = EINVAL;\n\n");
        } else {
		if(!is_void(f->type)) {
			fprintf(file,"\t\tresult =");
		} else {
			fprintf(file,"\t\t");
		}
		fprintf(file,"bypass_shadow_action_%s( %s );\n",f->name->text,arg_string(f->params));
	}
	fprintf(file,"\t\tbypass_errno = errno;\n");

	/* Send back errno, then result, then out params */

	fprintf(file,"\t\tTRY(external_errno_map(bypass_response,EXTERNAL_OUT,&bypass_errno));\n");
	if(!is_void(f->type)) {
		fprintf(file,"\t\tTRY(external(bypass_response,EXTERNAL_OUT,&result));\n");
	}

	e=f->options->external;
	for( p=f->params; p; p=p->next ) {
		if( p->control->out ) {
			write_param( file, "bypass_response", "EXTERNAL_OUT", p, e);
		}
		if(e) e=e->next;
	}

	/* All done. */

	fprintf(file,"\t\t}\n");
	fprintf(file,"\t\tbreak;\n\n");
}

void generate_shadow_action( FILE *file, struct function *f )
{
	fprintf(file,"static %s bypass_shadow_action_%s( %s )\n{\n",type_string(f->type),f->name->text,param_string_noconst(f->params));
	
	write_vararg_decls(file,f->params);

	if(f->shadow_action) {
		fprintf(file,"%s\n",f->shadow_action->text );
	} else {

		if(!is_void(f->type)) {
			fprintf(file,"\treturn ");
		}

		fprintf(file,"%s( %s );\n",f->name->text,arg_string_noconst(f->params));
	}

	fprintf(file,"\n}\n\n");
}

static int number_count=0;

void generate_number( FILE *file, struct function *f )
{
	if( strcmp(f->name->text,pattern_complete(f->options->remote_name->text,f->name->text)) ) {
		fprintf(file,"/* %s uses the same sender as %s */\n", f->name->text, pattern_complete(f->options->remote_name->text,f->name->text) );
	} else {
		if( f->options->instead ) {
			fprintf(file,"#define BYPASS_CALL_%s\t%d\n",f->options->instead->name->text,number_count);
		}
		fprintf(file,"#define BYPASS_CALL_%s\t%d\n",f->name->text,number_count++);
	}
}

void generate_last_number( FILE *file )
{
	fprintf(file,"\n#define BYPASS_MAX_CALL %d\n",number_count-1);
}

void generate_name( FILE *file, struct function *f )
{
	fprintf(file,"\"%s\",\n",f->name->text);
}

void write_param( FILE *file, char *packet, char *dir, struct param *p, struct external *e )
{
	char *strsize;
	char *ext;

	if( e ) {
		ext = e->name->text;
	} else {
		ext = "";
	}

	switch(p->control->type ) {
		case CONTROL_TYPE_SINGLE:
			fprintf(file,"\t\tTRY(external%s(%s,%s,&%s));\n",ext,packet,dir,p->name->text);
			break;
		case CONTROL_TYPE_ARRAY:
			fprintf(file,"\t\tTRY(external_array(%s,%s,&%s,%s));\n",packet,dir,p->name->text,p->control->code->text);
			break;
		case CONTROL_TYPE_OPAQUE:
			fprintf(file,"\t\tTRY(external_opaque(%s,%s,(char**)&%s,%s));\n",packet,dir,p->name->text,p->control->code->text);
			break;
		case CONTROL_TYPE_STRING:
			if( p->control->code ) {
				strsize = p->control->code->text;
			} else {
				strsize = "0";
			} 
			fprintf(file,"\t\tTRY(external_string(%s,%s,&%s,%s));\n",packet,dir,p->name->text,strsize);
			break;
	}
}

void write_alloc_param( FILE *file, char *packet, struct param *p )
{
	switch(p->control->type ) {
		case CONTROL_TYPE_SINGLE:
			fprintf(file,"\t\tTRY(%s = (%s) packet_alloc(%s,sizeof(*%s)));\n",p->name->text,type_string_noconst(p->type),packet,p->name->text);
			break;
		case CONTROL_TYPE_ARRAY:
			fprintf(file,"\t\tTRY(%s = (%s) packet_alloc(%s,sizeof(*%s)*%s));\n",p->name->text,type_string_noconst(p->type),packet,p->name->text,p->control->code->text);
			break;
		case CONTROL_TYPE_OPAQUE:
			fprintf(file,"\t\tTRY(%s = (%s) packet_alloc(%s,%s));\n",p->name->text,type_string_noconst(p->type),packet,p->control->code->text);
			break;
		case CONTROL_TYPE_STRING:
			if( !p->control->code ) {
				fprintf(stderr,"*** parameter %s is \"out string\", so it must have a maximum allowed size.\n",p->name->text);
				exit(-1);
			}
			fprintf(file,"\t\tTRY(%s = (%s) packet_alloc(%s,%s));\n",p->name->text,type_string_noconst(p->type),packet,p->control->code->text);
			break;
	}
}

void write_vararg_decls( FILE *file, struct param *p )
{
	struct param *q=0;

	/* Skip to the first vararg (if any) */

	while(1) {
		if(!p) return;
		if(p->is_vararg) break;
		q=p;
		p = p->next;
	}

	/* Now, q is null or points to the param previous to p. */

	if(!q) {
		fprintf(stderr,"*** At least one regular parameter must precede any variable parameters.\n");
		return;
	}

	/* Begin the vararg traversal */

	fprintf(file,"\tva_list bypass_arglist;\n");
	fprintf(file,"\tva_start(bypass_arglist,%s);\n",q->name->text);

	/* For each remaining parameter, declare storage and extract it */

	for( ; p; p=p->next ) {
		fprintf(file,"\t%s\t%s;\n",type_string(p->type),p->name->text);
		fprintf(file,"\t%s = va_arg(bypass_arglist,%s);\n",p->name->text,type_string(p->type));
	}

	/* Done with the traversal */

	fprintf(file,"\tva_end(bypass_arglist);\n");
}

void write_local_call( FILE *file, struct function *f, int do_static )
{
	switch(f->options->linkage) {
		case OPTION_LINKAGE_SYSCALL:
			write_system_call(file,f);
			break;
		case OPTION_LINKAGE_LIBCALL:
			if( do_static ) {
				write_static_call(file,f);
			} else {
				write_dynamic_call(file,f);
			}
			break;
		default:
			write_no_local_call(file,f);
			break;
	}
}


void write_system_call( FILE *file, struct function *f )
{
	if( f->options->indirect ) {
		fprintf(file,"\t\t\t#ifdef SYS_%s\n",f->options->indirect->text);
		if(!is_void(f->type)) {
			fprintf(file,"\t\t\t\tresult = ");
		} else {
			fprintf(file,"\t\t\t\t");
		}
		if(f->params) {
			fprintf(file,"syscall(SYS_%s,SYS_%s,%s);\n",f->options->indirect->text,upper_string(f->name->text),arg_string(f->params));
		} else {
			fprintf(file,"syscall(SYS_%s,SYS_%s);\n",f->options->indirect->text,upper_string(f->name->text));
		}
	} else {
		fprintf(file,"\t\t\t#ifdef SYS_%s\n",pattern_complete(f->options->local_name->text,f->name->text));
		if(!is_void(f->type)) {
			fprintf(file,"\t\t\t\tresult = ");
		} else {
			fprintf(file,"\t\t\t\t");
		}
		if(f->params) {
			fprintf(file,"syscall(SYS_%s,%s);\n",pattern_complete(f->options->local_name->text,f->name->text),arg_string(f->params));
		} else {
			fprintf(file,"syscall(SYS_%s);\n",pattern_complete(f->options->local_name->text,f->name->text));
		}
	}


	fprintf(file,"\t\t\t#else\n");
	write_dynamic_call( file, f );
	fprintf(file,"\t\t\t#endif\n");
}

void write_dynamic_call( FILE *file, struct function *f )
{
	/* Declare a library handle, open it if needed */
	fprintf(file,"\t\t\tstatic void *handle = 0;\n");
	fprintf(file,"\t\t\tif(!handle) handle = bypass_library_open(\"%s.so\");\n",f->options->library->text);
	fprintf(file,"\t\t\tif(!handle) handle = bypass_library_open(\"%s.sl\");\n",f->options->library->text);
	fprintf(file,"\t\t\tif(!handle) handle = bypass_library_open(\"%s.so.6\");\n",f->options->library->text);
	fprintf(file,"\t\t\tif(!handle) bypass_call_error(BYPASS_CALL_%s,\"can't find library\");\n\n",f->name->text);

	/* Declare a function pointer, look it up if needed */
	fprintf(file,"\t\t\tstatic %s (*fptr)( %s ) = 0;\n",type_string(f->type),param_string(f->params));
	fprintf(file,"\t\t\tif(!fptr) fptr = (%s(*)(%s)) bypass_library_lookup(handle,\"%s\");\n",type_string(f->type),param_string(f->params),pattern_complete(f->options->local_name->text,f->name->text));
	fprintf(file,"\t\t\tif(!fptr) bypass_call_error(BYPASS_CALL_%s,\"can't find procedure in library\");\n",f->name->text);

	/* Otherwise, invoke the function */

	if(!is_void(f->type)) {
		fprintf(file,"\t\t\tresult = ");
	} else {
		fprintf(file,"\t\t\t");
	}
	fprintf(file,"fptr( %s );\n",arg_string(f->params));
}

void write_static_call( FILE *file, struct function *f )
{
	fprintf(file,"\t\t\textern %s %s (%s);\n",type_string(f->type),upper_string(pattern_complete(f->options->local_name->text,f->name->text)),param_string(f->params));

	if(!is_void(f->type)) {
		fprintf(file,"\t\t\tresult = ");
	} else {
		fprintf(file,"\t\t\t");
	}
	fprintf(file,"%s( %s );\n",upper_string(pattern_complete(f->options->local_name->text,f->name->text)),arg_string(f->params));
}

void write_no_local_call( FILE *file, struct function *f )
{
	if(!is_void(f->type)) {
		fprintf(file,"\t\t\t\tresult = ");
	} else {
		fprintf(file,"\t\t\t\t");
	}
	fprintf(file,"bypass_call_error(BYPASS_CALL_%s,\"no local version of this call\");\n",pattern_complete(f->options->remote_name->text,f->name->text));
}


