#!/bin/bash

cwd=$(dirname $0)
cd "$cwd/../../openwhisk"
lastCommit=$(git rev-parse --short HEAD)
./gradlew :core:controller:distDocker :core:invoker:distDocker -PdockerRegistry=docker.io -PdockerImagePrefix=matheoatche -PdockerImageTag=$lastCommit

pushd "../openwhisk-scheduler/script" >/dev/null 2>&1
    pwd
    ./docker_build.sh
popd >/dev/null 2>&1
