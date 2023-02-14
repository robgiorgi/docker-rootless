#!/bin/bash
##########################################################################
# docker-userinit.sh - Installation script for Rootless Docker (user side)
# Copyright (c) Roberto Giorgi 2022-12-03 - FREE SOFTWARE: MIT LICENSE
# University of Siena, Italy
##########################################################################
# MIT LICENSE:
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
##########################################################################
VERSION="230214"

[ "$1" = "-d" ] && DEBUG="1"
#sudo apt -y install docker-ce-rootless-extras docker-ce uidmap xpdf exfat-fuse slirp slirp4netns

echo "* Creating user directories..."
unset DOCKER_HOST
mkdir -p ~/.config/systemd/user/default.target.wants 2>/dev/null
pushd ~/.config/systemd/user/default.target.wants 2>/dev/null >/dev/null
rm -f docker.service 2>/dev/null
ln -s ../docker.service 2>/dev/null
popd 2>/dev/null >/dev/null
#
mkdir ~/.config/systemd/user/docker.service.d 2>/dev/null
echo -e "[Service]\nEnvironment=\"DOCKERD_ROOTLESS_ROOTLESSKIT_PORT_DRIVER=slirp4netns\"\n" >~/.config/systemd/user/docker.service.d/override.conf
systemctl --user disable docker 2>/dev/null >/dev/null
systemctl --user stop docker 2>/dev/null >/dev/null
systemctl --user daemon-reload 2>/dev/null >/dev/null
echo "  ...done."

echo "* Rootless-Docker setup..."
rootlessdock1=`dockerd-rootless-setuptool.sh install 2>/dev/null`
rootlessdock=`dockerd-rootless-setuptool.sh install 2>/dev/null`
[ "$DEBUG" != "1" ] && rootlessdock=`dockerd-rootless-setuptool.sh install 2>/dev/null`
[ "$DEBUG" = "1" ]  && { rootlessdock=`dockerd-rootless-setuptool.sh install 2>&1`; echo "$rootlessdock"; }
#docker context use rootless
rdls="0"; rdlc="0"; rdln="0"
rldsuccess=`echo "$rootlessdock"|grep "Installed docker.service successfully."|awk '{$1="";print $0}'|awk '{$1=$1};1'`
rldcontext=`echo "$rootlessdock"|grep "Successfully created context \"rootless\""`
rldcexists=`echo "$rootlessdock"|grep "CLI context \"rootless\" already exists"|awk '{$1="";print $0}'|awk '{$1=$1};1'`
rldcurrcon=`echo "$rootlessdock"|grep "Current context is now \"rootless\""`
rldcontuse=`echo "$rootlessdock"|grep "Use CLI context \"rootless\""|awk '{$1="";print $0}'|awk '{$1=$1};1'`
if [ "$rldsuccess" = "Installed docker.service successfully." ]; then
   echo "  - Installed docker.service successfully"
   rdls="1"
fi
if [ "$rldcontext" = "Successfully created context \"rootless\"" -o "$rldcexists" = "CLI context \"rootless\" already exists" ]; then
   echo "  - Successfully created context \"rootless\""
   rdlc="1"
fi
if [ "$rldcurrcon" = "Current context is now \"rootless\"" -o "$rldcontuse" = "Use CLI context \"rootless\"" -o "$rdlc" = "1" ]; then
   echo "  - Current context is now \"rootless\""
   rdln="1"
fi
if [ "$rdls" = "1" -a "$rdlc" = "1" -a "$rdln" = "1" ]; then
   echo "  ...Rootless-Docker setup OK."
else
   echo "FAILURE: try again 'dockerd-rootless-setuptool.sh install'."
   exit 1
fi


#mkdir -p ~/.config/systemd/user/default.target.wants && pushd ~/.config/systemd/user/default.target.wants && ln -s ../docker.service && popd
#systemctl --user start docker
#systemctl --user enable docker

#
#export DOCKER_HOST=unix:///home/$(id -un)/.docker/run/docker.sock
export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock
echo "* Exporting: DOCKER_HOST=$DOCKER_HOST"
echo "  ...done"

#
echo "* Adding DOCKER_HOST to .bashrc"
linetoadd="export DOCKER_HOST=unix:///run/user/\$(id -u)/docker.sock"
grep -qxF "$linetoadd" ~/.bashrc|| echo "$linetoadd" >> ~/.bashrc
source ~/.bashrc
echo "  ...done"

#
echo "* Restarting docker..."
systemctl --user daemon-reload
systemctl --user restart docker
sleep 1
echo "  ...done"

#
echo "* Enabling docker.service on system startup..."
loginctl enable-linger $(id -un) 2>/dev/null >/dev/null
echo "  ...done."


#loginctl show-session $XDG_SESSION_ID
#docker run hello-world
#sudo systemctl status systemd-logind

# Verify if docker works
echo "* Verifying if Docker works..."
dockout=`docker run hello-world 2>/dev/null |grep "Hello from Docker!"`
[ "$DEBUG" = "1" ]  && { echo "dockout='$dockout'"; }
if [ "$dockout" = "Hello from Docker!" ]; then
   docker rm $(docker container ls -q --latest) 2>/dev/null >/dev/null
   echo "OK. Bye! `date`"
else
   echo "FAILURE!"
fi
