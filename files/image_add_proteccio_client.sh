#!/usr/bin/env bash

# image_add_proteccio_client.sh
#
# This script adds the Linux Minimal Client for Eviden Trustway Proteccio HSM
# to both the API and Worker images so that the HSM can be used as a PKCS#11
# backend for Barbican.
set -x
set -o errexit
set -o pipefail

BARBICAN_SRC_IMAGE_REGISTRY=${BARBICAN_SRC_IMAGE_REGISTRY:-"quay.io"}
BARBICAN_SRC_IMAGE_NAMESPACE=${BARBICAN_SRC_IMAGE_NAMESPACE:-"podified-antelope-centos9"}
BARBICAN_SRC_API_IMAGE_NAME=${BARBICAN_SRC_API_IMAGE_NAME:-"openstack-barbican-api"}
BARBICAN_SRC_WORKER_IMAGE_NAME=${BARBICAN_SRC_WORKER_IMAGE_NAME:-"openstack-barbican-worker"}
BARBICAN_SRC_IMAGE_TAG=${BARBICAN_SRC_IMAGE_TAG:-"current-podified"}

BARBICAN_SRC_API_IMAGE_FQIN="$BARBICAN_SRC_IMAGE_REGISTRY/$BARBICAN_SRC_IMAGE_NAMESPACE/$BARBICAN_SRC_API_IMAGE_NAME:$BARBICAN_SRC_IMAGE_TAG"
BARBICAN_SRC_WORKER_IMAGE_FQIN="$BARBICAN_SRC_IMAGE_REGISTRY/$BARBICAN_SRC_IMAGE_NAMESPACE/$BARBICAN_SRC_WORKER_IMAGE_NAME:$BARBICAN_SRC_IMAGE_TAG"

BARBICAN_DEST_IMAGE_REGISTRY=${BARBICAN_DEST_IMAGE_REGISTRY:-"quay.io"}
BARBICAN_DEST_IMAGE_NAMESPACE=${BARBICAN_DEST_IMAGE_NAMESPACE:-"podified-antelope-centos9"}
BARBICAN_DEST_API_IMAGE_NAME=${BARBICAN_DEST_API_IMAGE_NAME:-"openstack-barbican-api"}
BARBICAN_DEST_WORKER_IMAGE_NAME=${BARBICAN_DEST_WORKER_IMAGE_NAME:-"openstack-barbican-worker"}
BARBICAN_DEST_IMAGE_TAG=${BARBICAN_DEST_IMAGE_TAG:-"current-podified-proteccio"}

BARBICAN_DEST_API_IMAGE_FQIN="$BARBICAN_DEST_IMAGE_REGISTRY/$BARBICAN_DEST_IMAGE_NAMESPACE/$BARBICAN_DEST_API_IMAGE_NAME:$BARBICAN_DEST_IMAGE_TAG"
BARBICAN_DEST_WORKER_IMAGE_FQIN="$BARBICAN_DEST_IMAGE_REGISTRY/$BARBICAN_DEST_IMAGE_NAMESPACE/$BARBICAN_DEST_WORKER_IMAGE_NAME:$BARBICAN_DEST_IMAGE_TAG"

# PROTECCIO_LINUX_CLIENT_DIR - location of the linux client directory
# in your client media.  This could be a path to a mounted ISO or a path to
# the location where a tarball was extracted.
PROTECCIO_LINUX_CLIENT_DIR=${PROTECCIO_LINUX_CLIENT_DIR:-"/mnt/proteccio_iso"}

VERIFY_TLS=${VERIFY_TLS:-"true"}

function install_client() {

  if [ "$VERIFY_TLS" == "true" ]; then
    container=$(buildah from $1)
  else
    container=$(buildah from --tls-verify=false $1)
  fi

  # set required env
  buildah config --env ConfigurationPath=/etc/proteccio $container

  # add Linux client
  buildah run --user root $container -- mkdir -p /tmp/proteccio
  buildah add --chown root:root $container $PROTECCIO_LINUX_CLIENT_DIR /tmp/proteccio
  buildah run --user root $container -- cd /tmp/proteccio/Linux
  buildah run --user root $container -- bash -c "cd /tmp/proteccio/Linux; { echo \"e\"; echo \"n\"; echo; } | ./install.sh"
  buildah run --user root $container -- rm -rf /tmp/proteccio

  if [ "$VERIFY_TLS" == "true" ]; then
    buildah commit $container $2
    podman push $2
  else
    buildah commit --tls-verify=false $container $2
    podman push --tls-verify=false $2
  fi
  buildah rm $container
}

install_client $BARBICAN_SRC_API_IMAGE_FQIN $BARBICAN_DEST_API_IMAGE_FQIN
install_client $BARBICAN_SRC_WORKER_IMAGE_FQIN $BARBICAN_DEST_WORKER_IMAGE_FQIN
