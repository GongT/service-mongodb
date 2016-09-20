#!/usr/bin/env bash

BUILD_TAG=gongt/mongodb
RUN_NAME=mongodb

if [ -z "${DATABASE_PATH}" ]; then
	DATABASE_PATH=${1-"`pwd`/database"}
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
	docker exec -it ${RUN_NAME} mongo 'admin' -u admin -p password -eval ${1-'db.users.find().toString()'}
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

# -p 27017:27017 -p 28017:28017 \
docker run --restart=always -d \
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

if touch /usr/bin/mongo &>/dev/null; then
	INSTALL_PATH=/usr/bin/mongo
else
	INSTALL_PATH=/usr/local/bin/mongo
fi
DO_NOT_INSTALL_MONGO=
if [ -f "${INSTALL_PATH}" ]; then
	if grep -q "${SAFE_STRING}" "${INSTALL_PATH}"; then
		rm "${INSTALL_PATH}"
	else
		DO_NOT_INSTALL_MONGO="\nNote:\n   "${INSTALL_PATH}" is already exists. - mongo tool not installed.\n\nyou can add 'alias mongo=\"mongo -h mongodb -u admin -p password admin\"' to your .bashrc file"
	fi
fi

if [ -z "${DO_NOT_INSTALL_MONGO}" ]; then
	echo -e "#!/bin/bash\n# ${SAFE_STRING}\n\n docker exec -it ${RUN_NAME} mongo" > "${INSTALL_PATH}"
	chmod a+x "${INSTALL_PATH}"
fi

docker logs ${RUN_NAME}
echo "---- status log above ----"
echo "database files saved at: ${DATABASE_PATH}"
echo ""
echo "user:     admin"
echo "pass:     password"
echo -e "${DO_NOT_INSTALL_MONGO}"

