#ifndef PRIVATE_MALLOC_H
#define PRIVATE_MALLOC_H

/*
This module defines the simplest memory allocator possible,
simply linearly allocating memory from a statically declared
chunk of memory.  This is necessary because the lowest layers
of Bypass do even fundamental system calls such as malloc(),
sbrk(), and mmap().  This allocator will abort the process
if memory is exhausted, so it is not necessary to check
for a successful return value.
*/

#ifdef __cplusplus
extern "C" {
#endif

void * private_malloc( unsigned size );

#ifdef __cplusplus
}
#endif

#endif
