
#include "private_malloc.h"
#include "layer.h"

#define PRIVATE_MALLOC_MAX 1024*1024

static char arena[PRIVATE_MALLOC_MAX];
static char *top=0;

void * private_malloc( unsigned size )
{
	char *result;

	if(!top) {
		top = arena;
	}

	result = top;
	top += size;

	if((top-arena)>PRIVATE_MALLOC_MAX) {
		layer_fatal("Out of private memory!  Rebuild Bypass with a larger PRIVATE_MALLOC_MAX.");
	}

	return (void*) result;
}
