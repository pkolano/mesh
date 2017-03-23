-include Makefile.config

all: $(TYPE)

install: root prefix all $(TYPE)_install

clean:
	cd bypass; make clean

distclean: clean
	rm -f Makefile.config
	cd bypass; make distclean
	cd bypass_src; make realclean


#############################################################
#### DO NOT DIRECTLY INVOKE ANY TARGETS BELOW THIS POINT ####
#############################################################

MP_BIN = mc mesh-getmp mesh-keygen mesh-keykill mesh-keytime mesh-setmp \
         mesh-update
MP_SBIN = mesh-logstats
MAP_BIN = mesh-keygen mesh-keykill mesh-setmp
MAP_SBIN = mesh-logstats
MASH_LIB = Command.pm Policy.pm Proxy.pm Proxy/None.pm Proxy/Ssh.pm \
           Rule/Argument.pm Rule/Connection.pm Rule/Environment.pm \
           Rule/Group.pm Rule/Option.pm Rule/User.pm
.PHONY = all install clean distclean root \
         prefix extra_prefix \
         mp mp_install \
         map map_install \
         mash mash_install \
         resource resource_install \
         mess mess_install


##############
#### MAKE ####
##############

mp: mia mash

map: mia mash

mash:

resource: mia

mess: mia

mia:
	cd bypass_src; make
	cd bypass; make


######################
#### MAKE INSTALL ####
######################

root:
	test `whoami` = "root"

prefix:
	install -d -g root -m 0755 -o root /etc/mesh $(PREFIX)
	cd $(PREFIX); install -d -g root -m 0755 -o root bin lib sbin
	test -f /etc/mesh/mesh.conf || install -g root -m 0644 -o root etc/mesh.conf /etc/mesh/mesh.conf

mp_install: mash_install mia_install extra_prefix
	cd perl; install -g root -m 0755 -o root $(MP_BIN) $(PREFIX)bin
	cd perl; install -g root -m 0755 -o root $(MP_SBIN) $(PREFIX)sbin
	test -f /etc/mesh/mashrc || install -g root -m 0644 -o root etc/mashrc.mp /etc/mesh/mashrc

map_install: mash_install mia_install extra_prefix
	cd perl; install -g root -m 0755 -o root $(MAP_BIN) $(PREFIX)bin
	cd perl; install -g root -m 0755 -o root $(MAP_SBIN) $(PREFIX)sbin
	test -f /etc/mesh/mashrc || install -g root -m 0644 -o root etc/mashrc.map /etc/mesh/mashrc

mash_install:
	cd perl; install -g root -m 0755 -o root mash.pl $(PREFIX)bin/mash
	cd $(PREFIX)lib; install -d -g root -m 0755 -o root Mash/Proxy Mash/Rule
	cd perl/Mash; for file in $(MASH_LIB); do \
		install -g root -m 0644 -o root $$file $(PREFIX)lib/Mash/$$file; \
	done

resource_install: mess_install
	install -d -g root -m 0700 -o root /etc/mesh/mapkeys

mess_install: mia_install
	cd perl; install -g root -m 0755 -o root mess $(PREFIX)bin
	test -f /etc/mesh/meshrc || install -g root -m 0644 -o root etc/meshrc.resource /etc/mesh/meshrc

mia_install:
	cd perl; install -g root -m 0755 -o root mesh-getkey $(PREFIX)sbin
	cd perl; install -g root -m 0755 -o root mesh-getkey-hook $(PREFIX)sbin
	cd bypass; make install

extra_prefix:
	grep ^$(GROUP): /etc/group
	install -d -g root -m 0755 -o root $(PREFIX)var
	install -d -g $(GROUP) -m 0750 -o root /etc/mesh/mapkeys
	install -d -g $(GROUP) -m 1753 -o root $(PREFIX)var/meshkeys
	install -d -g root -m 1753 -o root $(PREFIX)var/meshmps

