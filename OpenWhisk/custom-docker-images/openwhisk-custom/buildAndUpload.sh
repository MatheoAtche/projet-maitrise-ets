#!/bin/sh

cwd=$(dirname $0)
cd "$cwd/../../openwhisk"
lastCommit=$(git rev-parse --short HEAD)
./gradlew :core:controller:distDocker :core:invoker:distDocker -PdockerRegistry=docker.io -PdockerImagePrefix=matheoatche -PdockerImageTag=$lastCommit
