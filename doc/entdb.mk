
# entdb yp/mgmt makefile
# ======================
#
# used to manage entdb related file generation for use by ypserv makefile
# syntax is intended to be as simple and generic as possible for compatiblity.
#
# $Id$


SRCMK=			doc/entdb.mk
YPDIR=			/var/yp
ENTDIR?=		${YPDIR}/ent
ENTDBDB=		${ENTDIR}/db

ENTDBCMD=		entdb
UMASK=umask 066

SRCALIASES?=		/etc/mail/aliases

default: help

help:
	@echo "entdb makefile targets"
	@echo ""
	@echo "  installdb: install db into ${ENTDIR}"
	@echo "  dblogin: launch sqlite against ${ENTDBDB}"
	@echo "  files: generate files from database. triggers:" 
	@echo "    triggers the following sub-targets:" 
	@echo "    - passwd"
	@echo "    - shadow"
	@echo "    - master.passwd"
	@echo "    - passwd.adjunct"
	@echo "    - group"
	@echo "    - netgroup"
	@echo "    - aliases"
	@echo "  ypupdate: trigger YP update"
	@echo ""

# Database Build/Maint Targets
# ============================

installdb:
	install -d -m 750 -o root -g 0 ${ENTDIR}
	${ENTDBCMD} createdb ${ENTDBDB}
	${ENTDBCMD} loadgetent ${ENTDBDB}
	${ENTDBCMD} loadnetgroup ${ENTDBDB}
	${ENTDBCMD} loadmailaliases ${ENTDBDB} ${SRCALIASES}
	install -m 750 -o root -g 0 ${SRCMK} \
		${ENTDIR}/Makefile

dblogin:
	sqlite3 ${ENTDBDB} || exit 0;

# File Generation Targets
# =======================

files: passwd shadow master.passwd passwd.adjunct group netgroup aliases

passwd: ${ENTDBDB}
	${ENTDBCMD} dumplinuxpasswd ${ENTDBDB} > passwd

shadow: ${ENTDBDB}
	${UMASK}; ${ENTDBCMD} dumplinuxshadow ${ENTDBDB} > shadow

master.passwd: ${ENTDBDB}
	${UMASK}; ${ENTDBCMD} dumpbsdpasswd ${ENTDBDB} > master.passwd

passwd.adjunct: ${ENTDBDB}
	${UMASK}; ${ENTDBCMD} dumppasswdadjunct ${ENTDBDB} > passwd.adjunct

group: ${ENTDBDB}
	${ENTDBCMD} dumpgroup ${ENTDBDB} > group

netgroup: ${ENTDBDB}
	${ENTDBCMD} dumpnetgroup ${ENTDBDB} > netgroup

aliases: ${ENTDBDB}
	${ENTDBCMD} dumpmailaliases ${ENTDBDB} > aliases

# NIS Interface
# =============

ypupdate:
	cd ${YPDIR} && ${MAKE}

