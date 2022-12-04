#!/bin/bash
##########################################################################
# docker-sysinit.sh - Installation script for Rootless Docker (system side)
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

VERSION="221203"
ubuntumin="1604"
fedoramin="34"

basepkgs="ca-certificates curl gnupg lsb-release qpdfview uidmap"


########################################################################################
#####################################################
function dsi_commandline () {
   local printversion="0"
   while [ $# -gt 0 ]; do
    case $1 in
        -v) VERBOSE=`expr $VERBOSE + 1`; VERBOPT=" -v"; shift;;
        -d) DEBUG=`expr $DEBUG + 1`; STRDEBU="$STRDEBU -d"; shift;;
        -q) QUIET="1"; shift;;
        -b) BYPASS="1"; shift;;
        --version) printversion="1"; shift;;
        -*) usage;;
        *) usage;;
    esac
   done

   # PRINT VERSION
   if [ "$printversion" != "0" ]; then echo "$0: version $VERSION1"; exit 0; fi

}

#####################################################
function setglobalvars() {
   grep=`which grep`; if [ "$grep" = "" ]; then echo "Cannot find 'grep'"; exit 105; fi
   awk=`which awk`; if [ "$awk" = "" ]; then echo "Cannot find 'awk'"; exit 107; fi
   tail=`which tail`; if [ "$tail" = "" ]; then echo "Cannot find 'tail'"; exit 116; fi
   # pre-requisite: md5sum (rpcinfo) lsb_release clone-me.sh <pkg>-prepare.sh

   # version
   md5sig=`md5sum $0|awk '{print $1}'`
   MYSIG="${md5sig:0:2}${md5sig:(-2)}" # reduced-hash: first 2 char and last two char
   VERSION1="v${VERSION}-${MYSIG}"
   MYUSER="$(id -u -n)"
   MYHOME="$(getent passwd `whoami`| cut -d: -f6)"
   MYSCRIPTNAME=`basename $0`
   MYPID="$$" # MY PID
   #bindir="${MYHOME}/bin"

   # Set $SCRIPTPATH to the same directory where this script is
   pushd `dirname $0` > /dev/null
   SCRIPTPATH=`pwd -P`
   popd > /dev/null

   # Save current path
   CURPATH=`pwd -P`

   # DEFAULT OPTIONS
   VERBOSE="0"
   DEBUG="0"
   QUIET="0"
   VERBOPT=""
   STRDEBU=""

   #-----------------------------------------------------------------------------
   # Colors
   black='\E[30;40m'
   red='\E[31;40m'
   green='\E[32;40m'
   yellow='\E[33;40m'
   blue='\E[1;34;40m'
   magenta='\E[35;40m'
   cyan='\E[36;40m'
   white='\E[37;40m'
}

#####################################################
function cecho ()            # Color-echo.
                             # Argument $1 = message
                             # Argument $2 = color
{
local default_msg="No message passed."
                             # Doesn't really need to be a local variable.

message=${1:-$default_msg}   # Defaults to default message.
color=${2:-$white}           # Defaults to white, if not specified.

  echo -en "$color"
  echo -n "$message"
  tput sgr0             # reset to normal
}

#####################################################
function debug2() {
   if [ "$DEBUG" -gt "1" ]; then echo "D2: $1"; fi
}

#####################################################
function debug1() {
   if [ "$DEBUG" -gt "0" ]; then echo "D1: $1"; fi
}

#####################################################
function usage () {
   echo "Usage: $0 [<options>]"
   echo ""
   echo "   <package> is the name of the package to be installed"
   echo ""
   echo "   and <options> can be:"
   echo "   -v                  verbose mode"
   echo "   -q                  quiet   mode"
   echo "   -d                  debug   mode"
   echo "   -b                  bypass  mode (bypass distro check)"
   echo "   --version           print version"
   echo ""
   exit 1
}

#####################################################
function detectdistro {
   local ich0=`which lsb_release 2>&1`
   local ich1=`echo "$ich0"|grep "not found"`
   local ich2=`echo "$ich0"|grep "no lsb_release"`
   local ich3=`which yum 2>&1|grep yum`
   local ich4=`which apt-get 2>&1|grep apt-get`
   local ich5=`which dnf 2>&1|grep dnf`
   if [[ "$ich1" != "" || "$ich2" != "" ]]; then
      # lsb_release not available - try to use /etc/os-release
      if [ -s "/etc/os-release" ]; then
         dist=`cat /etc/os-release|awk -F= '/^NAME/{print $2}'|tr -d '"'|awk '{print $1}'`
         dver=""
         dvernum=`cat /etc/os-release|awk -F= '/^VERSION_ID/{print $2}'|tr -d '"'|awk '{print $1}'`
         dvn1=${dvernum%.*}
      else # try some guess
         if [ "$ich3" != "" -o "$ich5" != "" ]; then
            dist="Fedora"
         fi
         #try
         if [ "$ich4" != "" ]; then
            local un=`uname -a 2>/dev/null|grep "Ubuntu"`
            [ "$un" != "" ] && dist="Ubuntu" || dist="Debian"
         fi
         dver=""
         dvernum=""
         dvn1=""
      fi
   else # lsb_release is present
      dist=`lsb_release -i -s|cut -d " " -f 1`
      dver=`lsb_release -c -s`
      dvernum=`lsb_release -r -s`
      dvn1=${dvernum%.*}
   fi

   distorig=""
   dvernumorig=""
   #patch to use CentOS
   if [ "$dist" = "CentOS" -o "$dist" = "RedHatEnterpriseServer" ]; then
      distorig="$dist"
      dvernumorig="$dvernum"
      dist="Fedora"
      if [ "$dvn1" = "6" ]; then dvernum="14"; fi
   fi
   if [ "$dist" = "n/a" ]; then
      #try to guess then...
      all=`lsb_release -a|grep "Description"`
      dist=`echo "$all"| awk '{print $2}'`
      dver=`echo "$all"| awk '{print $3}'`
   fi
   dvernum2=`echo "$dvernum"|tr -d \.`
   dsmall="${dist,,}"
   # at exit:
   # echo "Distribution '$dist' - Version '$ver'"
}

#####################################################
function distrocheck {
   detectdistro
   #echo "dist=$dist"
   #echo "dver=$dver"
   #echo "dvernum=$dvernum"
   #echo "dvernum2=$dvernum2"
   #echo "dvn1=$dvn1"
   #echo "distorig=$distorig"
   #echo "dvernumorig=$dvernumorig"

   echo "* Distro=$dist Version=$dvernum"

   if [ "$dist" != "Ubuntu" -a "$dist" != "Fedora" -a "$BYPASS" != "1" ]; then
      echo "ERROR: Distro '$dist' is not supported."
      exit 1
   fi
   [ "$dist" = "Ubuntu" ] && mindistro="$ubuntumin"
   [ "$dist" = "Fedora" ] && mindistro="$fedoramin"
   if [ "$dvernum2" -lt "$mindistro" -a "$BYPASS" !=  "1" ]; then
      echo "Version $dvernum of distro $dist is not supported"
      exit 2
   fi

   if [ "$dist" = "Ubuntu" ]; then
      removepkglist="docker docker-engine docker.io containerd runc"
      instpkgs="docker-ce docker-ce-cli containerd.io docker-compose-plugin"
      instcmd="apt -qqy install --reinstall"
      rmvecmd="apt -qqy remove"
      instopt=""
      gpgdir="/etc/apt/keyrings"
      fpreposrc="/etc/apt/sources.list.d/docker.list"
      dcecheck1="apt-file search /usr/bin/docker"
      dcecheck2="egrep \/usr\/bin\/dockerd$"
      basepkgs+=" apt-file iptables-persistent"
      aptupdate="sudo -E apt -y update"
      dockerce="docker-ce"
      [ "$dvernum2" = "1604" ] && { # limited support for Ubuntu 16.04
         instpkgs="docker-ce docker-ce-cli containerd.io docker-compose";
         dockerce="docker.io"
      }
   fi
   if [ "$dist" = "Fedora" ]; then
      removepkglist="docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-selinux \
                  docker-engine-selinux \
                  docker-engine"
      instpkgs="docker-ce docker-ce-cli containerd.io docker-compose-plugin"
      instcmd="dnf -y install"
      rmvecmd="dnf -y remove"
      instopt="--allowerasing"
      gpgdir="/etc/pki/docker"
      fpreposrc="/etc/yum.repos.d/docker-ce.repo"
      dcecheck1="rpm -qf /usr/bin/dockerd"
      dcecheck2="cat"
      aptupdate=""
      dockerce="docker-ce"
   fi
}

##########################################################################
#-- START OF SCRIPT
trap 'cleanup' SIGINT
setglobalvars
dsi_commandline $*
distrocheck

#
export DEBIAN_FRONTEND=noninteractive

echo "* Removing conflicting packages..."
debug1 "removepkglist='$removepkglist'"
for p in $removepkglist; do
   echo "    sudo $rmvecmd $p"
   sudo -E $rmvecmd $p 2>/dev/null >/dev/null
done
echo "  ...done."

#
echo "* Installing base packages..."
debug1 "basepkgs='$basepkgs'"
echo "  - repo update..." 
#$aptupdate 2>/dev/null >/dev/null
echo "  - installation..." 
for p in $basepkgs; do
   echo "    sudo $instcmd $p $instopt"
   sudo -E $instcmd $p $instopt 2>/dev/null >/dev/null
done
echo "  ...done."

## Add Docker’s official GPG key:
echo "* Adding Docker's official GPG key..."
#sudo mkdir -p /etc/apt/keyrings 2>/dev/null >/dev/null
sudo mkdir -p $gpgdir 2>/dev/null >/dev/null
#curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null >/dev/null
sudo rm -f $dpgdir/docker.asc $gpgdir/docker.gpg 2>/dev/null
sudo curl -fsSL https://download.docker.com/linux/$dsmall/gpg --output $gpgdir/docker.asc
cat $gpgdir/docker.asc | sudo gpg --dearmor -o $gpgdir/docker.gpg 2>/dev/null >/dev/null
# FEDORA
[ "$dist" = "Fedora" ] && sudo rpmkeys --import $gpgdir/docker.asc
echo "   ...done"
# sanity check
if [ ! -s $gpgdir/docker.asc -o ! -s $gpgdir/docker.gpg ]; then
   echo "FAILURE: files $gpgdir/docker.asc or $gpgdir/docker.gpg are missing."
   exit 3
fi

#
echo "* Installing Docker repos..."
#UBUNTU
if [ "$dist" = "Ubuntu" ]; then
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
     $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   sudo -E apt -y update 2>/dev/null >/dev/null
   sudo apt-file update 2>/dev/null >/dev/null
fi
# FEDORA
if [ "$dist" = "Fedora" ]; then
   sudo dnf -y install dnf-plugins-core 2>/dev/null >/dev/null
   sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null >/dev/null
fi
echo "  ...done."
# sanity check
if [ ! -s $fpreposrc ]; then
   echo "FAILURE: files $fpreposrc is missing."
   exit 4
fi

#
echo "* Installing Docker packages..."
for p in $instpkgs; do
   echo "    sudo $instcmd $p"
   sudo -E $instcmd $p 2>/dev/null >/dev/null
done
echo "  ...done."
# sanity check
outdcec=`$dcecheck1|$dcecheck2|grep $dockerce 2>/dev/null`
debug2 "$dcecheck1|$dcecheck2|grep $dockerce"
debug2 "outdcec='$outdcec'"
if [ "$outdcec" = "" ]; then
   echo "FAILURE: docker-ce package seems missing."
   echo "Try: 'sudo $instcmd $instpkgs'"
   echo " or: '$dcecheck1|$dcecheck2|grep $dockerce'"
   exit 5
fi

#
echo "* Stopping system daemon..."
sudo systemctl stop docker.service docker.socket 2>/dev/null >/dev/null
sudo systemctl disable docker.service docker.socket 2>/dev/null >/dev/null
echo "  ...done."

#
echo "* Stopping local daemon..."
systemctl --user stop docker.service docker.socket 2>/dev/null >/dev/null
systemctl --user disable docker.service docker.socket 2>/dev/null >/dev/null
echo "  ...done."

#
echo "* Enabling docker.service on system startup..."
sudo loginctl enable-linger $(id -un) 2>/dev/null >/dev/null
echo "  ...done."

# additional setup
echo "* Loading module ip_tables ..."
sudo modprobe ip_tables
echo "  ...done."


# check if slirp4netns is installed (problem in Ubuntu 18.04)
echo "* Checking if slirp4netns is available..."
iss4nok=`which slirp4netns`
if [ "$iss4nok" = "" ]; then
   echo "  - Downloading slip4netns ..."
   sudo curl -o /usr/local/bin/slirp4netns --fail -L https://github.com/rootless-containers/slirp4netns/releases/download/v1.1.12/slirp4netns-$(uname -m)
   sudo chmod +x /usr/local/bin/slirp4netns
fi
echo "  ...done."
iss4nok=`which slirp4netns`
if [ "$iss4nok" = "" ]; then
   echo "FAILURE: slirp4netns is missing"
   exit 6
fi

echo "OK. Bye! `date`"
