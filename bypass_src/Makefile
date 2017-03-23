
include Makefile.config

all:
	cd src; ${MAKE}

Makefile.config:
	@echo "*** You must run 'configure' before 'make'."
	@exit 1

install: all
	install -d ${INSTALL_DIR}
	install -d ${INSTALL_DIR}/bin
	install -d ${INSTALL_DIR}/lib
	install -d ${INSTALL_DIR}/include	
	install -d ${INSTALL_DIR}/doc
	install -d ${INSTALL_DIR}/examples
	install README ${INSTALL_DIR}
	install src/bypass ${INSTALL_DIR}/bin
	install lib/bypass* ${INSTALL_DIR}/lib
	install doc/bypass.html ${INSTALL_DIR}/doc
	install src/libbypass.a  ${INSTALL_DIR}/lib
	install src/layer.h  ${INSTALL_DIR}/include
	install src/network.h  ${INSTALL_DIR}/include
	install src/packet.h  ${INSTALL_DIR}/include
	install src/external.h  ${INSTALL_DIR}/include
	install src/external_unix.h  ${INSTALL_DIR}/include
	install src/pattern.h  ${INSTALL_DIR}/include
	install src/auth.h  ${INSTALL_DIR}/include
	install src/hashtable.h ${INSTALL_DIR}/include 
	install src/private_malloc.h ${INSTALL_DIR}/include

clean:
	cd src; ${MAKE} clean

realclean: clean
	rm -f Makefile.config configure.rerun
