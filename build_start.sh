#!/usr/bin/env bash

BUILD_TAG=gongt/mongodb
RUN_NAME=mongodb

set -e
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
DATABASE_PATH="$(pwd)/database"

L=`ls "${DATABASE_PATH}" 2>/dev/null | wc -l`
if [ ${L} -gt 0 ]; then
	DATABASE_ALREADY_EXISTS=yes
fi

SAFE_STRING=260968bb6fd2ca9c3c2ac056c970eec9a11a03a3
VERSION_STRING=`git log --format="%H" -n 1`

if ! git diff-index --quiet HEAD --; then
    VERSION_STRING=`git diff HEAD -- | md5sum | awk '{print $1}'`
fi

die () {
	echo $@ >&2
	exit 1
}

inspect_image () {
	docker inspect --type container ${RUN_NAME}
}

inspect_container () {
	docker inspect --type container ${RUN_NAME}
}

check_container_tag () {
	docker inspect --type container ${RUN_NAME} | grep "com.github.GongT.${1}" | grep -q "$2"
}
container_exists () {
	inspect_container &>/dev/null
}

try_run () {
	if [ -z "${DATABASE_ALREADY_EXISTS}" ]; then
		CRE='-u admin -p password'
	fi
	docker exec -i ${RUN_NAME} mongo 'admin' ${CRE} -eval ${1-'db.users.find().toString()'}
}
check_ok () {
	try_run &>/dev/null
}

docker build \
	--build-arg "SAFE_STRING=${SAFE_STRING}" \
	--build-arg "VERSION_STRING=${VERSION_STRING}" \
	-t ${BUILD_TAG} .
	
if [ $? -ne 0 ]; then
	die "can't build '${BUILD_TAG}' image."
fi
 
if container_exists ; then
	if check_container_tag "version" "${VERSION_STRING}" ; then
		echo "newest version of '${RUN_NAME}' is already running."
		exit
	fi
	if inspect_container | grep -q "${SAFE_STRING}" ; then
		echo "stop and remove '${RUN_NAME}' container"
		docker stop ${RUN_NAME} || die "can't stop container"
		docker rm ${RUN_NAME} || die "can't remove container"
	else
		die "container name '${RUN_NAME}' is already exists."
	fi
fi

echo "DATABASE_PATH=${DATABASE_PATH}"

# -p 27017:27017 -p 28017:28017 \
docker run --restart=always -d \
	-p 27017:27017 \
	--name ${RUN_NAME} \
	-v ${DATABASE_PATH}:/data/db \
	${BUILD_TAG}

if [ $? -ne 0 ]; then
	if ! container_exists ; then
		echo "can't create '${RUN_NAME}' container." >&2
	fi
	docker logs ${RUN_NAME}
	die "can't run '${RUN_NAME}' container. check logs."
fi

TRIES=0
sleep 1
while ! check_ok; do
	sleep 1
	TRIES=$((TRIES+1))
	if [ ${TRIES} -gt 5 ]; then
		echo "---- status log ----"
		docker logs ${RUN_NAME}
		echo "---- test result ----"
		try_run 1>&2
		echo "---- ----"
		die "can't connect to database after 5s."
	fi
done

DO_NOT_INSTALL_MONGO=
USER=${MONGODB_USER:-"admin"}
DATABASE=${MONGODB_DATABASE:-"admin"}
PASS=${MONGODB_PASS:-"password"}

install () {
	echo "#!/bin/bash
# ${SAFE_STRING}

docker exec -it ${RUN_NAME} mongo '-u${USER}' '-p${PASS}' '--authenticationDatabase' '${DATABASE}' \"\$@\"

" > "${*}"
	chmod a+x "${*}"
}
check_and_install () {
	local INSTALL_PATH="$*"
	if [ -e "${INSTALL_PATH}" ]; then
		if touch "${INSTALL_PATH}" &>/dev/null; then
			if grep -q "${SAFE_STRING}" "${INSTALL_PATH}"; then
				install "${INSTALL_PATH}"
				return 0
			fi
		fi
		DO_NOT_INSTALL_MONGO="\nNote:\n   "${INSTALL_PATH}" is already exists. - mongo tool not installed.\n\nyou can add \'alias mongo=\"xxxx\"\' to your .bashrc file"
		return 0
	else
		if touch "${INSTALL_PATH}" &>/dev/null; then
			install "${INSTALL_PATH}"
			return 0
		fi
		return 1
	fi
}


if ! check_and_install /usr/bin/mongo ; then
	check_and_install /usr/local/bin/mongo
fi

docker logs ${RUN_NAME}
echo "---- status log above ----"
echo "database files saved at: ${DATABASE_PATH}"
echo ""
echo "user:     admin"
echo "pass:     password"
echo -e "${DO_NOT_INSTALL_MONGO}"

