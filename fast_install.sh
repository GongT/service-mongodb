#!/usr/bin/env bash

die () {
	echo $@ >&2
	exit 1
}

if ! which git &>/dev/null ; then
	die "please install git first"
fi
if ! which docker &>/dev/null ; then
	die "please install docker first"
fi

echo_run(){
	echo "::: $@"
	$@
}

TARGET=
if [ -d /data ]; then
	TARGET=/data/gongt-services/mongodb
	mkdir -p /data/gongt-services
else
	if [ -d /opt ]; then
		TARGET=/opt/gongt-services/mongodb
		mkdir -p /opt/gongt-services
	else
		die "no where to install, please create /data or /opt"
	fi
fi

if [ -e "${TARGET}" ]; then
	if [ -e "${TARGET}/set_mongodb_password.sh" -a -e "${TARGET}/build_start.sh" ]; then
		cd ${TARGET}
		git pull
	else
		die "install target ${TARGET} already used."
	fi
else
	echo_run git clone https://github.com/GongT/service-mongodb.git ${TARGET}
fi

echo_run cd ${TARGET}
