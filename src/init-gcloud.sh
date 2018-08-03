#!/usr/bin/env bash
#
# If the proper variables are detected - setup gcp integration.
set -eo pipefail

if [[ -z $GCLOUD_SERVICE_ACCOUNT || -z $GCLOUD_PROJECT  ]]; then
	exit
fi

echo "Activating Google Cloud Platform account for ${GCLOUD_PROJECT}"

echo -n "$GCLOUD_SERVICE_ACCOUNT" | base64 --decode > ${HOME}/gcloud-service-key.json
gcloud auth activate-service-account --key-file ${HOME}/gcloud-service-key.json
gcloud config set project $GCLOUD_PROJECT
gcloud auth configure-docker --quiet
