#!/usr/bin/env bash

set -xe

if [ -z "$OS_NAME" ]; then
    echo "Unexpected: OS_NAME is empty"
    exit 1
fi
if [ -z "$OS_VER" ]; then
    echo "Unexpected: OS_VER is empty"
    exit 1
fi

if [ -z "$DOCKER_PASSWORD" ]; then
    echo "DOCKER_PASSWORD is not defined"
    exit 1
fi


# Install jq if necessary
if ! hash jq; then
    sudo apt -yqq update
    sudo apt install -yqq jq
fi

TARGET_TAG="foreigncc/$OS_NAME-for-ci:$OS_VER"

# Check if we needed build
# Use skopeo project
if [ "$TRAVIS_EVENT_TYPE" = "cron" ]; then
    sudo docker pull alexeiled/skopeo
    base="$(sudo docker run --rm alexeiled/skopeo skopeo inspect "docker://docker.io/$OS_NAME:$OS_VER" | jq -r '.Layers[-1]')"
    expect="$(sudo docker run --rm alexeiled/skopeo skopeo inspect "docker://docker.io/$TARGET_TAG" | jq -r '.Layers[-2]')"
    if [ "$base" = "$expect" ]; then
        echo "Image $OS_NAME:$OS_VER is latest. Do nothing."
        exit 0
    fi
fi



sudo docker login --username "foreigncc" --password "$DOCKER_PASSWORD"


rm -rf build
mkdir build
cd build

case "$OS_NAME" in
    "ubuntu"|"debian"):
        cp ../Dockerfile.apt ./Dockerfile
        ;;
    "centos"|"fedora"):
        cp ../Dockerfile.yum ./Dockerfile
        ;;
    *):
        echo "Unknown OS_NAME: $OS_NAME"
        exit 1
        ;;
esac

# Do substitution
set +x
env | while IFS=$'\n' read -r envvar; do
    IFS='=' read -r name value <<<"$envvar"
    name="${name//\\/\\\\}"
    value="${value//\\/\\\\}"
    #echo "[$name][$value]"
    sed -i "s/@${name//\//\\/}@/${value//\//\\/}/g" Dockerfile
done
set -x

echo "Substitution done"
cat Dockerfile

sudo docker build --rm --force-rm --pull --tag "${TARGET_TAG}" .
sudo docker push "${TARGET_TAG}"
