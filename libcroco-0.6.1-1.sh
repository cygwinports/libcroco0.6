#!/bin/bash
#
# Gentoo-based package build script

# find out where the build script is located
tdir=`echo "$0" | sed 's%[\\/][^\\/][^\\/]*$%%'`
test "x$tdir" = "x$0" && tdir=.
scriptdir=`cd $tdir; pwd`

# find src directory.
# If scriptdir ends in SPECS, then topdir is $scriptdir/..
# If scriptdir ends in CYGWIN-PATCHES, then topdir is $scriptdir/../..
# Otherwise, we assume that topdir = scriptdir
topdir1=`echo ${scriptdir} | sed 's%/SPECS$%%'`
topdir2=`echo ${scriptdir} | sed 's%/CYGWIN-PATCHES$%%'`
if [ "x$topdir1" != "x$scriptdir" ] ; then # SPECS
	T=`cd ${scriptdir}/..; pwd`
elif [ "x$topdir2" != "x$scriptdir" ] ; then # CYGWIN-PATCHES
		T=`cd ${scriptdir}/../..; pwd`
else
		T=`cd ${scriptdir}; pwd`
fi

tscriptname=`basename $0 .sh`
PN=`echo $tscriptname | sed -e 's/\-[^\-]*\-[^\-]*$//'`
PV=`echo $tscriptname | sed -e "s/${PN}\-//" -e 's/\-[^\-]*$//'`
PR=`echo $tscriptname | sed -e "s/${PN}\-${PV}\-//"`
PVR=${PV}-${PR}

PVP=(${PV//[-\._]/ })
PV_MAJ_MIN="${PVP[0]}.${PVP[1]}"
SLOT=${PVP[0]}${PVP[1]}

PN1=${PN}${SLOT}
PN2=${PN}${SLOT}-devel
PN3=${PN}${SLOT}-doc
PN4=${PN}${SLOT}-misc
P=${PN}-${PV}
P1=${PN1}-${PV}
P2=${PN2}-${PV}
P3=${PN3}-${PV}
P4=${PN4}-${PV}
PF1=${P1}-${PR}
PF2=${P2}-${PR}
PF3=${P3}-${PR}
PF4=${P4}-${PR}

# Package maintainers: if the original source is not distributed as a
# (possibly compressed) tarball, set the value of ${src_orig_pkg_name},
# and redefine the unpack() helper function appropriately.
#
# determine correct decompression option and tarball filename
src_orig_pkg_name=
if [ -e "${src_orig_pkg_name}" ] ; then
	opt_decomp=? # Make sure tar punts if unpack() is not redefined
elif [ -e ${P}.tar.bz2 ] ; then
	opt_decomp=j
	src_orig_pkg_name=${P}.tar.bz2
elif [ -e ${P}.tar.gz ] ; then
	opt_decomp=z
	src_orig_pkg_name=${P}.tar.gz
elif [ -e ${P}.tgz ] ; then
	opt_decomp=z
	src_orig_pkg_name=${P}.tgz
elif [ -e ${P}.tar ] ; then
	opt_decomp=
	src_orig_pkg_name=${P}.tar
else
	echo Cannot find original package.
fi

src_orig_pkg=${T}/${src_orig_pkg_name}

# determine correct names for generated files
src_pkg_name=${PF1}-src.tar.bz2
src_patch_name=${PF1}.patch
bin_pkg1_name=${PF1}.tar.bz2
bin_pkg2_name=${PF2}.tar.bz2
bin_pkg3_name=${PF3}.tar.bz2
bin_pkg4_name=${PF4}.tar.bz2
src_pkg=${T}/${src_pkg_name}
src_patch=${T}/${src_patch_name}
bin_pkg1=${T}/${bin_pkg1_name}
bin_pkg2=${T}/${bin_pkg2_name}
bin_pkg3=${T}/${bin_pkg3_name}
bin_pkg4=${T}/${bin_pkg4_name}

S=${T}/${P}
B=${S}/.build
D=${S}/.inst
C=${S}/CYGWIN-PATCHES
srcinstdir=${S}/.sinst
checkfile=${T}/${PF1}.check

MY_CFLAGS="-O2 -pipe"
MY_LDFLAGS=""
MAKEOPTS="-j2"
SIG=1
MULTIPKG=0

install_docs="\
	ABOUT-NLS \
	ANNOUNCE \
	ANNOUNCEMENTS \
	AUTHOR \
	AUTHORS \
	BUG-REPORTS \
	BUGS \
	Changes \
	ChangeLog \
	CONTRIBUTORS \
	COPYING \
	COPYING-DOCS \
	COPYING.LIB \
	COPYRIGHT \
	CREDITS \
	FAQ \
	GPL \
	HACKING \
	HOW-TO-CONTRIBUTE \
	INSTALL \
	KNOWNBUG \
	LEGAL \
	LICENCE \
	LICENSE \
	MAINTAINERS \
	NEWS \
	NLS \
	NOTES \
	PROGLIST \
	README \
	THANKS \
	TODO \
	WHATSNEW \
"

install_html=""

# helper function
# unpacks the original package source archive into ./${P}/
# change this if the original package was not tarred
# or if it doesn't unpack to a correct directory
unpack() {
	tar xv${opt_decomp}f "$@"
}

dodir() {
	for d in "$@" ; do
		mkdir -p ${D}/${d} ;
	done
}

doicon() {
	dodir /usr/share/pixmaps
	for i in "$@" ; do
		/bin/install -m 644 ${i} ${D}/usr/share/pixmaps ;
	done
}

make_desktop() {
	dodir /usr/share/applications

	echo "[Desktop Entry]
Encoding=UTF-8
Version=0.9.2
Name=${2}
Type=Application
Comment=${5}
Exec=${1}
Path=
Icon=${3}
Categories=Application;${4};" > ${D}/usr/share/applications/${1}.desktop
}

mkdirs() {
	cd ${T}
	rm -fr ${B} ${D} ${srcinstdir}
	mkdir -p ${B} ${D} ${srcinstdir} ${C}
}

getsrc() {
	PVP=(${PV//[-\._]/ })
	wget http://ftp.gnome.org/pub/gnome/sources/${PN}/${PVP[0]}.${PVP[1]}/${P}.tar.bz2 || exit 1
}

prepsrc() {
	cd ${T}
	unpack ${src_orig_pkg}
	if [ -f ${src_patch} ] ; then
		patch -Z -p0 < ${src_patch} || exit 1
	fi
	mkdirs
}

# Run this to re-autotool AFTER editing configure.{ac,in}/Makefile.am
autotool() {
	cd ${S}
	if [ -f ${S}/intltool-merge.in ] ; then
		intltoolize -c -f
	fi
	/usr/bin/autoreconf --install --force --verbose || exit 1
	cd ${T}
	if [ -f ${P}/INSTALL ] ; then
		unpack ${src_orig_pkg} ${P}/INSTALL ${P}/COPYING
	fi
}

cygconf() {
	cd ${B}
	export ac_cv_func_mmap_fixed_mapped=yes
	CFLAGS="${MY_CFLAGS}" CXXFLAGS="${MY_CFLAGS}" LDFLAGS="${MY_LDFLAGS}" \
	${S}/configure \
		--srcdir="${S}" \
		--sysconfdir=/etc \
		--prefix=/usr \
		--exec-prefix=/usr \
		--bindir=/usr/bin \
		--includedir=/usr/include \
		--libdir=/usr/lib \
		--libexecdir=/usr/sbin \
		--sbindir=/usr/sbin \
		--datadir=/usr/share \
		--infodir=/usr/share/info \
		--mandir=/usr/share/man \
		--localstatedir=/var/lib \
		--enable-gtk-doc \
		--disable-schemas-install \
		--disable-scrollkeeper \
		|| exit 1
}

reconf() {
	cd ${T}
	rm -fr ${B}
	mkdir -p ${B}
	cygconf
}

cygmake() {
	cd ${B}
	make ${MAKEOPTS} || exit 1
}

check() {
	cd ${B}
	if [ -f ${S}/Makefile.am ] ; then
		make check | tee ${checkfile} 2>&1
	else
		make test | tee ${checkfile} 2>&1
	fi
}

clean() {
	cd ${B} && make clean || exit 1
}

cyginstall() {
	rm -fr ${D}/*
	cd ${B}
	find . -name '*.la' | xargs -r sed -i -e 's:^relink_command=.*::'
	find . -type f | xargs touch -t `date +%Y%m%d%H%M.%S`
	make install DESTDIR=${D} || exit 1
	rm -fr ${D}/var/lib/scrollkeeper
}

cygdoc() {
	cd ${S}
	dodir /usr/share/doc/Cygwin
	dodir /usr/share/doc/${P1}

	for f in ${install_docs} ; do
		if [ -f ${S}/${f} ] ; then
			/bin/install -m 644 ${S}/${f} ${D}/usr/share/doc/${P1} ;
		fi
	done

	for f in ${install_html} ; do
		if [ -f ${S}/${f} ] ; then
			if [ ! -d ${D}/usr/share/doc/${P1}/html ] ; then
				dodir /usr/share/doc/${P1}/html
			fi
			/bin/install -m 644 ${S}/${f} ${D}/usr/share/doc/${P1}/html ;
		fi
	done

	if [ -f ${C}/README ] ; then
		/bin/install -m 644 ${C}/README \
			${D}/usr/share/doc/Cygwin/${P1}.README ;
	fi

	for f in ${PN1} ${PN2} ${PN3} ${PN4} ; do
		if [ -f ${C}/${f}.README ] ; then
			/bin/install -m 644 ${C}/${f}.README \
				${D}/usr/share/doc/Cygwin/${f}.README ;
		fi ;
	done
}

cygetc() {
	cd ${S}
	for s in postinstall preremove profile.d ; do
		if [ -f ${C}/${s}.sh ] ; then
			dodir /etc/${s}
			/bin/install -m 755 ${C}/${s}.sh ${D}/etc/${s}/${PN1}.sh
		fi
	done

	if [ -f ${C}/profile.d.csh ] ; then
		dodir /etc/profile.d
		/bin/install -m 755 ${C}/profile.d.csh \
			${D}/etc/profile.d/${PN1}.csh
	fi

	if [ -d ${D}/etc/gconf/schemas ] ; then
		dodir /etc/postinstall /etc/preremove
		cat >> ${D}/etc/postinstall/${PN1}.sh <<_EOF
/bin/kill -SIGKILL \$(pidof /usr/sbin/gconfd-2)
/bin/rm -fr \$TMP/gconfd-*

_EOF
		cat >> ${D}/etc/preremove/${PN1}.sh <<_EOF
/bin/kill -SIGKILL \$(pidof /usr/sbin/gconfd-2)
/bin/rm -fr \$TMP/gconfd-*

_EOF
		for f in ${D}/etc/gconf/schemas/*.schemas ; do
			cat >> ${D}/etc/postinstall/${PN1}.sh <<_EOF
GCONF_CONFIG_SOURCE="xml::/etc/gconf/gconf.xml.defaults" \
	/usr/bin/gconftool-2 --makefile-install-rule \
	/etc/gconf/schemas/`basename $f` > /dev/null 2>&1
_EOF
			cat >> ${D}/etc/preremove/${PN1}.sh <<_EOF
GCONF_CONFIG_SOURCE="xml::/etc/gconf/gconf.xml.defaults" \
	/usr/bin/gconftool-2 --makefile-uninstall-rule \
	/etc/gconf/schemas/`basename $f` > /dev/null 2>&1
_EOF
		done
	fi

	if [ -d ${D}/usr/share/omf ] ; then
		dodir /etc/postinstall
		echo 'scrollkeeper-update -p /var/lib/scrollkeeper > /dev/null 2>&1' \
			>> ${D}/etc/postinstall/${PN1}.sh
	fi

	if [ -d ${D}/usr/share/mime ] ; then
		for f in aliases globs magic subclasses XMLnamespaces ; do
			rm -f ${D}/usr/share/mime/$f
		done
		dodir /etc/postinstall
		echo 'update-mime-database /usr/share/mime' \
			>> ${D}/etc/postinstall/${PN1}.sh
	fi

	if [ -f ${D}/etc/postinstall/${PN1}.sh ] ; then
		chmod a+x ${D}/etc/postinstall/${PN1}.sh
	fi
}

prepallinfo() {
	cd ${D}
	for f in /usr/share/info/dir /usr/info/dir ; do \
		if [ -f ${D}${f} ] ; then
			rm -f ${D}${f}
		fi
	done
	if [ -d ${D}/usr/share/info ] ; then
		echo "gzipping info pages:"
		for i in `find usr/share/info -type f ! -name "*.gz"` ; do
			echo "        `basename $i`" ;
			gzip -q $i ;
		done
	fi
}

prepallman() {
	cd ${D}
	if [ -d ${D}/usr/share/man ] ; then
		echo "gzipping man pages:"
		for m in `find usr/share/man -type f ! -name "*.gz"` ; do
			echo "        `basename $m`" ;
			gzip -q $m ;
		done ;
	fi
}

prepstrip() {
	cd ${D}
	echo "Stripping executables:"
	for e in `find * -name "*.dll" -or -name "*.exe"` ; do
		echo "        $e" ;
		strip $e 2>&1 ;
	done
}

list_files() {
	cd ${D}
	find . -name "*" ! -type d | sed 's%^\.%  %'
	true
}

list_deps() {
	cd ${D}
	export PATH="${D}/usr/bin:$PATH"
	find . -name "*.exe" -o -name "*.dll" | xargs -r cygcheck | \
		sed -ne '/^  [^ ]/ s,\\,/,gp' | sort -bu | \
		xargs -r -n1 cygpath -u | xargs -r cygcheck -f | \
		sed 's%^%  %' | sort -u ; \
	true
}

cygpkg() {
	cd ${D}
	tar cvjf ${bin_pkg1} \
		--exclude="usr/bin/*-config" \
		--exclude="usr/include" \
		--exclude="usr/lib" \
		--exclude="usr/share/gtk-doc" \
		*
	echo
	tar cvjf ${bin_pkg2} \
		usr/bin/*-config \
		usr/include/ \
		usr/lib/
	echo
#	tar cvjf ${bin_pkg3} \
#		usr/share/gtk-doc
#	echo
}

mkpatch() {
	cd ${S}
	unpack ${src_orig_pkg}
	mv ${P} ../${P}-orig
	cd ${T}
	rm -f ${srcinstdir}/${src_patch_name}
	diff -urN -x '.build' -x '.inst' -x '.sinst' -x 'configure' \
		-x 'Makefile.in*' -x 'aclocal.m4*' -x 'ltmain.sh' -x 'config.*' \
		-x 'depcomp' -x 'install-sh' -x 'missing' -x 'mkinstalldirs' \
		-x 'intltool*' -x 'autom4te.cache' -x '*compile' \
		-x '*stamp' -x '*html' -x '*sgml' -x '*tmpl' -x '*txt' -x '*xml' \
		${P}-orig ${P} > ${srcinstdir}/${src_patch_name} ;
	rm -rf ${P}-orig
}

cygspkg() {
	mkpatch
	if [ "${SIG}" -eq 1 ] ; then
		name=${srcinstdir}/${src_patch_name} text="PATCH" sigfile
	fi
	cp ${src_orig_pkg} ${srcinstdir}/${src_orig_pkg_name}
	if [ -e ${src_orig_pkg}.sig ] ; then
		cp ${src_orig_pkg}.sig ${srcinstdir}/
	fi
	cp $0 ${srcinstdir}/`basename $0`
	name=$0 text="SCRIPT" sigfile
	if [ "${SIG}" -eq 1 ] ; then
		cp $0.sig ${srcinstdir}/
	fi
	cd ${srcinstdir}
	tar cvjf ${src_pkg} *
}

dist() {
	cd ${T}
	mkdir -p ${T}/${PN1}
	cp ${src_pkg} ${T}/${PN1}
	mv ${bin_pkg1} ${T}/${PN1}
	cp ${C}/setup.hint ${T}/${PN1}/setup.hint

	if [ -f ${bin_pkg2} ] ; then
		mkdir -p ${T}/${PN1}/${PN2}
		mv ${bin_pkg2} ${T}/${PN1}/${PN2}
		cp ${C}/devel.hint ${T}/${PN1}/${PN2}/setup.hint
	fi

	if [ -f ${bin_pkg3} ] ; then
		mkdir -p ${T}/${PN1}/${PN3}
		mv ${bin_pkg3} ${T}/${PN1}/${PN3}
		cp ${C}/doc.hint ${T}/${PN1}/${PN3}/setup.hint
	fi

	if [ -f ${bin_pkg4} ] ; then
		mkdir -p ${T}/${PN1}/${PN4}
		mv ${bin_pkg4} ${T}/${PN1}/${PN4}
		cp ${C}/misc.hint ${T}/${PN1}/${PN4}/setup.hint
	fi
}

finish() {
	rm -rf ${S}
}

cleandir() {
	rm -fr ${src_orig_pkg} ${src_orig_pkg}.sig $0.sig ${src_patch} \
	${src_patch}.sig
	finish
}

sigfile() {
	if [ \( "${SIG}" -eq 1 \) -a \( -e $name \) -a \( \( ! -e $name.sig \) -o \( $name -nt $name.sig \) \) ] ; then
		if [ -x /usr/bin/gpg ] ; then
			echo "$text signature needs to be updated"
			rm -f $name.sig
			/usr/bin/gpg --detach-sign $name
		else \
			echo "You need the gnupg package installed in order to make signatures."
		fi
	fi
}

checksig() {
	if [ -x /usr/bin/gpg ] ; then
		if [ -e ${src_orig_pkg}.sig ] ; then
			echo "ORIGINAL PACKAGE signature follows:"
			/usr/bin/gpg --verify ${src_orig_pkg}.sig ${src_orig_pkg}
		else \
			echo "ORIGINAL PACKAGE signature missing."
		fi
		if [ -e $0.sig ] ; then
			echo "SCRIPT signature follows:"
			/usr/bin/gpg --verify $0.sig $0
		else \
			echo "SCRIPT signature missing."
		fi
		if [ -e ${src_patch}.sig ] ; then
			echo "PATCH signature follows:"
			/usr/bin/gpg --verify ${src_patch}.sig ${src_patch}
		else \
			echo "PATCH signature missing."
		fi
	else
		echo "You need the gnupg package installed in order to check signatures."
	fi
}

while test -n "$1" ; do
	case $1 in
		download|wget|get)
			getsrc ; STATUS=$? ;;
		prep|unpack)
			prepsrc ; STATUS=$? ;;
		mkdirs)
			mkdirs ; STATUS=$? ;;
		auto*)
			autotool ; STATUS=$? ;;
		conf*)
			cygconf ; STATUS=$? ;;
		reconf)
			reconf ; STATUS=$? ;;
		build|make)
			cygmake ; STATUS=$? ;;
		compile)
			autotool && cygconf && cygmake ; STATUS=$? ;;
		check|test)
			check ; STATUS=$? ;;
		clean)
			clean ; STATUS=$? ;;
		inst*)
			cyginstall && cygdoc && cygetc && \
			prepallinfo && prepallman && prepstrip ; STATUS=$? ;;
		list)
			list_files ; STATUS=$? ;;
		dep*)
			list_deps ; STATUS=$? ;;
		strip)
			prepstrip ; STATUS=$? ;;
		package|pkg)
			cygpkg ; STATUS=$? ;;
		mkpatch)
			mkpatch ; STATUS=$? ;;
		src-package|spkg)
			cygspkg ; STATUS=$? ;;
		dist)
			dist ; STATUS=$? ;;
		finish)
			finish ; STATUS=$? ;;
		checksig)
			checksig ; STATUS=$? ;;
		first|ready)
			mkdirs && cygspkg && finish ; STATUS=$? ;;
		all)
			checksig && prepsrc && autotool && cygconf && cygmake && \
			cyginstall && cygdoc && cygetc && prepallinfo && prepallman && \
			prepstrip && cygpkg && cygspkg && finish ; STATUS=$? ;;
		*)
			echo "Error: bad arguments" ; exit 1 ;;
	esac
	( exit ${STATUS} ) || exit ${STATUS}
	shift
done
