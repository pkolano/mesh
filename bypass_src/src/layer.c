
#include "layer.h"
#include "hashtable.h"
#include "private_malloc.h"

#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <signal.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <dlfcn.h>

// PZK 4/6/06: define these in makefile
//#define BACKUP_LIBRARY "libc.so"
#define BACKUP_BACKUP_LIBRARY "libc.so"
#define CACHE_LOOKUPS

#ifdef linux
	long syscall( long num, ... );
#else
	int syscall( int num, ... );
#endif

#ifndef sgi
	#include <sys/syscall.h>
#else
	#include <sys.s>
#endif

/*
One layer_entry structure is kept for every
interposition layer present in the process.
*/

struct layer_entry {
	int is_agent;
	char *name;
	void *handle;
	struct hashtable *table;
	struct layer_entry *next, *prev;
};

/*
One thread_entry structure is kept for every
thread in the process, detailing where it is
with respect to the layers.  An unthreaded
process has exactly one thread_entry.
*/

struct thread_entry {
	struct layer_entry *current;
	int overflow;
    // PZK 8/7/07: changed int to intptr_t for 64-bit compatibility
	intptr_t tid;
};	

static struct hashtable *thread_table = 0;
static struct layer_entry *layer_head = 0;
static void *backup_library = 0;

/*
Add a layer to the bottom of the layer list.
*/

// PZK 11/3/11: changed name to const to avoid warnings
int layer_register( const char *library_name, int is_agent )
{
	struct layer_entry *layer;

	layer = private_malloc(sizeof(struct layer_entry));
	layer->table = hashtable_create( 127 );

	layer->is_agent = is_agent;
	layer->name = (char *) library_name;
	layer->handle = 0;
	layer->prev = 0;
	layer->next = 0;

	if(!layer_head) {
		layer_head = layer;
	} else {
		struct layer_entry *j;
		for(j=layer_head;j->next;j=j->next) {} 
		j->next = layer;
		layer->prev = j;
	}

	return 1;
}

/*
This function returns the entry for the current thread,
creating it if necessary.  Notice that the thread is
initialized to run in *no* layer.
*/

static struct thread_entry * layer_thread_lookup()
{
	struct thread_entry *thread;

	if(!thread_table) {
		thread_table = hashtable_create(127);
	}

	thread = (struct thread_entry*)hashtable_lookup(thread_table, layer_pthread_self());
	if(!thread) {

		thread = private_malloc(sizeof(*thread));
		thread->current = 0;
		thread->overflow = 0;
		thread->tid = layer_pthread_self();

		if(!hashtable_insert(thread_table,thread->tid,thread)) {
			layer_fatal("out of memory");
		}
	}

	return thread;
}

/*
If all else goes wrong, this is a last-ditch attempt to find a symbol in libc.
*/

// PZK 11/3/11: changed name to const to avoid warnings
static void * layer_lookup_backup( const char *name )
{
	void * result;

	if(!backup_library) {
		backup_library = dlopen(BACKUP_LIBRARY,RTLD_LAZY);
		if(!backup_library) {
			backup_library = dlopen(BACKUP_BACKUP_LIBRARY,RTLD_LAZY);
			if(!backup_library) {
				layer_fatal("couldn't open %s: %s!\n",BACKUP_LIBRARY,strerror(errno));
			}
		}
	}

	result = dlsym(backup_library,name);
	if(!result) layer_fatal("couldn't find %s in %s\n",name,BACKUP_LIBRARY);

	return result;
}

/*
Given two name variants and a key, find the function to call,
based on knowledge of the current thread and its position
in the layer stack.
*/

// PZK 11/3/11: changed names to const to avoid warnings
// PZK 8/7/07: changed int to intptr_t for 64-bit compatibility
void * layer_lookup( const char *name, const char *standard_name, intptr_t key )
{
	struct thread_entry *thread;
	struct layer_entry *layer;
	void *result;

	result = 0;

	layer_pthread_mutex_lock();

	thread = layer_thread_lookup();
	layer = thread->current;

	/*
	If the thread does not know its current layer,
	then we are in a deep mess, so punt by calling
	the backup routine.
	*/

	if(!layer) {
		result = layer_lookup_backup(standard_name);
		layer_pthread_mutex_unlock();
		return result;
	}

	/*
	If caching is enabled, first look for the requested
	routine in the layer's hash table
	*/

	#ifdef CACHE_LOOKUPS
	result = hashtable_lookup( layer->table, key );
	if(result) {
		layer_pthread_mutex_unlock();
		return result;
	}
	#endif

	/*
	Otherwise, go to the physical library itself and
	look for the symbol by its variants.
	*/

	if(!layer->handle) {
		layer->handle = dlopen(layer->name,RTLD_LAZY);
		if(!layer->name) layer_fatal("couldn't open library '%s'",layer->name);
	}

	if(layer->is_agent) {
		result = dlsym(layer->handle,name);
	} else {
		result = dlsym(layer->handle,standard_name);
	}

	if(!result && !layer->next) {
		layer_fatal("fell off the bottom while looking for '%s'",standard_name);
	}

	#ifdef CACHE_LOOKUPS
	hashtable_insert( layer->table, key, result );
	#endif

	layer_pthread_mutex_unlock();

	return result;
}

int 	layer_is_agent()
{
	struct thread_entry *thread;
	int result;

	layer_pthread_mutex_lock();
	thread = layer_thread_lookup();
	if(!thread->current) {
		result = 0;
	} else {
		result =  thread->current->is_agent;
	}
	layer_pthread_mutex_unlock();

	return result;
}

void	layer_descend()
{
	struct thread_entry *thread;

	layer_pthread_mutex_lock();
	thread = layer_thread_lookup();
	if(thread->current) {
		if(thread->current->next) {
			thread->current = thread->current->next;
		} else {
			thread->overflow++;
		}
	}
	layer_pthread_mutex_unlock();
}

void	layer_ascend()
{
	struct thread_entry *thread;

	layer_pthread_mutex_lock();

	thread = layer_thread_lookup();
	if(thread->current) {
		if(thread->overflow>0) {
			thread->overflow--;
		} else {
			if(thread->current->prev) {
				thread->current = thread->current->prev;
			}
		}
	}
	layer_pthread_mutex_unlock();
}

/*
This function moves the calling thread
to the topmost layer.   It is used to initialize the
first thread into an application-usable state.
*/

void  layer_top()
{
	struct thread_entry *thread;

	layer_pthread_mutex_lock();
	thread = layer_thread_lookup();
	thread->current = layer_head;
	thread->overflow = 0;
	layer_pthread_mutex_unlock();
}

/*
This function moves the thread to the bottommost layer.
It simply clears the 'current' variable, which causes
layer_lookup to always use the backup method.
*/

void layer_bottom()
{
	struct thread_entry *thread;

	layer_pthread_mutex_lock();
	thread = layer_thread_lookup();
	thread->current = 0;
	layer_pthread_mutex_unlock();
}

/*
Return a pointer to the current layer.
*/

struct layer_entry * layer_get()
{
	struct thread_entry *thread;
	void *result;

	layer_pthread_mutex_lock();

	thread = layer_thread_lookup();
	result = thread->current;

	layer_pthread_mutex_unlock();

	return result;
}

/*
Force the current thread to move to the given layer.
*/

void layer_set( struct layer_entry *layer )
{
	struct thread_entry *thread;
	
	layer_pthread_mutex_lock();

	thread = layer_thread_lookup();
	thread->current = layer;
	thread->overflow = 0;

	layer_pthread_mutex_unlock();
}

/*
Display a fatal message and abort the process.
*/

void	layer_fatal( char *fmt, ... )
{
	char buffer[1024];

	va_list args;
	va_start(args,fmt);

	vsprintf(buffer,fmt,args);

	layer_debug("layer: ");
	layer_debug(buffer);

	if(errno!=0) {
		layer_debug(" ");
		layer_debug(strerror(errno));
	}

	layer_debug("\n");
	kill(getpid(),SIGKILL);

	va_end(args);
}

/*
Display the list of layers loaded.
*/

void layer_dump()
{
	struct layer_entry *layer;

	for( layer=layer_head; layer; layer=layer->next ) {
		if(layer->is_agent) {
			layer_debug("\tagent\t");
		} else {
			layer_debug("\tlibrary\t");
		}
		layer_debug(layer->name);
		layer_debug("\n");
	}
}

/*
Print a message to the console.
*/

void layer_debug( char *str )
{
	syscall(SYS_write,2,str,strlen(str));
}
