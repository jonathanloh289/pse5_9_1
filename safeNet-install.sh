#! /bin/sh
SHELL=/bin/sh
#SHELL=/bin/bash #Solaris???
export SHELL

# Copyright 2018 SafeNet, Inc.
# All Rights Reserved
#
# Use of this file for any purpose whatsoever is prohibited without the
# prior written consent of Eracom Technologies Australia Pty. Ltd.
#
# File  : eracom-install.sh
# Author: Bob Hepple
#
# This file is provided as part of the SafeNet Protect Toolkit.
#
# (c) Copyright 2004-2018 SafeNet, Inc. All rights reserved.
# This file is protected by laws protecting trade secrets and confidential
# information, as well as copyright laws and international treaties.
#
# SafeNet install/uninstall script for all supported flavours of Unix:
# Use the '-h' option to get help
# Note: 
# #! /bin/sh does not work for Solaris.
# It was replaced with #! /bin/bash
# See also SHELL variable definition
#
###############################################################################
PATH=/usr/sbin:$PATH; export PATH
#PTK 5.0 Only supports Linux and Windows
#PTK 5.1.0 returns AIX and Solaris support
KNOWN_OS_DIRS="AIX HP-UX Linux Linux64 Solaris SolarisX86"
#KNOWN_OS_DIRS="AIX Linux Linux64 Solaris SolarisX86"

# Set this to turn on some debugging:
DEBUG=""
trace_debug() {
	if [ "$DEBUG" ]; then
		echo ${1+"$@"} pwd=`pwd` >&2
	fi
}

chop() {
	sed -e "s/\\(.\\{1,$MAX_SCREEN_WIDTH\}\\).*/\\1/"
}

# Note: use path to echo to eliminate the built-in version:
echo_no_cr_backslash() {
	MSG="$1\\c"
	$ECHO "$MSG"
}

echo_no_cr_n() {
	$ECHO -n "$1"
}

tput_output() {
	if [ "$ENABLE_TPUT" ]; then
		OUTPUT=`tput $@ 2>/dev/null`
		if [ $? -eq 0 -a -n "$OUTPUT" ]; then
			$ECHO_NO_CR $OUTPUT
		else
			return 1
		fi
	fi
}

print_normal() {
	$ECHO_NO_CR "$@"
}

print_reverse() {
	$ECHO_NO_CR "$START_REVERSE$@$START_NORMAL"
}

print_italic() {
	$ECHO_NO_CR "$START_ITALIC$@$START_NORMAL"
}

print_bold() {
	$ECHO_NO_CR "$START_BOLD$@$START_NORMAL"
}

print_alarm() {
	$ECHO_NO_CR "$START_ALARM$@$START_NORMAL"
}

print_menu_letter() {
	$ECHO_NO_CR "$START_ALARM$@$START_NORMAL"
}

print_blink() {
	$ECHO_NO_CR "$START_BLINK$@$START_NORMAL"
}

clear_last_line() {
	tput_output cuu1
	tput_output ed
}

press_enter() {
	print_reverse "type enter to continue:"
	print_normal " "
	read I
	I=`echo $I| $TR '[A-Z]' '[a-z]'`
	if [ "$I" = "q" ]; then
		exit 0
	fi
	clear_last_line
}

skip_lines() {
	echo
	I="$1"
	while [ "$I" -lt "$SCREEN_HEIGHT" ]; do
		I=`expr "$I" + 1`
		echo
	done
}

wait_over() {
	echo " ... done"
}

please_wait() {
	MSG=${1+"$@"}
	if [ -z "$MSG" ]; then
		MSG="working"
	fi
	print_normal "$MSG ... please wait"
}

confirm() {
	while true; do
		print_reverse "$1"
		echo
		print_normal "[y or n]? "
		read CONFIRM
		CONFIRM=`echo $CONFIRM |$TR '[A-Z]' '[a-z]'`
		clear_last_line
		case $CONFIRM in
			"y*") CONFIRM="y";;
			"n*") CONFIRM="n";;
		esac
		if [ "$CONFIRM" = "y" -o "$CONFIRM" = "n" ]; then
			return
		fi
	done
}

do_main_title() {
	print_bold "$TITLE"
	echo
	echo "$SUBTITLE"
	echo ${1+"$@"}
	echo
	return 4
}

get_input() {
	DEFAULT="$1"
	shift
	LEGALINPUT=${1+"$@"}
	
	while true; do
		print_normal "Choice "
		print_menu_letter "($LEGALINPUT)"
		print_normal " [$DEFAULT]:"
		print_normal " "
		read INVAL
		INVAL=`echo $INVAL |$TR '[A-Z]' '[a-z]'`
		if [ -z "$INVAL" ]; then
			INVAL="$DEFAULT"
			clear_last_line
			return
		fi
		for IN in $LEGALINPUT; do
			if [ "$INVAL" = "$IN" ]; then
				clear_last_line
				return
			fi
		done
		INVAL=$DEFAULT
	done
}

show_command() {
	if [ "$EXEC" = "test_mode" ]; then
		echo "If we weren't in test mode we would be running:"
		echo $COMMAND
	else
		echo "Now running the following command:"
		echo $COMMAND
	fi
}

mod_command_for_test() {
	if [ "$EXEC" = "test_mode" ]; then
		COMMAND="echo $COMMAND"
	fi
}

must_be_root() {
	if [ `$IDPROG -u` -ne 0 ]; then
		echo "$PROG: you must be root to run this"
		exit 1
	fi
}


guess_package_name() {
	case $1 in
		ERACe8k*|devices.pci.11106510*) 
			echo "SafeNet PCI HSM Device Driver";;
	   	ERACecsa*|devices.pci.e810bc80*) 
			echo "ProtectServer Blue (CSA7000) Device Driver";;
		ERACcprov*) 
			echo "ProtectToolkit C Runtime (PS Blue)";;
		ERACcp8k*) 
			echo "ProtectToolkit C Runtime (PS Orange)";;
		ERACcprc*) 
			echo "ProtectToolkit C Remote Client Runtime";;
		ERACcpsw*) 
			echo "ProtectToolkit C SDK Software";;
		ERACcpsdk*) 
			echo "ProtectToolkit C Software Development Kit";;
		ERACjprov* ) 
			echo "ProtectToolkit J Runtime";;
		ERACjpsdk* ) 
			echo "ProtectToolkit J Software Development Kit";;
		ERACtoeft*) 
			echo "ProtectToolkit C Orange EFT";;
		ETptkeftw*) 
			echo "ProtectToolkit C White EFT";;
		ERACpenc*) 
			echo "Pin Encryption Software Development Kit";;
		ETlhsm*|ETpcihsm*)
			echo "SafeNet PCI HSM Device Driver";;
		ETrhsm*|ETnethsm*)
			echo "Remote Client HSM Access Provider";;
		ETnetsrv*)
			echo "HSM Net Server";;
		ETcprt-sdk*)
			echo "ProtectToolkit C SDK Runtime";;
		ETcprt*)
			echo "ProtectToolkit C Runtime";;
		ETcpsw*)
			echo "ProtectToolkit C SDK Software";;
		ETcpsdk*)
			echo "ProtectToolkit C SDK";;
		ETppohdk*)
		    echo "ProtectProcessing Orange HDK";;
		devices.pci.11106510*)
			echo "SafeNet PCI HSM Device Driver";;
		devices.pci.e810bc80*)
			echo "ProtectServer Blue (CSA7000) Device Driver";;

	# PTk 5 packages

		PTKnethsm*)
			echo "SafeNet Network HSM Access Provider";;
		PTKnetsrv*)
			echo "SafeNet HSM Net Server";;
		PTKcpsw-sdk*)
			echo "SafeNet ProtectToolkit C SDK Software";;
		PTKcprt-sdk*)
			echo "SafeNet ProtectToolkit C SDK Runtime";;
		PTKcprt*)
			echo "SafeNet ProtectToolkit C Runtime";;
		PTKcpsdk*)
			echo "SafeNet ProtectToolkit C SDK";;
		PTKjprov*) 
			echo "SafeNet ProtectToolkit J Runtime";;
		PTKjpsdk*) 
			echo "SafeNet ProtectToolkit J Software Development Kit";;
		PTKpcihsmK6*)
			echo "SafeNet PCIe HSM Access Provider (Device Driver)";;
		PTKpcihsmK5*)
			echo "SafeNet PSI-E HSM Access Provider (Device Driver)";;
		PTKfmsdk*)
			echo "SafeNet ProtectToolkit FM SDK";;
		fm-toolchain*)
			FM_ARCH=`echo $1|cut -d '-' -f 3`
			if [ "_$FM_ARCH" = "_ppc440e" ]; then FM_ARCH="PPC"; fi
			echo "SafeNet $FM_ARCH FM Toolchain";;

	# Unknown
		*)
			echo "($1)"
		esac
}

# pwd is ./
guess_packages() {
	trace_debug "guess_packages($1)"
	OS_DIRS=`ls_known_oss`

	for OS in $OS_DIRS; do 
		if [ -d "$OS" ]; then 
			(
				cd "$OS"
				echo "$OS:"
				for DIR in *; do
					if [ -d "$DIR" ]; then
						PKG=`cd "$DIR"; ls -1 |egrep "^ERAC|^ET|^PTK|^fm-toolchain|^devices" 2>/dev/null | fgrep -v .sig | ${FIRSTLINE}`
						if [ -z "$PKG" ]; then
							continue
						fi
						guess_package_name $PKG
					fi
				done
				echo
			)
		fi
	done
}

# METHODS:
# The build_install_command_* methods are called with "PKG~VERSION~DESCRIPTION"
# ... PKG is the _directory_ containing the package installation file
# The build_uninstall_command_* methods are called with "PKG~VERSION~DESCRIPTION"
# ... PKG is the machine-readable package name eg. ERACcp8k
# The list_installed_* methods must print "PKG~VERSION~DESCRIPTION"

# pwd is $OS
# no args
list_installed_Linux() {
	PACKAGES=`rpm -qa|egrep '^ET|^ERAC|^PTK|^fm-toolchain'`
	if [ -z "$PACKAGES" ]; then
		return
	fi
	for PKG in $PACKAGES; do
		VERSION=`rpm -q --qf "%{VERSION}" $PKG | sed 's/~/-/g'`
		DESC=`rpm -q --qf "%{SUMMARY}" $PKG | sed 's/~/-/g'`
		echo "nil~$PKG~$VERSION~$DESC"
	done
}
list_installed_Linux64() {
    list_installed_Linux
}

# pwd is $OS
# $1 is directory to list
list_cd_Linux() {
	DIR="$1"

	PKGFILE=`cd "$DIR"; ls -1 *.rpm 2>/dev/null |${FIRSTLINE}`
	if [ -z "$PKGFILE" ]; then
		return
	fi
	PKGFILE="$DIR/$PKGFILE"
	NAME=`rpm -qp --qf "%{NAME}" $PKGFILE | sed 's/~/-/g'`
	VERSION=`rpm -qp --qf "%{VERSION}" $PKGFILE | sed 's/~/-/g'`
	DESC=`rpm -qp --qf "%{SUMMARY}" $PKGFILE | sed 's/~/-/g'`
	echo "$DIR~$NAME~$VERSION~$DESC"
}
list_cd_Linux64() {
	list_cd_Linux "$@"
	}

# pwd=./$OSNAME
# $1 is DIR
# $2 is PKG
build_install_command_Linux() {
	DIR="$1"
	PKG="$2"
	COMMAND="$INSTALL_PROGRAM -U $EXTRA_OPTIONS $DIR/$PKG*.rpm"
	case $PKG in
		PTKpcihsmK6*)
		#   unset ARCH to avoid a mismatch with the installed kernel
		POSTINSTALL="env --unset=ARCH /opt/safenet/protecttoolkit5/pcihsm2/driver/vkd-install.sh"
		;;
	esac
}
build_install_command_Linux64() {
	build_install_command_Linux "$@"
}


# $1 is DIR
# $2 is PKG
build_uninstall_command_Linux() {
	DIR="$1"
	PKG="$2"
	COMMAND="$UNINSTALL_PROGRAM -e $EXTRA_OPTIONS $PKG"
	case $PKG in
		PTKpcihsmK6*)
		# uninstall the vkd driver too
		PREUNINSTALL="/opt/safenet/protecttoolkit5/pcihsm2/driver/vkd-uninstall.sh"
		;;
	esac
}

build_uninstall_command_Linux64() {
	build_uninstall_command_Linux "$@"
}

# SOLARIS METHODS

# pwd is $OS
# no args
list_installed_Solaris() {
	PACKAGES=`pkginfo | $AWK '{print $2}' | egrep '^ET|^ERAC|^PTK'`
	if [ -z "$PACKAGES" ]; then
		return
	fi
    #echo "PACKAGES: " $PACKAGES > ./packages.lst
	for PKG in $PACKAGES; do
		print_normal "nil~"
		pkginfo -l $PKG |$AWK '
			/VERSION:/   {$1=""; gsub(/[^-0-9.]/,"",$0); gsub(/~/,"-",$0); V=$0}
			/DESC:/      {$1=""; sub(/^ +/,"",$0); gsub(/~/,"-",$0); D=$0}
			/PKGINST:/   {$1=""; sub(/^ +/,"",$0); gsub(/~/,"-",$0); P=$0}
			END { printf "%s~%s~%s~\n", P, V, D }'
	done
}

# pwd is $OS
# For SolarisX86
# $1 is directory to list
list_cd_Solaris() {
	DIR="$1"
    #echo "PACKAGES: " $DIR > ./list_cd.lst
	PKGFILE=`cd "$DIR"; ls -1 *.pkg 2>/dev/null | ${FIRSTLINE}`
    #echo "PKGFILE: " $PKGFILE >> ./list_cd.lst
	if [ -z "$PKGFILE" ]; then
		PKGDIR=`cd "$DIR"; ls -1 2>/dev/null | fgrep -v .sig | ${FIRSTLINE}` # pickup directory
	fi
	if [ -z "$PKGFILE" ]; then
		if [ -z "$PKGDIR" ]; then
			return
		fi
	fi

	P=`pwd`
    #echo "P: " $P >> ./list_cd.lst
	RAW_INFO=`if [ "$PKGFILE" ]; then pkginfo -l -d "$P/$DIR/$PKGFILE" ; else pkginfo -l -d "$P/$DIR" "$PKGDIR"; fi 2>/dev/null`
    #echo "RAW_INFO: " $RAW_INFO  >> ./list_cd.lst
	if [ $? -eq 0 ]; then
		print_normal "$DIR~"
		echo "$RAW_INFO" |$AWK '
			/VERSION:/   {$1=""; gsub(/[^-0-9.]/,"",$0); gsub(/~/,"-",$0); V=$0}
			/DESC:/      {$1=""; sub(/^ +/,"",$0); gsub(/~/,"-",$0); D=$0}
			/PKGINST:/   {$1=""; sub(/^ +/,"",$0); gsub(/~/,"-",$0); P=$0}
			END { printf "%s~%s~%s~\n", P, V, D }'
	fi
}

# pwd=./$OSNAME
# $1 is DIR
# $2 is PKG
build_install_command_Solaris() {
	DIR="$1"
	PKG="$2"
	COMMAND="$INSTALL_PROGRAM $EXTRA_OPTIONS -d `pwd`/$DIR/$PKG.pkg"
}

# pwd=./
# $1 is DIR
# $2 is PKG
build_uninstall_command_Solaris() {
	DIR="$1"
	PKG="$2"

	COMMAND="$UNINSTALL_PROGRAM $EXTRA_OPTIONS $PKG"
}

# AIX METHODS

# pwd is $OS
# no args
list_installed_AIX() {
	lslpp -L -c all |egrep '^ERAC|^ET|^PTK|^devices.pci.11106510|^devices.pci.e810bc80' | while read DATA; do
		SAVE_IFS=$IFS
		IFS=':'
		set -- $DATA
		PKG=`echo "$1" | sed 's/~/-/g'`
		VERSION=`echo "$3"| sed 's/~/-/g'`
		DESCRIPTION=`echo "${8}"| sed 's/~/-/g'`
		IFS=$SAVE_IFS
		echo "nil~$PKG~$VERSION~$DESCRIPTION"
	done
}

# pwd is $OS
# $1 is directory to list
list_cd_AIX() {
	trace_debug "list_cd_AIX(${1+"$@"})"
	DIR="$1"

	PKGFILE=`cd $DIR; ls -1 *.bff 2>/dev/null |${FIRSTLINE}`
	if [ -z "$PKGFILE" ]; then
		return
	fi
	DATA=`installp -L -d $DIR/$PKGFILE`
	SAVE_IFS=$IFS
	IFS=':'
	set -- $DATA
	PKG=`echo "$1" | sed 's/~/-/g'`
	VERSION=`echo "$3"| sed 's/~/-/g'`
	DESCRIPTION=`echo "${12}"| sed 's/~/-/g'`
	IFS=$SAVE_IFS
	echo "$DIR~$PKG~$VERSION~$DESCRIPTION"
}

# pwd=./$OSNAME
# $1 is DIR
# $2 is PKG
build_install_command_AIX() {
	DIR="$1"
	PKG="$2"
	COMMAND="$INSTALL_PROGRAM $EXTRA_OPTIONS -acgNQqwX -d `pwd`/$DIR/$PKG.bff $PKG.rte"
	case $PKG in
		ETpcihsm*|devices*) POSTINSTALL="cfgmgr";;
	esac
}

# pwd=./
# $1 is DIR
# $2 is PKG
build_uninstall_command_AIX() {
	DIR="$1"
	PKG="$2"

	COMMAND="$INSTALL_PROGRAM $EXTRA_OPTIONS -u $PKG"
}

# HPUX METHODS

# pwd is $OS
# no args
list_installed_HPUX() {
	# Assumes VERSION contains no spaces ....

	swlist | egrep '^  (ERAC|ET|PTK)' | $AWK '{P=$1; V=$2; $1=""; $2=""; gsub("^ +", ""); printf "nil~%s~%s~%s~\n", P, V, $0 }'
}

# pwd is $OS
# $1 is directory to list
list_cd_HPUX() {
	trace_debug "list_cd_HPUX(${1+"$@"})"
	DIR="$1"

	PKGFILE=`cd "$DIR"; ls -1 *.depot 2>/dev/null |${FIRSTLINE}`
	if [ -z "$PKGFILE" ]; then
		return
	fi
	swlist -s `pwd`/$DIR/$PKGFILE |egrep '^  (ERAC|ET|PTK)' |$AWK '{P=$1; V=$2; $1=""; $2=""; gsub("^ +", ""); printf "'"$DIR"'~%s~%s~%s~\n", P, V, $0 }'
}

# pwd=./$OSNAME
# $1 is DIR
# $2 is PKG
# swinstall fails if the depot file is on a NFS mounted system. In this case,
# copy it to /tmp and hope _that_ is not NFS mounted.
build_install_command_HPUX() {
	trace_debug "build_install_command_HPUX(${1+"$@"})"
	DIR="$1"
	PKG="$2"
	DEPOTFILE=`cd "$DIR"; ls -1 *.depot 2>/dev/null | ${FIRSTLINE}`
	DEPOTDIR="`pwd`/$DIR"

	# is the installation file on an NFS volume?
	if ! df "$DEPOTDIR" | $AWK '{print $1}' |grep ":" >/dev/null; then
		# the depot file is NFS mounted
		cp "$DEPOTDIR/$DEPOTFILE" "/tmp/$DEPOTFILE"
		DEPOTDIR="/tmp"
	fi
	#Configure swinstall command:
	COMMAND="$INSTALL_PROGRAM $EXTRA_OPTIONS -s $DEPOTDIR/$DEPOTFILE $PKG"
}

# pwd=./$OSNAME
# $1 is DIR
# $2 is PKG
cleanup_HPUX() {
	DIR="$1"
	PKG="$2"
	DEPOTFILE=`cd "$DIR"; ls -1 *.depot 2>/dev/null | ${FIRSTLINE}`
	DEPOTDIR="`pwd`/$DIR"

	# was the installation file on an NFS volume?
	if ! df "$DEPOTDIR" | $AWK '{print $1}' |grep ":" >/dev/null; then
		# the depot file was NFS mounted
		rm "/tmp/$DEPOTFILE"
	fi
}

# pwd=./
# $1 is DIR
# $2 is PKG
build_uninstall_command_HPUX() {
	DIR="$1"
	PKG="$2"
	COMMAND="$UNINSTALL_PROGRAM $EXTRA_OPTIONS $PKG"
}

# UnixWare METHODS

# pwd is $OS
# no args
list_installed_UnixWare() {
	list_installed_Solaris $@
}

# pwd is $OS
# $1 is directory to list
list_cd_UnixWare() {
	list_cd_Solaris $@
}

# pwd=./$OSNAME
# $1 is DIR
# $2 is PKG
build_install_command_UnixWare() {
	build_install_command_Solaris $@
}

# pwd=./
# $1 is DIR
# $2 is PKG
build_uninstall_command_UnixWare() {
	build_uninstall_command_Solaris $@
}

# OpenServer METHODS

# pwd is $OS
# no args
list_installed_OpenServer() {
	list_installed_Solaris $@
}

# pwd is $OS
# $1 is directory to list
list_cd_OpenServer() {
	list_cd_Solaris $@
}

# pwd=./$OSNAME
# $1 is DIR
# $2 is PKG
build_install_command_OpenServer() {
	build_install_command_Solaris $@
}

# pwd=./
# $1 is DIR
# $2 is PKG
build_uninstall_command_OpenServer() {
	build_uninstall_command_Solaris $@
}

fqn() {
	# return the full filename, removing ./ ../ adding `pwd` if necessary
	FILE="$1"

	# file		dot relative
	# ./file	dot relative
	# ../file	parent relative
	# /file		absolute
	while true; do
		case "$FILE" in
			/* ) 		
		# Remove /./ inside filename:
			while echo "$FILE" |fgrep "/./" >/dev/null 2>&1; do
				FILE=`echo "$FILE" | sed "s/\\/\\.\\//\\//"`
			done
		# Remove /../ inside filename:
			while echo "$FILE" |grep "/[^/][^/]*/\\.\\./" >/dev/null 2>&1; do
				FILE=`echo "$FILE" | sed "s/\\/[^/][^/]*\\/\\.\\.\\//\\//"`
			done
			echo "$FILE"
			exit 0
			;;
			
			*)
			FILE=`pwd`/"$FILE"
			;;
		esac

	done
}

default_hsm_link() {
	set -- $HSM_LINK_LABELS
	for HSM_LINK in $LEGAL_HSM_LINKS; do
		if [ -f "$HSM_LINK" ]; then
			echo $HSM_LINK
			return 0
		fi
		shift
	done
	return 1
}

default_cryptoki() {
	set -- $CRYPTOKI_LABELS
	for CRYPTOKI in $LEGAL_CRYPTOKIS; do
		if [ -f "$CRYPTOKI" ]; then
			echo $CRYPTOKI
			return 0
		fi
		shift
	done
	return 1
}

# makes 
# ln -s /opt/PKG/lib/sparc/libX.so to /opt/PTK/lib/libX.so
# ln -s /opt/PKG/lib/sparc/sparv9/libX.so to /opt/PTK/lib/sparcv9/libX.so
make_links() {
	PKG="$1" # eg cprt/cpsdk/...
	F1="$2"  # eg lib/bin/doc/man
	F2="$3"  # eg sparc/linux-i386/hpux-pa/hpux-ia64/aix-ppc or ""
	F3="$4"  # eg sparcv9/64 or ""
	#For 32 bits:
	if [ -d ${BASENAME}/${PKG}/$F1/$F2 ] ; then
		mkdir -p ${LINKBASE}/$F1 2>/dev/null
		(
			cd ${BASENAME}/${PKG}/$F1/$F2
			for i in *; do
				if [ ! -d $i ]; then
					if [ ! $LINKTEST ${LINKBASE}/$F1/$i ]; then
						ln -s `pwd`/$i ${LINKBASE}/$F1/$i
					fi
				fi
			done
		)
	fi
	# For 64 bits:
	if [ "$F2" -a "$F3" -a -d "${BASENAME}/${PKG}/$F1/$F2/$F3" ] ; then
		mkdir -p ${LINKBASE}/$F1/$F3 2>/dev/null
		(
			cd "${BASENAME}/${PKG}/$F1/$F2/$F3"
			for i in *; do
				if [ ! -d $i ]; then
					if [ ! $LINKTEST "${LINKBASE}/$F1/$F3/$i" ]; then
						ln -s `pwd`/$i "${LINKBASE}/$F1/$F3/$i"
					fi
				fi
			done
		)
	fi
}

check_links() {
	# Remove any dead symbolic links:
	if [ -d "$LINKBASE" ]; then
		find $LINKBASE | while read LINK; do
			if [ $LINKTEST "$LINK" ]; then
				if follow_link $LINK >/dev/null 2>&1; then
					:
				else
					rm -f $LINK
				fi
			fi
		done
	fi

	# remove any empty directories:
	DONE=""
	while [ -d "$LINKBASE" -a -z "$DONE" ]; do
		DONE="yes"
		find $LINKBASE | while read LINK; do
			if [ -d "$LINK" ]; then
				rmdir "$LINK" >/dev/null 2>&1
				if [ $? -eq 0 ]; then
					DONE=""
				fi
			fi
		done
	done

	rmdir $LINKBASE >/dev/null 2>&1

	CRYPTOKI=`default_cryptoki`
 	if [ $CRYPTOKI ]; then # there is at least one cryptoki available
		CURRENT_CRYPTOKI=`follow_link $DEFAULT_CRYPTOKI_LINK`
		if [ "$CURRENT_CRYPTOKI" ]; then
			# all is well
			:
		else
			DIR=`dirname $DEFAULT_CRYPTOKI_LINK`
			mkdir -p $DIR 2>/dev/null
			ln -s $CRYPTOKI $DEFAULT_CRYPTOKI_LINK

			if [ "$LIB64" ]; then
				# make sure this link follows the main one:
				rm -f $DEFAULT_CRYPTOKI_LINK64
				F=`basename $CRYPTOKI`
				D=`dirname $CRYPTOKI`
				if [ "$ARCH" = "hpux-ia64" ]; then
					#D has an extra 32 at the end on HP-UX
					D=`dirname $D`
				fi
				if [ -f $D/$LIB64/$F ]; then
					mkdir -p `dirname $DEFAULT_CRYPTOKI_LINK64` 2>/dev/null
					ln -s $D/$LIB64/$F $DEFAULT_CRYPTOKI_LINK64
				fi
			fi
			if [ "$LEGACY" ]; then
				# make sure this link follows the main one:
				rm -f $DEFAULT_CRYPTOKI_LINK_LEGACY
				F=`basename $CRYPTOKI`
				D=`dirname $CRYPTOKI`
				if [ -f $D/$LEGACY/$F ]; then
					mkdir -p `dirname $DEFAULT_CRYPTOKI_LINK_LEGACY` 2>/dev/null
					ln -s $D/$LEGACY/$F $DEFAULT_CRYPTOKI_LINK_LEGACY
				fi
			fi
		fi
	fi
	CURRENT_CRYPTOKI=`follow_link $DEFAULT_CRYPTOKI_LINK`

	HSM_LINK=`default_hsm_link`
	if [ "$HSM_LINK" ]; then # there is at least one hsm library available
		CURRENT_HSM_LINK=`follow_link $DEFAULT_HSM_LINK`
		if [ "$DEFAULT_HSM_LINK" ]; then
			# all is well
			:
		else
			DIR=`dirname $DEFALT_HSM_LINK`
			mkdir -p $DIR 2>/dev/null
			ln -s $HSM_LINK $DEFAULT_HSM_LINK
		fi
		if [ "$LIB64" ]; then
			rm -f $DEFAULT_HSM_LINK64
			F=`basename $HSM_LINK`
			D=`dirname $HSM_LINK`
			if [ -f $D/$LIB64/$F ]; then
				mkdir -p `dirname $DEFAULT_HSM_LINK64` 2>/dev/null
				ln -s $D/$LIB64/$F $DEFAULT_HSM_LINK64
			fi
		fi
		if [ "$LEGACY" ]; then
			rm -f $DEFAULT_HSM_LINK_LEGACY
			F=`basename $HSM_LINK`
			D=`dirname $HSM_LINK`
			if [ -f $D/$LEGACY/$F ]; then
				mkdir -p `dirname $DEFAULT_HSM_LINK_LEGACY` 2>/dev/null
				ln -s $D/$LEGACY/$F $DEFAULT_HSM_LINK_LEGACY
			fi
		fi
	fi
	CURRENT_HSM_LINK=`follow_link $DEFAULT_HSM_LINK`

	# Make sure other links are in place - if not, create them for the
	# product containing the default cryptoki eg.
	# /opt/ERACcprc/lib/linux-i386/libctclient.so. These links may be
	# missing eg if remote client and SDK are installed and then SDK
	# removed.

	if [ "$CURRENT_CRYPTOKI" ]; then
		DIR=`dirname $CURRENT_CRYPTOKI` 	# eg. /opt/ERACcprc/lib/linux-i386
		DIR=`dirname $DIR` 					# eg. /opt/ERACcprc/lib
		DIR=`dirname $DIR` 					# eg. /opt/ERACcprc
		PKG=`basename $DIR` 				# eg. ERACcprc
		make_links $PKG lib
		make_links $PKG lib $ARCH $LIB64
		if [ "$LEGACY" ]; then
			L=$LIBSUFFIX 
			LIBSUFFIX=$LEGACY_LIBSUFFIX 
			make_links $PKG lib $ARCH $LEGACY
			LIBSUFFIX=$L
		fi
		make_links $PKG bin
		make_links $PKG bin $ARCH $LIB64
		make_links $PKG doc
		make_links $PKG man
		make_links $PKG man/man1
		make_links $PKG man/man1m
	fi

	# Any others?
	for PKG in ERACe8k ERACcprc ERACcpsdk ERACcp8k ERACcprs ERACcpsw ERACcprov ETcprt ETcpsw ETcpsdk ETlhsm ETpcihsm ETrhsm ETnethsm \
	   cprt cpsdk pcihsm2 nethsm netsrv jprov jpsdk; do
		if [ -d $BASENAME/$PKG ]; then
			make_links $PKG lib
			make_links $PKG lib $ARCH $LIB64
			if [ "$LEGACY" ]; then
				L=$LIBSUFFIX 
				LIBSUFFIX=$LEGACY_LIBSUFFIX 
				make_links $PKG lib $ARCH $LEGACY
				LIBSUFFIX=$L
			fi
			make_links $PKG bin
			make_links $PKG bin $ARCH $LIB64
			make_links $PKG doc
			make_links $PKG man
			make_links $PKG man/man1
			make_links $PKG man/man1m
		fi
	done

	return 0
}

ls_known_oss() {
	ls -d $KNOWN_OS_DIRS 2>/dev/null
	cd ..
}

# parse input records into DIR PKG VERSION DESCRIPTION and paint menu
# do this in a subroutine to avoid forking in Solaris (& UnixWare &
# OS5?) sh: $1=number to stop at; if 0 do all but suppress the numeric
# prefixes (in this case it's a listing, not a menu)
paint_menu_items() {
	CARDINAL=$1
	if [ "$1" = 0 ]; then
		LISTING=1
	else
		LISTING=""
	fi

	LEGAL=""
	I=0
	while read ENTRY; do
		I=`expr $I + 1`
		SAVE_IFS=$IFS
		IFS='~'
		set -- $ENTRY
		DIR="$1"
		PKG="$2"
		VERSION=`echo "$3" |awk '{printf("%-9s",$0)}'` # 'X.XX.X ' - left justified!
		DESCRIPTION="$4"
		IFS=$SAVE_IFS

		if [ "$LISTING" ]; then
			echo "$VERSION$DESCRIPTION" |chop
		else
			print_menu_letter $I
			echo " $VERSION$DESCRIPTION" |chop
		fi
		LEGAL="$LEGAL $I"
		if [ "$CARDINAL" = "$I" ]; then
			return $I
		fi
	done 
	return $I
}

uninstall_menu() {
	INVAL="$REPAINT"
	INSTALLED=$TMPFILE-installed
	while true; do
		case "$INVAL" in
		"$REPAINT")
			if [ ! -s "$TMPFILE-installed" ]; then 
				print_alarm "No SafeNet packages installed" 
				echo
				press_enter
				return
			fi

			do_main_title "Main menu >> Uninstall Menu"
			SKIP=$?

			paint_menu_items < $TMPFILE-installed
			SKIP=`expr $SKIP + $?`

			echo
			print_menu_letter "b"
			echo " back"
			print_menu_letter "q"
			echo " quit the utility"
			SKIP=`expr $SKIP + 5`

			skip_lines $SKIP
			;;

		[123456789]*)
			# NB: we're re-using INSTALLED from the screen repaint to save time!!
			paint_menu_items $INVAL < $TMPFILE-installed >/dev/null
			echo "Uninstall package:"
			confirm "$VERSION: $DESCRIPTION"
			if [ "$CONFIRM" = "y" ]; then
				EXTRA_OPTIONS=""
				if [ -n "$POSSIBLE_UNINSTALL_OPTIONS" ]; then
					print_reverse "Any extra options for the uninstallation program?"
					echo
					print_normal "eg. $POSSIBLE_UNINSTALL_OPTIONS [] "
					read EXTRA_OPTIONS
				fi
				please_wait "uninstalling"
				echo
				build_uninstall_command_$OSNAME "$DIR" "$PKG"
				
				#execut preuninstall command
				if [ "$PREUNINSTALL" ]; then
					please_wait "Running pre-uninstall script"
					if [ "$DEBUG" ]; then echo "\"eval $PREUNINSTALL\""; fi
					eval $PREUNINSTALL
					wait_over
					PREUNINSTALL=
				fi

				show_command
				mod_command_for_test

				# use 'tee' in case input is needed eg. "Relink Kernel now?" in OS5
				# but $? is then the result of the tee rather than COMMAND so
				# we can't detect success or failure and TMPFILE is useless
				# $COMMAND |tee /dev/tty >$TMPFILE 2>&1
				$COMMAND
				if [ "$?" -ne 0 ]; then
					print_alarm "There were errors:"
					echo
				else
					print_reverse "Success!"
					echo
				fi
				please_wait "scanning system for installed packages"
				list_installed_$OSNAME > $TMPFILE-installed
				wait_over
				check_links
				press_enter
			else
				echo "Did not uninstall $VERSION: $DESCRIPTION"
				press_enter
			fi
			INVAL="$REPAINT"
			continue
			;;

		b|B)
			break
			;;
		q|Q) 
			confirm "Really quit?"
			if [ "$CONFIRM" = "y" ]; then
				exit 0
			fi
			INVAL="$REPAINT"
			;;
		esac

		get_input "$REPAINT" $LEGAL b q
	done
}

install_menu() {
	INVAL="$REPAINT"

	while true; do
		case "$INVAL" in
		"$REPAINT")
			do_main_title "Main menu >> Install Menu"
			SKIP=$?

			paint_menu_items < $TMPFILE-cd
			SKIP=`expr $SKIP + $?`

			echo
			print_menu_letter "b"
			echo " back"
			print_menu_letter "q"
			echo " quit the utility"

			SKIP=`expr $SKIP + 5`
			skip_lines $SKIP
			;;

		[123456789]*)
			paint_menu_items $INVAL < $TMPFILE-cd >/dev/null

			echo "Install:"
			confirm "$VERSION: $DESCRIPTION"
			if [ "$CONFIRM" != "y" ]; then
				echo "Did not install $VERSION: $DESCRIPTION"
				press_enter
				INVAL="$REPAINT"
				continue
			fi

			EXTRA_OPTIONS=""
			if [ -n "$POSSIBLE_INSTALL_OPTIONS" ]; then
				print_reverse "Any extra options for the installation program?"
				echo
				print_normal "eg. $POSSIBLE_INSTALL_OPTIONS [] "
				read EXTRA_OPTIONS
			fi
			please_wait "installing"
			echo
			(
				cd $OS_DIR
				build_install_command_$OSNAME "$DIR" "$PKG"
				show_command
				mod_command_for_test
				# use 'tee' in case input is needed eg. "Relink Kernel now?" in OS5
				# but $? is then the result of the tee rather than COMMAND so
				# we can't detect success or failure
				# $COMMAND |tee /dev/tty >$TMPFILE 2>&1
				IN_INSTALL=1 $COMMAND
				if [ "$?" -ne 0 ]; then
					print_alarm "There were errors:"
					echo
				else
					if [ "$POSTINSTALL" ]; then
						please_wait "Running post-install script"
						if [ "$DEBUG" ]; then echo "\"eval $POSTINSTALL\""; fi
						eval $POSTINSTALL
						wait_over
						POSTINSTALL=
					fi
					print_reverse "Success!"
					echo

					# Install a copy of this script, if not already there or older than this:
					DEST=/usr/bin
					SELF_INSTALL=""
					if [ -x "$DEST/$PROG" ]; then
						if [ "`${FIRSTLINE} $DEST/$PROG 2>/dev/null`" = "#! /bin/sh" ]; then
							if grep PTK $DEST/$PROG >/dev/null 2>&1; then
								EXISTING_VERSION=`$DEST/$PROG -V 2>/dev/null`
								if [ $? = 0 ]; then
									SELF_INSTALL=`awk "END {if (\"$EXISTING_VERSION\" < \"$PROG_VERSION\") { print \"yes\" } }" </dev/null 2>/dev/null`
								fi
							fi
						fi
					else
						SELF_INSTALL="yes"
					fi
					if [ "$SELF_INSTALL" ]; then
						echo "$PROG: Installing a copy of this script in $DEST"
						cp -f $PROG_DIR/$PROG $DEST
					fi

				fi
				if [ "$OSNAME" = "HPUX" ]; then
					cleanup_HPUX "$DIR" "$PKG"
				fi
				
			)
			please_wait "scanning system for installed packages"
			list_installed_$OSNAME > $TMPFILE-installed
			wait_over
			press_enter
			INVAL="$REPAINT"
			continue
			;;

		b|B)
			break
			;;

		q|Q) 
			confirm "Really quit?"
			if [ "$CONFIRM" = "y" ]; then
				exit 0
			fi
			INVAL="$REPAINT"
			;;
		esac

		get_input "$REPAINT" $LEGAL b q
	done
}

# pwd=./
# $1=message
# $2=all or OS to list
print_packages() {
	trace_debug "print_packages(${1+"$@"})"
	(
		# enter_bold - don't use terminal enhancements in a pager
		echo "$1"
		echo
		SKIP=4

		if [ $2 = "all" ]; then
			cat $TMPFILE-cd-guess
			L=`cat $TMPFILE-cd-guess | wc -l `
			SKIP=`expr $SKIP + $L`
		else
			paint_menu_items 0 < $TMPFILE-cd
			SKIP=`expr $? + 5`
			echo
		fi
		return $SKIP
	) > $TMPFILE
	SKIP=$?
	OUTPUT_METHOD=cat
	DISPLAY_LINES=`cat $TMPFILE |wc -l`
	DISPLAY_LINES=`expr $DISPLAY_LINES + 1`
	if [ "$DISPLAY_LINES" -ge "$SCREEN_HEIGHT" ]; then
		OUTPUT_METHOD=$PAGER
	fi
	$OUTPUT_METHOD < $TMPFILE
	rm $TMPFILE
	if [ "$OUTPUT_METHOD" = cat ]; then
		skip_lines $SKIP
	fi

	press_enter
}

list_cd_menu() {
	INVAL="$REPAINT"

	while true; do
		case "$INVAL" in
		"$REPAINT") 
			do_main_title "Main Menu >> List CD menu"
			SKIP=$?
			print_menu_letter "1"
			echo " list packages for this platform"
			print_menu_letter "2"
			echo " list packages for all platforms"
			echo
			print_menu_letter "b"
			echo " back"
			print_menu_letter "q"
			echo " quit the utility"
			SKIP=`expr $SKIP + 7`
			skip_lines $SKIP
			;;

		1)
			print_packages "Packages available for $OSNAME on this CD:" $OSNAME
			INVAL="$REPAINT"
			continue
			;;

		2)
			print_packages "Packages available on this CD:" all
			INVAL="$REPAINT"
			continue
			;;

		b|B) 
			INVAL="$REPAINT"
			return 
			;;

		q|Q) 
			confirm "Really quit?"
			if [ "$CONFIRM" = "y" ]; then
				exit 0
			fi
			INVAL="$REPAINT"
			;;

		esac

		get_input "$REPAINT" 1 2 b q
	done
}

# print the filename pointed to by $1 otherwise "" if a dead link
follow_link() {
	L=$1

	if [ ! -f "$L" ] ; then
		echo ""
		return 0
	fi

	if [ -d "$L" ]; then
		echo $L
		return 2
	fi

	while [ $LINKTEST "$L" ]; do
		# L=`ls -l $L | awk '{print $11}'`
		L=`ls -l $L | sed "s/^.*-> //"`

		if [ -d "$L" ]; then
			echo $L
			return 2
		fi

		if [ ! -f "$L" ] ; then # -f == exists, could be another symbolic link
			echo ""
			return 0
		fi
 	done
	echo $L
	return 0
}

# Returns the number of hsm_link files installed
probe_hsm_links() {
	NUM_HSMS=0
	set -- $HSM_LINK_LABELS
	for C in $LEGAL_HSM_LINKS; do
		if [ -f "$C" ]; then
			echo $1 $C
			NUM_HSMS=`expr $NUM_HSMS + 1`
		fi
		shift
	done
	return $NUM_HSMS
}

count_hsm_links() {
	probe_hsm_links >/dev/null
	echo $?
}	

# Paints menu items and sets HSM_LINK and HSM_LINK_FILE parameters
# Parameters:
# $1 is the item to "paint": "" means all
paint_hsm_link_menu() {
	CARDINAL=$1
	I=$NUM_CRYPTOKIS
	while read HSM_LINK HSM_LINK_FILE; do
		I=`expr $I + 1`
		FLAG="   "
		if [ "$CURRENT_HSM_LINK" = "$HSM_LINK_FILE" ]; then
			FLAG=" * "
		fi
		DESC=`guess_package_name $HSM_LINK`
		print_menu_letter $I
		echo "$FLAG$DESC"
		if [ "$CARDINAL" = "$I" ]; then
			return $I
		fi
	done
	return $I
}

# Returns the number of cryptoki files installed
# SDK can contain sw, rc and 8k/7k cryptokis.
probe_cryptokis() {
	NUM_CRYPTOKIS=0
	set -- $CRYPTOKI_LABELS
	for C in $LEGAL_CRYPTOKIS; do
		if [ -f "$C" ]; then
			echo $1 $C
			NUM_CRYPTOKIS=`expr $NUM_CRYPTOKIS + 1`
		fi
		shift
	done
	return $NUM_CRYPTOKIS
}

count_cryptokis() {
	probe_cryptokis >/dev/null
	echo $?
	#echo LEGAL_CRYPTOKIS=$LEGAL_CRYPTOKIS	#JS
}	

# Paints menu items and sets CRYPTOKI and CRYPTOKI_FILE parameters
# Parameters:
# $1 is the item to "paint": "" means all
paint_cryptoki_menu() {
	CARDINAL=$1
	I=0
	while read CRYPTOKI CRYPTOKI_FILE; do
		I=`expr $I + 1`
		FLAG="   "
		if [ "$CURRENT_CRYPTOKI" = "$CRYPTOKI_FILE" ]; then
			FLAG=" * "
		fi
		DESC=`guess_package_name $CRYPTOKI`
		print_menu_letter $I
		echo "$FLAG$DESC"
		LEGAL="$LEGAL $I"
		if [ "$CARDINAL" = "$I" ]; then
			return $I
		fi
	done
	return $I
}

set_cryptoki_hsm_menu() {
	INVAL="$REPAINT"
	while true; do
		case "$INVAL" in
		"$REPAINT") 
			do_main_title "Main Menu >> Check/Set Default Cryptoki & HSM Menu"
			SKIP=$?
			LEGAL=""

			CURRENT_CRYPTOKI==""
			if [ -f "$DEFAULT_CRYPTOKI_LINK" ]; then
				CURRENT_CRYPTOKI=`follow_link "$DEFAULT_CRYPTOKI_LINK"`
			fi

			probe_cryptokis >$TMPFILE
			NUM_CRYPTOKIS=$?
			if [ "$NUM_CRYPTOKIS" -ge 1 ]; then
				echo "-------------------- Cryptoki Selection --------------------"
				SKIP=`expr $SKIP + 1`
				paint_cryptoki_menu <$TMPFILE
				SKIP=`expr $SKIP + $NUM_CRYPTOKIS`
				echo
				SKIP=`expr $SKIP + 1`
			fi

			CURRENT_HSM_LINK=""
			if [ -f "$DEFAULT_HSM_LINK" ]; then
				CURRENT_HSM_LINK=`follow_link "$DEFAULT_HSM_LINK"`
			fi

			probe_hsm_links >$TMPFILE-hsm
			NUM_HSMS=$?
			cat $TMPFILE-hsm >>$TMPFILE
			if [ "$NUM_HSMS" -gt 1 ]; then
				echo "---------------------- HSM Selection ----------------------"
				SKIP=`expr $SKIP + 1`
			fi

			if [ "$NUM_HSMS" -ge 1 ]; then
				paint_hsm_link_menu <$TMPFILE-hsm
				SKIP=`expr $SKIP + $NUM_HSMS`
			fi

			echo
			echo "b back"
			echo "q quit the utility"
			SKIP=`expr $SKIP + 5`
			skip_lines $SKIP
			;;

		[123456789]*)
			if [ "$INVAL" -le "$NUM_CRYPTOKIS" ]; then
				# Setup the CRYPTOKI & CRYPTOKI_FILE parameters:
				paint_cryptoki_menu $INVAL <$TMPFILE >/dev/null

				echo "Change the default cryptoki to:"
				PKGNAME=`guess_package_name $CRYPTOKI`
				confirm "$PKGNAME"
				if [ "$CONFIRM" = "y" ]; then
					rm -f "$DEFAULT_CRYPTOKI_LINK"
					ln -s "$CRYPTOKI_FILE" "$DEFAULT_CRYPTOKI_LINK"
					if [ "$LIB64" ]; then
						rm -f $DEFAULT_CRYPTOKI_LINK64
						F=`basename $CRYPTOKI_FILE`
						D=`dirname $CRYPTOKI_FILE`
						if [ "$ARCH" = "hpux-ia64" ]; then
							#D has an extra 32 at the end on HP-UX
							D=`dirname $D`
						fi
						if [ -f $D/$LIB64/$F ]; then
							mkdir -p `dirname $DEFAULT_CRYPTOKI_LINK64` 2>/dev/null
							ln -s $D/$LIB64/$F $DEFAULT_CRYPTOKI_LINK64
						fi
					fi
					if [ "$LEGACY" ]; then
						rm -f $DEFAULT_CRYPTOKI_LINK_LEGACY
						F=`basename $CRYPTOKI_FILE`
						D=`dirname $CRYPTOKI_FILE`
						if [ -f $D/$LEGACY/$F ]; then
							mkdir -p `dirname $DEFAULT_CRYPTOKI_LINK_LEGACY` 2>/dev/null
							ln -s $D/$LEGACY/$F $DEFAULT_CRYPTOKI_LINK_LEGACY
						fi
					fi
				fi
			else
				# Setup the HSM_LINK & HSM_LINK_FILE parameters:
				paint_hsm_link_menu $INVAL <$TMPFILE-hsm >/dev/null

				echo "Change the default hsm link to:"
				PKGNAME=`guess_package_name $HSM_LINK`
				confirm "$PKGNAME"
				if [ "$CONFIRM" = "y" ]; then
					rm -f "$DEFAULT_HSM_LINK"
					ln -s "$HSM_LINK_FILE" "$DEFAULT_HSM_LINK"
					if [ "$LIB64" ]; then
						rm -f $DEFAULT_HSM_LINK64
						F=`basename $HSM_LINK_FILE`
						D=`dirname $HSM_LINK_FILE`
						if [ -f $D/$LIB64/$F ]; then
							mkdir -p `dirname $DEFAULT_HSM_LINK64` 2>/dev/null
							ln -s $D/$LIB64/$F $DEFAULT_HSM_LINK64
						fi
					fi
					if [ "$LEGACY" ]; then
						rm -f $DEFAULT_HSM_LINK_LEGACY
						F=`basename $HSM_LINK_FILE`
						D=`dirname $HSM_LINK_FILE`
						if [ -f $D/$LEGACY/$F ]; then
							mkdir -p `dirname $DEFAULT_HSM_LINK_LEGACY` 2>/dev/null
							ln -s $D/$LEGACY/$F $DEFAULT_HSM_LINK_LEGACY
						fi
					fi
				fi
			fi
			rm $TMPFILE
			INVAL="$REPAINT"
			continue
			;;

		b|B) 
			INVAL="$REPAINT"
			return 
			;;

		q|Q) 
			confirm "Really quit?"
			if [ "$CONFIRM" = "y" ]; then
				exit 0
			fi
			INVAL="$REPAINT"
			;;

		esac

		get_input "$REPAINT" $LEGAL b q
	done
}

main_menu() {
	INVAL="$REPAINT"
	while true; do
		case "$INVAL" in
		"$REPAINT") 
			LEGAL=""
			do_main_title "Main menu"
			SKIP=$?
			print_menu_letter "1"
			echo " list SafeNet packages already installed"
			LEGAL="$LEGAL 1"
			SKIP=`expr $SKIP + 1`

			if [ "$HAVE_PACKAGES" ]; then
				print_menu_letter "2"
				echo " list packages on CD"
				SKIP=`expr $SKIP + 1`
				LEGAL="$LEGAL 2"
			fi

			if [ "$HAVE_PACKAGES" ]; then
				if [ "$IS_ROOT" ]; then
					print_menu_letter "3"
					echo " install a package from this CD"
					SKIP=`expr $SKIP + 1`
					LEGAL="$LEGAL 3"
				fi
			fi

			if [ "$IS_ROOT" ]; then
				print_menu_letter "4"
				echo " uninstall a SafeNet package"
				SKIP=`expr $SKIP + 1`
				LEGAL="$LEGAL 4"
			fi

			if [ "$IS_ROOT" ]; then
				NUM_CRYPTOKIS=`count_cryptokis`
				NUM_HSM_LINKS=`count_hsm_links`
				#echo NUM_CRYPTOKIS=$NUM_CRYPTOKIS, NUM_HSM_LINKS=$NUM_HSM_LINKS	#JS
				if [ "$NUM_CRYPTOKIS" -gt 1 -o "$NUM_HSM_LINKS" -gt 1 ]; then
					print_menu_letter "5"
					echo " Set the default cryptoki and/or hsm link"
					SKIP=`expr $SKIP + 1`
					LEGAL="$LEGAL 5"
				fi
			fi

			echo
			print_menu_letter "q"
			echo " quit the utility"
			echo

			if [ ! "$IS_ROOT" ]; then
				echo "Run this as root to be able to install and uninstall packages"
				SKIP=`expr $SKIP + 1`
			fi
			if [ ! "$HAVE_PACKAGES" ]; then
				echo "Change directory to the CDROM before running this to see the CDROM contents"
				SKIP=`expr $SKIP + 1`
			fi
			#print_normal "Support is available at: "
			#print_bold "support@eracom-tech.com"
			echo
			SKIP=`expr $SKIP + 6`
			skip_lines $SKIP
			;;

		1)
			if [ ! -s "$TMPFILE-installed" ]; then 
				print_alarm "No SafeNet packages installed" 
				echo
				press_enter
				INVAL="$REPAINT"
				continue
			fi

			(
				# enter_bold # don't put enhancements through PAGER
				echo "SafeNet packages already installed on `hostname`:"
				echo
				SKIP=2
				paint_menu_items 0 < $TMPFILE-installed
				SKIP=`expr $SKIP + $? + 3`
				echo ""
				return $SKIP
			)  > $TMPFILE
			SKIP=$?
			OUTPUT_METHOD=cat
			DISPLAY_LINES=`cat $TMPFILE |wc -l`
			DISPLAY_LINES=`expr $DISPLAY_LINES + 1`
			if [ "$DISPLAY_LINES" -gt "$SCREEN_HEIGHT" ]; then
				OUTPUT_METHOD=$PAGER
			fi
			$OUTPUT_METHOD < $TMPFILE
			rm $TMPFILE
			if [ "$OUTPUT_METHOD" = cat ]; then
				skip_lines $SKIP
			fi

			press_enter

			INVAL="$REPAINT"
			continue
			;;

		2) 
			list_cd_menu 
			INVAL="$REPAINT"
			continue
			;;

		3)
			install_menu
			INVAL="$REPAINT"
			continue
			;;

		4)
			uninstall_menu
			INVAL="$REPAINT"
			continue
			;;

		5)
			set_cryptoki_hsm_menu
			INVAL="$REPAINT"
			continue
			;;

		q|Q) 
			confirm "Really quit?"
			if [ "$CONFIRM" = "y" ]; then
				exit 0
			fi
			INVAL="$REPAINT"
			;;
		esac

		get_input "$REPAINT" $LEGAL q
	done
}

check_packages() {
	HAVE_PACKAGES=""
    #echo "OS_DIR: " $OS_DIR > ./check_packages.lst
	if [ -d "$OS_DIR" ]; then
		please_wait "scanning CD"
		(
			
			cd $OS_DIR
			for DIR in *; do
				if [ -d "$DIR" ]; then
					#list_cd_$OSNAME "$DIR" #JS.Orig
					echo `list_cd_$OSNAME "$DIR"`
				fi
			done
		) >$TMPFILE-cd

		if [ -s "$TMPFILE-cd" ]; then
			HAVE_PACKAGES="yes"
		fi
		guess_packages >$TMPFILE-cd-guess
		wait_over
	fi
	please_wait "scanning system for installed packages"
	list_installed_$OSNAME > $TMPFILE-installed
	wait_over
}

check_programs() {
# DEPENDENCIES:
# All: 			sh, awk, sed, grep, egrep, fgrep, tr, ls, expr, id, more, head, tput (optional), hostname, uname, tee
# Linux: 		rpm rpmbuild
# Solaris: 		pkgadd, pkginfo, pkgrm, nawk
# HPUX: 		swlist, swinstall, swremove
# AIX:			installp, lslpp
# UnixWare: 	pkgadd, pkginfo, pkgrm
# OpenServer:	pkgadd, pkginfo, pkgrm
	
	ERR=""
	PROGLIST="awk sed grep egrep fgrep tr ls expr id more head hostname uname tee"
	case `uname -s` in
		[lL]inux) 	
			PROGLIST="$PROGLIST rpm"
			;;
		SunOS) 		
			PROGLIST="$PROGLIST pkgadd pkginfo pkgrm nawk"
			;;
		SCO_SV) 	
			PROGLIST="$PROGLIST pkgadd pkginfo pkgrm"
			;;
		UnixWare) 	
			PROGLIST="$PROGLIST pkgadd pkginfo pkgrm"
			;;
		AIX) 		
			PROGLIST="$PROGLIST installp lslpp"
			;;
		HP-UX) 		
			PROGLIST="$PROGLIST swlist swinstall swremove"
			;;
		*)
			echo "$PROG: this OS is not supported: $OSNAME"
			exit 1
			;;
	esac

	for P in $PROGLIST; do
		if type $P >/dev/null 2>&1 ; then
			:
		else
			echo "$PROG: Can't find $P"
			ERR="yes"
		fi
	done

	if [ "$ERR" ]; then
		echo "PATH=$PATH" >&2
		exit 1
	fi
}

check_term() {

	if [ "$ENABLE_TPUT" ]; then
		# make sure tput is usable, otherwise disable:

		if tput init >/dev/null 2>&1 ; then
			:
		else
			I=`stty -a |sed -n -e 's/^.*intr *= *\([^;]*\);.*$/\1/p'`
			echo "This program needs to know what sort of terminal you are using, but the"
			echo "terminal identifier (TERM) is presently set to '$TERM' and this is unknown."
			echo
			echo "If you see garbage after this point, press your INTR key ($I)"
			echo "to exit this program and use the -p option next time."
			echo
			echo "Please type the correct value for TERM or press ENTER."
			print_normal "(eg. vt100, xterm): "
			read T
			if [ -n "$T" ]; then
				TERM=$T
				export TERM
			fi
			if tput init >/dev/null 2>&1 ; then
				tput_output sgr0
			else
				ENABLE_TPUT=""
			fi
		fi
	fi

	START_BOLD=""
	START_NORMAL=""
	START_REVERSE=""
	START_ITALIC=""
	START_BLINK=""
	START_ALARM=""
	export START_BOLD
	export START_NORMAL
	export START_REVERSE
	export START_ITALIC
	export START_BLINK
	export START_ALARM
	if [ "$ENABLE_TPUT" ]; then
		START_BOLD=${START_BOLD}`tput bold`
		START_BOLD=${START_BOLD}`tput setaf 3` # yellow
		START_BOLD=${START_BOLD}`tput setab 4` # blue
		START_NORMAL=${START_NORMAL}`tput setaf 7` # white
		START_NORMAL=${START_NORMAL}`tput setab 0` # black
		START_NORMAL=${START_NORMAL}`tput sgr0`
		START_REVERSE=`tput rev`
		START_ITALIC=`tput sitm`
		START_BLINK=`tput blink`
		START_ALARM=""
		START_ALARM=$START_ALARM`tput rev`
		START_ALARM=${START_ALARM}`tput setaf 3` # yellow
		START_ALARM=${START_ALARM}`tput setab 1` # red
		if [ -z "$SCREEN_HEIGHT" ]; then
			SCREEN_HEIGHT=`tput lines`
		fi
		if [ -z "$SCREEN_WIDTH" ]; then
			SCREEN_WIDTH=`tput cols`
		fi
	fi

	if [ -z "$SCREEN_HEIGHT" ]; then
		SCREEN_HEIGHT=$LINES
	fi
	if [ -z "$SCREEN_HEIGHT" ]; then
		SCREEN_HEIGHT=24
	fi
	if [ "$SCREEN_HEIGHT" -lt 10 ]; then
		SCREEN_HEIGHT=24
	fi

	if [ -z "$SCREEN_WIDTH" ]; then
		SCREEN_WIDTH=$COLS
	fi
	if [ -z "$SCREEN_WIDTH" ]; then
		SCREEN_WIDTH=80
	fi
	if [ "$SCREEN_WIDTH" -lt 65 ]; then
		SCREEN_WIDTH=80
	fi

	# echo screensize==${SCREEN_WIDTH}x$SCREEN_HEIGHT
	# don't write in the rightmost column in case it pushes the cursor down:
	MAX_SCREEN_WIDTH=`expr $SCREEN_WIDTH - 1`
}

os_dependancies() {
	LIBSUFFIX=so
	OSNAME=`uname -s`
	case $OSNAME in
		[lL]inux)
			MACHINE_OS=`uname -m`
			case $MACHINE_OS in 
				[xX]86_64)
					OSNAME="Linux64"
					;;
				[iI]386)
					;;
			esac
			;;
	esac
			
	OS_DIR=$OSNAME
	LINKTEST="-L"
	IDPROG="id"
	TR=tr
	AWK=awk
	FIRSTLINE="head -n 1"
	for ECHO in /usr/bin/echo /bin/echo nil; do
		if [ -x "$ECHO" ]; then
			break
		fi
	done
	if [ "$ECHO" = "nil" ]; then
		echo "$PROG: can't find an 'echo' program"
		exit 1
	fi

	if [ `$ECHO 'one line\c'|wc -l` -eq 0 ]; then
		ECHO_NO_CR=echo_no_cr_backslash
	else
		ECHO_NO_CR=echo_no_cr_n
	fi

	LIB64=""
	case $OSNAME in
		[lL]inux64)
			OSNAME=Linux64
			OS_DIR=Linux64
			ARCH=linux-x86_64
			INSTALL_PROGRAM=rpm
			UNINSTALL_PROGRAM=rpm
			POSSIBLE_INSTALL_OPTIONS="--nodeps --noscripts"
			POSSIBLE_UNINSTALL_OPTIONS="--nodeps --noscripts"
			;;
		[lL]inux)
   			OSNAME=Linux
   			OS_DIR=Linux
   			ARCH=linux-i386
   			INSTALL_PROGRAM=rpm
   			UNINSTALL_PROGRAM=rpm
   			POSSIBLE_INSTALL_OPTIONS="--nodeps --noscripts"
   			POSSIBLE_UNINSTALL_OPTIONS="--nodeps --noscripts"
   			;;
		SunOS) 		
			OSNAME=Solaris

			AWK=nawk
			IDPROG="/usr/xpg4/bin/id"
			OS_DIR=Solaris
			LIB64=sparcv9
			ARCH=`uname -p`

            #For X86
            if [ "$ARCH" != "sparc" ];then
                    echo "Installing for Solaris X86"
                    OS_DIR=SolarisX86
                    LIB64=amd64
            fi

			INSTALL_PROGRAM=pkgadd
			UNINSTALL_PROGRAM=pkgrm
			POSSIBLE_INSTALL_OPTIONS=""
			POSSIBLE_UNINSTALL_OPTIONS=""
			LINKTEST="-h"
			;;
		SCO_SV) 	
			OSNAME=OpenServer
			OS_DIR=$OSNAME
			ARCH=openserver-i386
			INSTALL_PROGRAM=pkgadd
			UNINSTALL_PROGRAM=pkgrm
			POSSIBLE_INSTALL_OPTIONS=""
			POSSIBLE_UNINSTALL_OPTIONS=""
			;;
		UnixWare) 	
			OSNAME=UnixWare
			TR="tr -s"
			ARCH=unixware-i386
			INSTALL_PROGRAM=pkgadd
			UNINSTALL_PROGRAM=pkgrm
			POSSIBLE_INSTALL_OPTIONS=""
			POSSIBLE_UNINSTALL_OPTIONS=""
			;;
		AIX) 	
			OSNAME=AIX
			ARCH=aix-ppc
			LIBSUFFIX=a
			INSTALL_PROGRAM=installp
			UNINSTALL_PROGRAM=installp
			POSSIBLE_INSTALL_OPTIONS=""
			POSSIBLE_UNINSTALL_OPTIONS=""
			must_be_root # otherwise installp can't even list packages!
			LIB64=aix-ppc64
			LEGACY=legacy
			LEGACY_LIBSUFFIX=so
			;;
		HP-UX) 		
			OSNAME=HPUX
			OS_DIR=HP-UX
			case `uname -m` in
				ia64) 
				ARCH=hpux-ia64
				LIBSUFFIX=so
				;;
				*)    
				ARCH=hpux-pa
				LIBSUFFIX=sl
				;;
			esac
			INSTALL_PROGRAM=swinstall
			UNINSTALL_PROGRAM=swremove
			POSSIBLE_INSTALL_OPTIONS=""
			POSSIBLE_UNINSTALL_OPTIONS=""
			must_be_root # otherwise swlist command hangs
			#LINKTEST="-h" #JS orig
			LINKTEST="-L"
			LIB64=64
			;;
		*)
			echo "$PROG: this OS is not supported: $OSNAME"
			exit 1
			;;
	esac
}

# usage: inPath new_directory LD_LIBRARY_PATH
inPath() {
	RETVAL=1
    CANDIDATE="$1"
	AGGREGATE=`echo $2|sed 's/:/ /g'`
    for P in "$AGGREGATE"; do
        if [ "$P" = "$CANDIDATE" ]; then
			RETVAL=0
			break
		fi
    done
    return $RETVAL
}

set_path() {
	for C in /usr /usr/bin /sbin /usr/sbin; do
		if inPath $C $PATH; then
			:
		else
			PATH=$PATH:$C
		fi
	done
}

cleanup_tmp() {
	[ "$TMPFILE" ] && rm -f $TMPFILE $TMPFILE-installed $TMPFILE-cd-guess $TMPFILE-cd $TMPFILE-hsm
}

initialise_globals() {

	export LIBSUFFIX
	export OSNAME
	export LINKTEST
	export IDPROG
	export TR
	export AWK
	export ECHO_NO_CR
	export ARCH
	export LIB64
	export LEGACY
	export LEGACY_LIBSUFIX
	export INSTALL_PROGRAM
	export UNINSTALL_PROGRAM
	export POSSIBLE_INSTALL_OPTIONS
	export POSSIBLE_UNINSTALL_OPTIONS
	export EXTRA_OPTIONS
	export SCREEN_HEIGHT
	export SCREEN_WIDTH
	export MAX_SCREEN_WIDTH
	export TERM
	export LEGAL
	export TMPFILE
	export POSTINSTALL

	REPAINT="Redraw"
	export REPAINT
	if [ -z "$PAGER" ]; then
		PAGER=more
	fi
	export PAGER

	TMPFILE=/tmp/install.sh.$$
	EXEC="eval"
	export EXEC

	BASENAMEv4="/opt"
	LINKBASEv4="${BASENAMEv4}/PTK"
	BASENAMEv5="/opt/safenet/protecttoolkit5"
	LINKBASEv5="${BASENAMEv5}/ptk"
	
	export ENABLE_TPUT

	DISPLAY="" # just in case ...
	export DISPLAY

	# Note: if sh(1) had the facility, LEGAL_CRYPTOKISv4 and CRYPTOKI_LABELSv4
	# would be asociative arrays. As it is, they have to be manually
	# defined as parallel lists - make sure they stay in sync!

	LEGAL_CRYPTOKISv4="$BASENAMEv4/ERACcp8k/lib/$ARCH/libctc8k.$LIBSUFFIX"
	LEGAL_CRYPTOKISv4="$LEGAL_CRYPTOKISv4 $BASENAMEv4/ERACcprc/lib/$ARCH/libctclient.$LIBSUFFIX"
	LEGAL_CRYPTOKISv4="$LEGAL_CRYPTOKISv4 $BASENAMEv4/ERACcpsw/lib/$ARCH/libctsw.$LIBSUFFIX"
	LEGAL_CRYPTOKISv4="$LEGAL_CRYPTOKISv4 $BASENAMEv4/ERACcprov/lib/$ARCH/libctcsa.$LIBSUFFIX"
	LEGAL_CRYPTOKISv4="$LEGAL_CRYPTOKISv4 $BASENAMEv4/ERACcpsdk/lib/$ARCH/libctc8k.$LIBSUFFIX"
	LEGAL_CRYPTOKISv4="$LEGAL_CRYPTOKISv4 $BASENAMEv4/ERACcpsdk/lib/$ARCH/libctclient.$LIBSUFFIX"
	LEGAL_CRYPTOKISv4="$LEGAL_CRYPTOKISv4 $BASENAMEv4/ERACcpsdk/lib/$ARCH/libctsw.$LIBSUFFIX"
	LEGAL_CRYPTOKISv4="$LEGAL_CRYPTOKISv4 $BASENAMEv4/ERACcpsdk/lib/$ARCH/libctcsa.$LIBSUFFIX"
	LEGAL_CRYPTOKISv4="$LEGAL_CRYPTOKISv4 $BASENAMEv4/ETcprt/lib/$ARCH/libcthsm.$LIBSUFFIX"
	LEGAL_CRYPTOKISv4="$LEGAL_CRYPTOKISv4 $BASENAMEv4/ETcpsdk/lib/$ARCH/libctsw.$LIBSUFFIX"
	LEGAL_CRYPTOKISv4="$LEGAL_CRYPTOKISv4 $BASENAMEv4/ETcpsdk/lib/$ARCH/libcthsm.$LIBSUFFIX"
	export LEGAL_CRYPTOKISv4
	
	CRYPTOKI_LABELSv4="ERACcp8k ERACcprc ERACcpsw ERACcprov ERACcp8k-sdk ERACcprc-sdk ERACcpsw-sdk ERACcprov-sdk ETcprt ETcpsw-sdk ETcprt-sdk"
	export CRYPTOKI_LABELSv4
	#JS
	if [ `uname -s` = "HP-UX" ]; then
		LEGAL_CRYPTOKISv5="$BASENAMEv5/cprt/lib/$ARCH/32/libcthsm.$LIBSUFFIX"
		LEGAL_CRYPTOKISv5="$LEGAL_CRYPTOKISv5 $BASENAMEv5/cpsdk/lib/$ARCH/32/libctsw.$LIBSUFFIX"
		LEGAL_CRYPTOKISv5="$LEGAL_CRYPTOKISv5 $BASENAMEv5/cpsdk/lib/$ARCH/32/libcthsm.$LIBSUFFIX"
	else
		LEGAL_CRYPTOKISv5="$BASENAMEv5/cprt/lib/$ARCH/libcthsm.$LIBSUFFIX"
		LEGAL_CRYPTOKISv5="$LEGAL_CRYPTOKISv5 $BASENAMEv5/cpsdk/lib/$ARCH/libctsw.$LIBSUFFIX"
		LEGAL_CRYPTOKISv5="$LEGAL_CRYPTOKISv5 $BASENAMEv5/cpsdk/lib/$ARCH/libcthsm.$LIBSUFFIX"
	fi
	export LEGAL_CRYPTOKISv5

	CRYPTOKI_LABELSv5="PTKcprt PTKcpsw-sdk PTKcprt-sdk"
	export CRYPTOKI_LABELSv5
	
	# simple check on the arrays:
	if [ `echo "$LEGAL_CRYPTOKISv4" |wc -w` -ne `echo "$CRYPTOKI_LABELSv4" |wc -w` ]; then
		echo "Internal BUG in CRYPTOKI_LABELSv4"
		exit 1
	fi
	if [ `echo "$LEGAL_CRYPTOKISv5" |wc -w` -ne `echo "$CRYPTOKI_LABELSv5" |wc -w` ]; then
		echo "Internal BUG in CRYPTOKI_LABELSv5"
		exit 1
	fi
	
	DEFAULT_CRYPTOKI_LINKv4="$BASENAMEv4/PTK/lib/libcryptoki.$LIBSUFFIX"
	export DEFAULT_CRYPTOKI_LINKv4
	
	DEFAULT_CRYPTOKI_LINKv5="$BASENAMEv5/ptk/lib/libcryptoki.$LIBSUFFIX"
	export DEFAULT_CRYPTOKI_LINKv5	
	#JS
	echo LIB64=$LIB64	#JS
	if [ "$LIB64" ]; then
		DEFAULT_CRYPTOKI_LINK64v4="$BASENAMEv4/PTK/lib/$LIB64/libcryptoki.$LIBSUFFIX"
		export DEFAULT_CRYPTOKI_LINK64v4
		DEFAULT_CRYPTOKI_LINK64v5="$BASENAMEv5/ptk/lib/$LIB64/libcryptoki.$LIBSUFFIX"
		export DEFAULT_CRYPTOKIv5_LINK64v5
	fi

	if [ "$LEGACY" ]; then
		DEFAULT_CRYPTOKI_LINK_LEGACY="$BASENAMEv4/PTK/lib/$LEGACY/libcryptoki.$LEGACY_LIBSUFFIX"
		export DEFAULT_CRYPTOKI_LINK_LEGACY
	fi
		
	#####################################################################################
		
	# Similarly, LEGAL_HSM_LINKSv4 and HSM_LINK_LABELSv4 should be
	# associative arrays but need to be kept syncronised manually:
	LEGAL_HSM_LINKSv4="$BASENAMEv4/ETlhsm/lib/$ARCH/libetpso.$LIBSUFFIX"
	LEGAL_HSM_LINKSv4="$LEGAL_HSM_LINKSv4 $BASENAMEv4/ETpcihsm/lib/$ARCH/libetpso.$LIBSUFFIX"
	LEGAL_HSM_LINKSv4="$LEGAL_HSM_LINKSv4 $BASENAMEv4/ETpcihsm/lib/$ARCH/libetpcihsm.$LIBSUFFIX"
	LEGAL_HSM_LINKSv4="$LEGAL_HSM_LINKSv4 $BASENAMEv4/ETrhsm/lib/$ARCH/libetnetclient.$LIBSUFFIX"
	LEGAL_HSM_LINKSv4="$LEGAL_HSM_LINKSv4 $BASENAMEv4/ETnethsm/lib/$ARCH/libetnetclient.$LIBSUFFIX"
	
	LEGAL_HSM_LINKSv5="$BASENAMEv5/pcihsm2/lib/$ARCH/libetpcihsm.$LIBSUFFIX"
	LEGAL_HSM_LINKSv5="$LEGAL_HSM_LINKSv5 $BASENAMEv5/nethsm/lib/$ARCH/libetnetclient.$LIBSUFFIX"
	
	export LEGAL_HSM_LINKSv4
	export LEGAL_HSM_LINKSv5

	HSM_LINK_LABELSv4="ETlhsm ETpcihsm ETpcihsm ETrhsm ETnethsm"
	HSM_LINK_LABELSv5="PTKpcihsmK6 PTKnethsm"
	export HSM_LINK_LABELSv4
	export HSM_LINK_LABELSv5
	
	# simple check on the arrays:
	if [ `echo "$LEGAL_HSM_LINKSv4" |wc -w` -ne `echo "$HSM_LINK_LABELSv4" |wc -w` ]; then
		echo "Internal BUG in HSM_LINK_LABELSv4"
		exit 1
	fi
		if [ `echo "$LEGAL_HSM_LINKSv5" |wc -w` -ne `echo "$HSM_LINK_LABELSv5" |wc -w` ]; then
		echo "Internal BUG in HSM_LINK_LABELSv5"
		exit 1
	fi

	DEFAULT_HSM_LINKv4="$BASENAMEv4/PTK/lib/libethsm.$LIBSUFFIX"
	export DEFAULT_HSM_LINKv4
	
	DEFAULT_HSM_LINKv5="$BASENAMEv5/ptk/lib/libethsm.$LIBSUFFIX"
	export DEFAULT_HSM_LINKv5

	if [ "$LIB64" ]; then
		DEFAULT_HSM_LINK64v4="$BASENAMEv4/PTK/lib/$LIB64/libethsm.$LIBSUFFIX"
		export DEFAULT_HSM_LINK64v4
		DEFAULT_HSM_LINK64v5="$BASENAMEv5/ptk/lib/$LIB64/libethsm.$LIBSUFFIX"
		export DEFAULT_HSM_LINK64v5
	fi

	if [ "$LEGACY" ]; then
		DEFAULT_HSM_LINK_LEGACY="$BASENAMEv4/PTK/lib/$LEGACY/libethsm.$LEGACY_LIBSUFFIX"
		export DEFAULT_HSM_LINK_LEGACY
	fi

	HAVE_PACKAGES=""
	export HAVE_PACKAGES
}

set_ptk4_paths() {
	BASENAME=$BASENAMEv4; export BASENAME
	LINKBASE=$LINKBASEv4; export LINKBASE

	LEGAL_CRYPTOKIS=$LEGAL_CRYPTOKISv4; export LEGAL_CRYPTOKIS
	CRYPTOKI_LABELS=$CRYPTOKI_LABELSv4; export CRYPTOKI_LABELS
	DEFAULT_CRYPTOKI_LINK=$DEFAULT_CRYPTOKI_LINKv4; export DEFAULT_CRYPTOKI_LINK
	DEFAULT_CRYPTOKI_LINK64=$DEFAULT_CRYPTOKI_LINK64v4; export DEFAULT_CRYPTOKI_LINK64

	LEGAL_HSM_LINKS=$LEGAL_HSM_LINKSv4; export LEGAL_HSM_LINKS
	HSM_LINK_LABELS=$HSM_LINK_LABELSv4; export HSM_LINK_LABELS
	DEFAULT_HSM_LINK=$DEFAULT_HSM_LINKv4; export DEFAULT_HSM_LINK
	DEFAULT_HSM_LINK64=$DEFAULT_HSM_LINK64v4; export DEFAULT_HSM_LINK64
}

set_ptk5_paths() {
	#echo "set_ptk5_paths(). BASENAMEv5: " $BASENAMEv5
	BASENAME=${BASENAMEv5}; export BASENAME
	LINKBASE=$LINKBASEv5; export LINKBASE

	LEGAL_CRYPTOKIS=$LEGAL_CRYPTOKISv5; export LEGAL_CRYPTOKIS
	CRYPTOKI_LABELS=$CRYPTOKI_LABELSv5; export CRYPTOKI_LABELS
	DEFAULT_CRYPTOKI_LINK=$DEFAULT_CRYPTOKI_LINKv5; export DEFAULT_CRYPTOKI_LINK
	DEFAULT_CRYPTOKI_LINK64=$DEFAULT_CRYPTOKI_LINK64v5; export DEFAULT_CRYPTOKI_LINK64

	LEGAL_HSM_LINKS=$LEGAL_HSM_LINKSv5; export LEGAL_HSM_LINKS
	HSM_LINK_LABELS=$HSM_LINK_LABELSv5; export HSM_LINK_LABELS
	DEFAULT_HSM_LINK=$DEFAULT_HSM_LINKv5; export DEFAULT_HSM_LINK
	DEFAULT_HSM_LINK64=$DEFAULT_HSM_LINK64v5; export DEFAULT_HSM_LINK64
}


process_options() {
	PROGNAME="$0"
	PROG=`basename $0`
	PROG_DIR=`dirname $0`
	PROG_DIR=`fqn $PROG_DIR`
	PROG_VERSION="5.9.1"
	SCREEN_HEIGHT=""
	SCREEN_WIDTH=""
	ENABLE_TPUT="yes"
	BASENAME=""

	ARGS=`getopt hptVs: $@`
	STAT=$?
	if [ "$STAT" -ne 0 ]; then
		echo "$PROG: use -h for usage" >&2
		exit $STAT
	fi
	set -- $ARGS
	for I in $@; do
		case $I in
			-h) usage; exit 0; shift ;;
			-p) ENABLE_TPUT=""; shift;;
			-t) EXEC=test_mode;; # for testing
			-s) SCREEN_PARAM=$2; shift 2;;
			-V) echo $PROG_VERSION; exit 0;;
			--) shift; break;;
		esac
	done

	if [ "$EXEC" != "eval" ]; then
		TITLE="$TITLE - test mode"
	fi

	if [ -n "SCREEN_PARAM" ]; then
		SAVE_IFS=$IFS
		IFS=x
		set -- $SCREEN_PARAM
		IFS=$SAVE_IFS
		SCREEN_HEIGHT=$1
		SCREEN_WIDTH=$2
	fi
}

usage() {
	echo "Usage: $PROG [-hp] [-s size]"
	echo "Gemalto Unix installation utility for SafeNet ProtectServer HSM supporting:"
	echo "$KNOWN_OS_DIRS"
	echo
	echo "You need to be 'root' to be able to install and uninstall packages."
	echo
	echo "Options:"
	echo "  -h       show this help"
	echo "  -p       plain mode (don't use 'tput' for video enhancements)"
	echo "  -s size  override the screensize (default = 'tput lines/cols' or 24x80)"
	echo "  -V       print the version of this script"
	echo
	echo "If TERM is not set correctly then this program's screens may be confused."
	echo "In this case you can use the -p and/or -s options."
	echo
	echo "If your 'backspace' key does not work properly then, before running this"
	echo "program, use:"
	echo "	stty erase <backspace><enter>"
	echo "... where '<backspace>' is the key you want to use."
	echo
	echo "Support is available at support@SafeNet.com"
	echo
}

############
# Main:

process_options $@
SIGEXIT=0
SIGHUP=1
SIGINTR=2
SIGQUIT=3
SIGTERM=15
trap "cleanup_tmp; exit 0" $SIGEXIT $SIGHUP $SIGINTR $SIGQUIT $SIGTERM

set_path
os_dependancies
initialise_globals

IS_ROOT=""
if [ `$IDPROG -u` -eq 0 ]; then
	IS_ROOT="yes"
fi

check_programs
check_term

# We now know enough to be able to start outputing:
skip_lines 0

TITLE="Gemalto Unix Installation Utility for SafeNet ProtectServer HSM (version $PROG_VERSION):"
SUBTITLE="Hostname: `hostname` ($OSNAME `uname -r`)"

echo "IMPORTANT:  The terms and conditions of use outlined in the software"
echo "license agreement shipped with the product (\"License\") constitute"
echo "a legal agreement between you and Gemalto"
echo "Please read the License contained in the packaging of this"
echo "product in its entirety before installing this product."
echo ""
echo "Do you agree to the License contained in the product packaging? "
echo ""
echo "If you select 'yes' or 'y' you agree to be bound by all the terms"
echo "and conditions set out in the License."
echo ""
echo "If you select 'no' or 'n', this product will not be installed."
echo ""
echo "(y/n) "

read LICENSE
if [ "$LICENSE" = "y" ]  || [ "$LICENSE" = "yes" ]; then
    echo ""
else
    echo "You must agree to the license agreement before installing this software."
    echo "The install will now exit."
    exit 1
fi

set_ptk5_paths

print_bold "$TITLE"
echo
echo "$SUBTITLE"
echo
echo "Base for installation is $BASENAME"
echo

check_packages

please_wait "Checking links"
if [ "$IS_ROOT" ]; then
	check_links
fi
wait_over

main_menu
