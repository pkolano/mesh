/*
Bypass
Copyright (C) 1999-2001 Douglas Thain
http://www.cs.wisc.edu/condor/bypass
This program is released under a BSD License.
See the file COPYING for details.
*/

#include "hashtable.h"
#include "private_malloc.h"
#include <stdlib.h>

struct entry {
	int is_valid;
    // PZK 8/7/07: changed int to intptr_t for 64-bit compatibility
	intptr_t key;
	void *value;
};

struct hashtable {
	int bucket_count;
	struct entry *buckets;
};

struct hashtable * hashtable_create( int bucket_count )
{
	struct hashtable *h;
	int i;

	h = private_malloc(sizeof(struct hashtable));
	h->bucket_count = bucket_count;
	h->buckets = private_malloc( sizeof(struct entry)*bucket_count );

	for( i=0; i<bucket_count; i++ ) {
		h->buckets[i].is_valid = 0;
	}

	return h;
}

void * hashtable_lookup( struct hashtable *h, intptr_t key )
{
    // PZK 8/7/07: changed int to intptr_t for 64-bit compatibility
	intptr_t start;
	intptr_t i;

	if(key<0) key = -key;
	start = key % h->bucket_count;

	for(i=start;i<h->bucket_count;i++) {
		if( !h->buckets[i].is_valid ) {
			return 0;
		}
		if( h->buckets[i].key==key ) {
			return h->buckets[i].value;
		}
	}

	for(i=0;i<start;i++) {
		if( !h->buckets[i].is_valid ) {
			return 0;
		}
		if( h->buckets[i].key==key ) {
			return h->buckets[i].value;
		}
	}

	return 0;
}

int hashtable_insert( struct hashtable *h, intptr_t key, void *value )
{
    // PZK 8/7/07: changed int to intptr_t for 64-bit compatibility
	intptr_t i;
	intptr_t start;
	
	if(key<0) key = -key;
	start = key % h->bucket_count;

	for(i=start;i<h->bucket_count;i++) {
		if( !h->buckets[i].is_valid || h->buckets[i].key==key ) {
			h->buckets[i].is_valid = 1;
			h->buckets[i].key = key;
			h->buckets[i].value = value;
			return 1;
		}
	}

	for(i=0;i<start;i++) {
		if( !h->buckets[i].is_valid || h->buckets[i].key==key ) {
			h->buckets[i].is_valid = 1;
			h->buckets[i].key = key;
			h->buckets[i].value = value;
			return 1;
		}
	}

	return 0;
}
