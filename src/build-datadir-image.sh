#!/usr/bin/env bash
# Initializes a mariadb container with a databasedump and extracts its datadir
# into a seperate container-image.

set -euo pipefail
IFS=$'\n\t'
PATH="$HOME/bin:/usr/local/bin:/usr/local/sbin:$PATH";
# In case of errors, just write out that we stopped due to an error.
# Cleanup is performed subsequently by the cleanup() trap.
error() {
    echo "Exiting due to error"
    exit $?
}

show_system_state() {
  echo "Dumping usage status:"
  echo "*** LOCAL w"
  w
  echo "*** LOCAL df -h"
  df -h

  echo "*** CONTAINER df -h"
  docker run alpine df -h
}

# Remove volumes and containers.
cleanup() {
  echo "Cleanup called."

  if [[ ! -z "${DB_CONTAINER_NAME:-}" ]]
  then
    echo "Removing container ${DB_CONTAINER_NAME}."
    docker rm -f "${DB_CONTAINER_NAME}"
  fi

  if [[ ! -z "${DUMP_VOLUME:-}" ]]
    then
      echo "Removing dump volume ${DUMP_VOLUME}."
      docker volume rm -f "${DUMP_VOLUME}"
  fi

  if [[ ! -z "${DATADIR_VOLUME:-}" ]]
    then
      echo "Removing datadir volume ${DATADIR_VOLUME}."
      docker volume rm -f "${DATADIR_VOLUME}"
  fi

  if [[ ! -z "${DATADIR_CONTAINER:-}" ]]
    then
      echo "Removing container ${DATADIR_CONTAINER}."
      docker rm -f "${DATADIR_CONTAINER}"
  fi
  show_system_state
}

# Remove all temporary data we can get our hands on.
cleanup_tmp() {
  echo "Cleanup temp data called."

  if [[ ! -z "${TMP_DATADIR-}" ]]
    then
      echo "Removing datadir ${TMP_DATADIR}."
      rm -rf "${TMP_DATADIR}"
  fi
}


trap error ERR
trap cleanup_tmp EXIT

# Make sure our current directory is the scriptdir.
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${SCRIPTDIR}"

if [ $# -lt 2 ]
  then
    echo "Syntax: ${0} <source user/repo:tag> <destination user/repo:tag> [init-sql-script-url]"
    exit
fi

DUMP_IMAGE_SOURCE=$1
DATADIR_IMAGE_DESTINATION=$2

echo "Using source dump ${DUMP_IMAGE_SOURCE} to build a datadir and push it to ${DATADIR_IMAGE_DESTINATION}"
if [ $# -gt 2 ]
  then
  echo " source dump will be supplemented with the initscript ${3} "
fi

# Random string used for names.
RUN_TOKEN=$(cat /proc/sys/kernel/random/uuid | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
DUMP_VOLUME="dump-source-${RUN_TOKEN}"
DATADIR_VOLUME="datadir-${RUN_TOKEN}"
MYSQL_CONFIG="${SCRIPTDIR}/mysql-config/my.cnf"
INIT_ONLY_ENTRYPOINT="${SCRIPTDIR}/init-only-entrypoint.sh"
# Datadir we're going to wrap in an image.
INITSCRIPT=""
# Let the user specify a init-script to be run after the db-import.
if [ $# -gt 2 ]
  then
    if [[ $3 == standard-* ]]
      then
      INITSCRIPT="${SCRIPTDIR}/init-sql/${3:9}/reset.sql"
    else
      echo "ERROR: init script must be one of standard-drupal7 or standard-drupal8"
      exit 1
    fi
  else
    INITSCRIPT=''
fi

$SCRIPTDIR/init-gcloud.sh

show_system_state

# Get the tag and make sure it is available as a dbdump image.
docker pull "${DUMP_IMAGE_SOURCE}"

# Create a temporary volume for the run
docker volume create "${DUMP_VOLUME}"

# Populate the dump volume with our source dump (this is the default behaviour
# if you mount an empty volume on top of existing files in the image).
docker run \
  --rm \
  -v "${DUMP_VOLUME}:/docker-entrypoint-initdb.d" \
  "${DUMP_IMAGE_SOURCE}"

# Create a volume we'll have mysql write its datadir to.
# We use a named volume instead of a bind mount to make the setup a bit more
# robust.
docker volume create "${DATADIR_VOLUME}"

# Setup the mariadb container we're about to start
# Lock down the version to make our entrypoint override more stable.
DB_CONTAINER_NAME="mariadb-${RUN_TOKEN}"
docker container create \
  --name "${DB_CONTAINER_NAME}" \
  -v "${DUMP_VOLUME}:/docker-entrypoint-initdb.d" \
  -v "${DATADIR_VOLUME}:/var/lib/mysql" \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=db \
  -e MYSQL_USER=db \
  -e MYSQL_PASSWORD=db \
  mariadb:10.3.9

show_system_state

# Now that the container has been created (but not yet started) we can copy
# files to its volumes.

# Pick up a init-script (ie. sql that should be run after the databasedump has
# been imported) specified on the commandline, and add it to docker-compose.yml.
if [ ! -z $INITSCRIPT ]
  then
    docker cp $INITSCRIPT "${DB_CONTAINER_NAME}:/docker-entrypoint-initdb.d/900-init.sql"
fi

# Get our custom configurations in place.
docker cp "${MYSQL_CONFIG}" "${DB_CONTAINER_NAME}:/etc/mysql/conf.d/my.cnf"

# Get our override entrypoint in place.
docker cp "${INIT_ONLY_ENTRYPOINT}" "${DB_CONTAINER_NAME}:/docker-entrypoint.sh"

# Run up a mariadb container with a sql-dump.
echo "Initializing container with dbdump"
docker start -a "${DB_CONTAINER_NAME}"

# Setup the final destination for the datadir, we use /workspace as it's
# a mountpoint with plenty of spaces in Google Cloud Build.
TMP_DATADIR=/workspace/datadir
mkdir -p "${TMP_DATADIR}/var/lib/"
docker cp -a "${DB_CONTAINER_NAME}:/var/lib/mysql" "${TMP_DATADIR}/var/lib/mysql"

# Do some intermediary cleanup already to avoid blowing up the 100GB disk limit.
show_system_state
cleanup
show_system_state

# Build the pre-init data-container, use same tag as the sql-dump image.
echo "Building the datadir image ${DATADIR_IMAGE_DESTINATION}"

# Ok ... so ....  aufs (which will host the datadir for fulldb build) has this
# "feature" where if you create a file/directory with a given ownership and
# permission, subsequent permissions can only be narrower. In other words, if we
# add, say, a datadir owned by root and then change the ownership to mysql -
# strange things can happen when you then try to change things. Specifically
# touch datadir/db/a && rm datadir/db/a will fail on the rm.
# So, to avoid all of that, we do something slightly crazy, we make everything
# in the datadir world write/readable - make a mental note of never ever
# allowing this image to hit prod - and then add the datadir. This way we start
# out with very liberal permissions which makes aufs happy.
# This might be resolved in a future version of Docker so it is worth checking
# whether the following can be removed when this script is updated.
chmod -R a+rw "${TMP_DATADIR}"
find "${TMP_DATADIR}" -type d -print0 | xargs -0 chmod a+x

# Create a temporary container for the datadir. Instead of starting it we'll
# do a snapshot after the data has been copied into it and push that tag.
DATADIR_CONTAINER="datadir_container-${RUN_TOKEN}"
docker container create --name "${DATADIR_CONTAINER}" tianon/true
docker cp "${TMP_DATADIR}/var" "${DATADIR_CONTAINER}:/"

# Do the commit and track the space usage.
show_system_state
docker commit "${DATADIR_CONTAINER}" "${DATADIR_IMAGE_DESTINATION}"
show_system_state

if [[ -z "${NO_PUSH-}" ]]; then
  echo "Pushing ${DATADIR_IMAGE_DESTINATION}"
  docker push "${DATADIR_IMAGE_DESTINATION}"
  docker rmi "${DATADIR_IMAGE_DESTINATION}"
  show_system_state
else
  echo "Datadir image is available as ${DATADIR_IMAGE_DESTINATION}"
fi
