
# verification tests
#
# currently simply provides means to automatically sort/diff entdb
# generated files as compared to reference copies - output must be
# manually verified.
#
# although entdb attempts to carefully store database recods in
# input source order to preserve traditional v7-like local-filesystem
# parsing semantics,
# files are sorted in the tests since entdb's 'load' mechanisms
# uses 'getent' calls, which in turn will source data over NIS on
# a client machine; this in turn implies that input data over NIS
# comes from dbm files, which do not treat sequence as important
# in some cases.
#
# files can be directly diffed in such cases and so much of the
# makefile logic here is not needed.
# 

TRUE=/usr/bin/true

TESTBASE=var
SRCBASE=${TESTBASE}/src
ENTBASE=${TESTBASE}/ent

SRCPASS=${SRCBASE}/passwd
SRCSHADOW=${SRCBASE}/shadow
SRCGROUP=${SRCBASE}/group
SRCNETGROUP=${SRCBASE}/netgroup
SRCALIASES=${SRCBASE}/aliases

SRCPASS_SORTED=${SRCPASS}.sorted
SRCSHADOW_SORTED=${SRCSHADOW}.sorted
SRCGROUP_SORTED=${SRCGROUP}.sorted
SRCNETGROUP_SORTED=${SRCNETGROUP}.sorted
SRCALIASES_SORTED=${SRCALIASES}.sorted

ENTPASS=${ENTBASE}/passwd
ENTSHADOW=${ENTBASE}/shadow
ENTGROUP=${ENTBASE}/group
ENTNETGROUP=${ENTBASE}/netgroup
ENTALIASES=${ENTBASE}/aliases

ENTPASS_SORTED=${ENTPASS}.sorted
ENTSHADOW_SORTED=${ENTSHADOW}.sorted
ENTGROUP_SORTED=${ENTGROUP}.sorted
ENTNETGROUP_SORTED=${ENTNETGROUP}.sorted
ENTALIASES_SORTED=${ENTALIASES}.sorted
	${SRCSHADOW_SORTED} ${ENTSHADOW_SORTED} \
	${SRCALIASES_SORTED} ${ENTALIASES_SORTED}

TARGS=		verify-passwd verify-shadow verify-group \
		verify-netgroup verify-aliases

.PHONY: ${TARGS}

all: ${TARGS}

verify-passwd: ${SRCPASS_SORTED} ${ENTPASS_SORTED}
	@echo "# => password diff:"
	@diff ${SRCPASS_SORTED} ${ENTPASS_SORTED} || ${TRUE}

verify-shadow: ${SRCSHADOW_SORTED} ${ENTSHADOW_SORTED}
	@echo "# => shadow diff:"
	@diff ${SRCSHADOW_SORTED} ${ENTSHADOW_SORTED} || ${TRUE}

verify-group: ${SRCSHADOW_SORTED} ${ENTSHADOW_SORTED}
	@echo "# => group diff:"
	@diff ${SRCSHADOW_SORTED} ${ENTSHADOW_SORTED} || ${TRUE} 

verify-netgroup: ${SRCNETGROUP_SORTED} ${ENTNETGROUP_SORTED}
	@echo "# => netgroup diff:"
	@diff ${SRCNETGROUP_SORTED} ${ENTNETGROUP_SORTED} || ${TRUE}

verify-aliases: ${SRCALIASES_SORTED} ${ENTALIASES_SORTED}
	@echo "# => aliases diff:"
	@diff ${SRCALIASES_SORTED} ${ENTALIASES_SORTED} || ${TRUE}

${SRCPASS_SORTED}: ${SRCPASS}
	sort ${SRCPASS} > ${SRCPASS_SORTED}

${ENTPASS_SORTED}: ${ENTPASS}
	sort ${ENTPASS} > ${ENTPASS_SORTED}

${SRCSHADOW_SORTED}: ${SRCSHADOW}
	sort ${SRCSHADOW} > ${SRCSHADOW_SORTED}

${ENTSHADOW_SORTED}: ${ENTSHADOW}
	sort ${ENTSHADOW} \
	| awk -F : '{print $$1":x:"$$3":"$$4":"$$5":"$$6":"$$7":"$$8":"$$9 }' \
	> ${ENTSHADOW_SORTED}

${SRCGROUP_SORTED}: ${SRCGROUP}
	sort ${SRCGROUP} > ${SRCGROUP_SORTED}

${ENTGROUP_SORTED}: ${ENTGROUP}
	sort ${ENTGROUP} > ${ENTGROUP_SORTED}

${SRCNETGROUP_SORTED}: ${SRCNETGROUP}
	sed -e 's:\\::' -e 's:^ *::' -e 's: *: :' ${SRCNETGROUP} \
		| tr -s '\040' '\012' |sort \
		> ${SRCNETGROUP_SORTED}

${ENTNETGROUP_SORTED}: ${ENTNETGROUP}
	sed -e 's:\\::' -e 's:^ *::' -e 's: *: :' ${ENTNETGROUP} \
		| tr -s '\040' '\012' | sort \
		> ${ENTNETGROUP_SORTED}

${SRCALIASES_SORTED}: ${SRCALIASES}
	egrep -v '^(#|$$| *$$| *#)' ${SRCALIASES} |sort > ${SRCALIASES_SORTED}

${ENTALIASES_SORTED}: ${ENTALIASES}
	egrep -v '^(#|$$| *$$| *#)' ${ENTALIASES} |sort > ${ENTALIASES_SORTED}

clean:
	rm -f ${GEN}

