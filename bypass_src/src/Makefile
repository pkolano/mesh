
include ../Makefile.config

all: bypass libbypass.a

bypass: main.o generate.o extract.o stringtools.o parser.tab.o scanner.o pattern.o
	${LD} $^ ${LDFLAGS} -o $@

libbypass.a: layer.o hashtable.o network.o external.o external_unix.o packet.o pattern.o auth.o auth_trivial.o private_malloc.o
	ar rv $@ $^

main.o: main.c
	${CC} ${CCFLAGS} $< -c -o $@

generate.o: generate.c
	${CC} ${CCFLAGS} $< -c -o $@

extract.o: extract.c
	${CC} ${CCFLAGS} $< -c -o $@

stringtools.o: stringtools.c
	${CC} ${CCFLAGS} $< -c -o $@

pattern.o: pattern.c
	${CC} ${CCFLAGS} $< -c -o $@

scanner.o:  scanner.c
	${CC} ${CCFLAGS} $< -c -o $@

parser.tab.o: parser.tab.c
	${CC} ${CCFLAGS} $< -c -o $@

scanner.c: scanner.l parser.tab.h
	${LEX} ${LEXFLAGS} -t >scanner.c scanner.l

parser.tab.h: parser.tab.c

parser.tab.c: parser.y parser.h
	${YACC} ${YACCFLAGS} -b parser -d parser.y

layer.o: layer.c
	${CC} ${CCFLAGS} ${THREADS_SUPPORTED} $< -c -o $@

hashtable.o: hashtable.c
	${CC} ${CCFLAGS} $< -c -o $@

auth.o: auth.c
	${CXX} ${CXXFLAGS} $< -c -o $@

auth_trivial.o: auth_trivial.c
	${CC} ${CCFLAGS} $< -c -o $@

private_malloc.o: private_malloc.c
	${CC} ${CCFLAGS} $< -c -o $@

network.o: network.c
	${CC} ${CCFLAGS} $< -c -o $@

packet.o: packet.c int_sizes.h
	${CC} ${CCFLAGS} $< -c -o $@

int_sizes.h: make_int_sizes
	if ./make_int_sizes > int_sizes.h ; then exit 0 ; else rm -f int_sizes.h ; exit 1 ; fi

make_int_sizes: make_int_sizes.o
	${LD} make_int_sizes.o -o $@ ${LDFLAGS}

make_int_sizes.o: make_int_sizes.c
	${CC} ${CCFLAGS} $< -c -o $@

external.o: external.c
	${CXX} ${CXXFLAGS} $< -c -o $@

external_unix.o: external_unix.c open_map.c fcntl_map.c signal_map.c errno_map.c poll_map.c
	${CXX} ${CXXFLAGS} $< -c -o $@

open_map.c: open_map.list
	perl ./list-to-map.pl bitmap open_map < open_map.list > open_map.c

fcntl_map.c: fcntl_map.list
	perl ./list-to-map.pl integer fcntl_map < fcntl_map.list > fcntl_map.c

signal_map.c: signal_map.list
	perl ./list-to-map.pl integer signal_map < signal_map.list > signal_map.c

errno_map.c: errno_map.list
	perl ./list-to-map.pl integer errno_map < errno_map.list > errno_map.c

poll_map.c: poll_map.list
	perl ./list-to-map.pl bitmap poll_map < poll_map.list > poll_map.c

clean:
	rm -f bypass *~ *.o parser.tab.* scanner.c open_map.c fcntl_map.c signal_map.c errno_map.c poll_map.c libbypass.a int_sizes.h make_int_sizes

