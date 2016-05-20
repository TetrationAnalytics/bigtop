#!/bin/bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# The following script adds a docker container running centos using VirtualBox
#  docker-machine create --driver virtualbox bigtop
#  docker-machine start bigtop
#  eval $(docker-machine env bigtop)

# After running this script, do ensure the following:
# a) packages.gradle -
#    change APACHE_ARCHIVE: "http://192.168.1.3:8000" to point to any directory
#    which has the tar.gz organized for the locally built hbase tar images
# At this point you can skip to c) if you are running on the centos VM within VPN.
# b) copy ~/bigtop to ~/bigtop2
# c) ./gradlew hbase-rpm
# RPMs will be in output directory
# THis needs the artifactory to be available with the version of jars which
# you need. Can be used for patch testing purposes.


set -e               # exit on error

cd "$(dirname "$0")" # connect to root

if [ "$(uname -s)" == "Linux" ]; then
  USER_NAME=${SUDO_USER:=$USER}
  USER_ID=$(id -u "${USER_NAME}")
  GROUP_ID=$(id -g "${USER_NAME}")
else # boot2docker uid and gid
  USER_NAME=$USER
  USER_ID=1000
  GROUP_ID=50
fi

docker build -t "bigtop-build-${USER_NAME}" - <<UserSpecificDocker
FROM centos
RUN groupadd --non-unique -g ${GROUP_ID} ${USER_NAME}
RUN useradd -g ${GROUP_ID} -u ${USER_ID} -k /root -m ${USER_NAME}
ENV HOME /home/${USER_NAME}
RUN yum -y install unzip
RUN yum -y install rpm-build
RUN yum -y install maven
RUN yum -y install java-1.7.0-openjdk-devel.x86_64
ENV JAVA_HOME="/usr/lib/jvm/java-1.7.0-openjdk/"
UserSpecificDocker

# By mapping the .m2 directory you can do an mvn install from
# within the container and use the result on your normal
# system.  And this also is a significant speedup in subsequent
# builds because the dependencies are downloaded only once.
# -v "${HOME}/.m2:/home/${USER_NAME}/.m2" \
# Add the above line if you want to use artifactory.tetration...
# Does not work within VPN yet,, so kind of no-op for now.
docker run --rm=true -t -i \
  -v "${PWD}/.:/home/${USER_NAME}/bigtop:z" \
  -w "/home/${USER_NAME}/bigtop" \
  -u "${USER_NAME}" \
  "bigtop-build-${USER_NAME}"
