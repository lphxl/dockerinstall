#!/usr/bin/env bash
##############################################################################
#    Copyright (C) 2018 phx <https://github.com/phx>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.
##############################################################################
# /var/lib/docker is not removed when uninstalling previous versions of Docker
##############################################################################

if [[ -f logo.ansi ]]; then
  cat logo.ansi
elif command -v 'curl' &> /dev/null; then
  curl -skLf 'https://raw.githubusercontent.com/phx/dockerinstall/master/logo.ansi'
fi

echo -e 'Welcome to The Almost Universal Docker Installer.\n'

# Distro Version Info:
macos="$(uname -a | grep Darwin)"
if [[ -z $macos ]]; then
  release_info="$(cat /etc/*-release)"
  arch="$(echo "$release_info" | grep -i 'ID=arch')"
  centos="$(echo "$release_info" | grep -iE '(ID="centos")|(ID="rhel")|(ID="amzn")')"
  debian="$(echo "$release_info" | grep -i 'ID=debian')"
  fedora="$(echo "$release_info" | grep -i 'ID=fedora')"
  kali="$(echo "$release_info" | grep -i 'ID=kali')"
  raspbian="$(echo "$release_info" | grep -i 'ID=Raspbian')"
  ubuntu="$(echo "$release_info" | grep -i 'ID=ubuntu')"
  version_id=$(echo "$release_info" | grep 'VERSION_ID' | awk -F '"' '{print $2}' | cut -d'.' -f1)
  # fedora $version_id determined later in script
  VERSION="$(echo "$release_info" | grep 'VERSION=' | awk -F '(' '{print $2}' | cut -d')' -f1 | tr "[:upper:]" "[:lower:]" | awk '{print $1}' | awk 'NF>0')"
fi

# Set $USER if unset:
if [[ -z "${USER}" ]]; then
  USER="$(id -un)"
fi

# FUNCTIONS:
show_help() {
echo -e '
Usage: ./install_docker.sh [--interactive | --with-compose]
Installs Docker and/or docker-compose on supported Linux distributions.

--interactive	  Allows more installation options.
--with-compose	Additionally installs docker-compose.
--help	        Shows this help dialog.

If run without parameters, docker will be installed,
the current user will be added to the docker group,
and docker will be enabled to start on boot.

'
}
proxy_check() {
  if [[ -n "$(echo "${@}" | grep interactive)" ]]; then
    echo -e '\n[INFO] This script cannot be run on a proxied network without modifying'
    echo -e '[INFO] $http_proxy, $https_proxy, and setting up both apt and docker proxy config files.'
    echo -e '[INFO] It is MANDATORY to run this script from a non-proxied, external ISP without prior config modification.'
    echo -e '\nARE YOU BEHIND A PROXY???'
    read -rp '[yes/no] ' proxy
  elif [[ (-n "$http_proxy") || (-n "$http_proxy") ]]; then
    proxy='yes'
  else
    proxy='no'
  fi
  if [[ $proxy = yes ]]; then
    echo -e '\nGet your ass out from behind a proxy and try again later.\n'
    exit
  fi
}
error_check() {
  if [[ $? -ne 0 ]]; then
    echo -e "\n[ERROR] $*"
    exit
  fi
}
not_supported() {
  echo -e '\n[ERROR] This script is not currently supported for your operating system.'
  exit 1
}
distro_check_active() {
  echo -e '\nSelect your distribution:\n'
  echo '1) MacOS 10.8+'
  echo '2) Ubuntu'
  echo '3) Debian 8+'
  echo '4) Raspbian 8+'
  echo '5) CentOS/Amazon/RHEL'
  echo '6) Fedora 30+'
  echo '7) Arch'
  echo '8) Kali 2018+'
  echo
  read -rp 'Distro Number: ' DISTRO
  if [[ $DISTRO -eq 1 ]]; then
    export DISTRO_NAME='macos'
  elif [[ $DISTRO -eq 2 ]]; then
    export DISTRO_NAME='ubuntu'
  elif [[ $DISTRO -eq 3 ]]; then
    export DISTRO_NAME='debian'
  elif [[ $DISTRO -eq 4 ]]; then
    export DISTRO_NAME='raspbian'
  elif [[ $DISTRO -eq 5 ]]; then
    export DISTRO_NAME='centos'
  elif [[ $DISTRO -eq 6 ]]; then
    export DISTRO_NAME='fedora'
  elif [[ $DISTRO -eq 7 ]]; then
    export DISTRO_NAME='arch'
  elif [[ $DISTRO -eq 8 ]]; then
    export DISTRO_NAME='kali'
  else
    not_supported
  fi
}
distro_check_passive() {
  # FIND IF SUPPORTED:
  if [[ -n $arch ]]; then
    DISTRO_NAME='arch'
  elif [[ -n $debian ]]; then
    DISTRO_NAME='debian'
    if [[ $version_id -lt 8 ]]; then
      not_supported
    fi
  elif [[ -n $raspbian ]]; then
    DISTRO_NAME='raspbian'
    if [[ $version_id -lt 8 ]]; then
      not_supported
    fi
  elif [[ -n $fedora ]]; then
    DISTRO_NAME='fedora'
    version_id=$(echo "$release_info" | grep 'VERSION_ID' | cut -d'=' -f2)
    if [[ $version_id -lt 30 ]]; then
      not_supported
    fi
  elif [[ -n $centos ]]; then
    DISTRO_NAME='centos'
  elif [[ -n $kali ]]; then
    DISTRO_NAME='kali'
    if [[ $version_id -lt 2018 ]]; then
      not_supported
    fi
  elif [[ -n $ubuntu ]]; then
    DISTRO_NAME='ubuntu'
    if [[ $version_id -lt 16 ]]; then
      not_supported
    fi
  elif [[ -n $macos ]]; then
    DISTRO_NAME='macos'
  fi
}
pkg_manager_config() {
  if command -v apt-get &> /dev/null; then
    if [[ $USER != 'root' ]]; then
      PKG_MANAGER='sudo apt-get'
    else
      PKG_MANAGER='apt-get'
    fi
    UPDATE_PKG_CACHE="${PKG_MANAGER} update"
    PKG_INSTALL="${PKG_MANAGER} --yes install"
    PKG_REMOVE="${PKG_MANAGER} --silent --yes"
  elif command -v pacman &> /dev/null; then
    if [[ $USER != 'root' ]]; then
      PKG_MANAGER='sudo pacman'
    else
      PKG_MANAGER='pacman'
    fi
    UPDATE_PKG_CACHE="${PKG_MANAGER} -Sy"
    PKG_INSTALL="${PKG_MANAGER} --noconfirm -S"
    PKG_REMOVE="${PKG_MANAGER} --noconfirm -Rsn"
  elif [[ $DISTRO = "centos" ]]; then
    if [[ $USER != 'root' ]]; then
      PKG_MANAGER='sudo yum'
    else
      PKG_MANAGER='yum'
    fi
    UPDATE_PKG_CACHE="${PKG_MANAGER} check-update"
    PKG_INSTALL="${PKG_MANAGER} install -y"
    PKG_REMOVE="${PKG_MANAGER} remove -y"
  elif command -v dnf &> /dev/null; then
    if [[ $USER != 'root' ]]; then
      PKG_MANAGER='sudo dnf'
    else
      PKG_MANAGER='dnf'
    fi
    UPDATE_PKG_CACHE="${PKG_MANAGER} check-update"
    PKG_INSTALL="${PKG_MANAGER} install -y"
    PKG_REMOVE="${PKG_MANAGER} remove -y"
  elif [[ $DISTRO_NAME = "macos" ]]; then
    if command -v brew &> /dev/null; then
      PKG_MANAGER='brew'
      UPDATE_PKG_CACHE="${PKG_MANAGER} update"
      PKG_INSTALL="${PKG_MANAGER} install"
      PKG_REMOVE="${PKG_MANAGER} uninstall"
    else
      echo -e "\nThis installation requires the Homebrew package manager.\n"
      read -rp 'Do you wish to install Homebrew now? [y/n] ' homebrew
      if [[ ($homebrew = y) || ($homebrew = yes) ]]; then
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
      else
        not_supported
      fi
    fi
  else
    not_supported
  fi
}
remove_packages() {
  echo -e '\n[INFO] Removing any existing Docker packages...'
  declare -a pkgs_to_remove=(docker docker.io docker-machine docker-compose docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine)
  ${PKG_REMOVE} "${pkgs_to_remove[@]}" 2>/dev/null
  if [[ $INTERACTIVE -eq 1 ]]; then
    if [[ -d /var/lib/docker ]]; then
      read -rp 'Do you want to remove /var/lib/docker, which contains any existing images? [y/n] ' remove_images
      if [[ $remove_images = "y" ]]; then
        sudo rm -rf /var/lib/docker
      fi
    fi
  fi
}

###################################################################
# START:
###################################################################

# Show help:
if [[ -n $(echo "${@}" | grep -E '(\-h)|(help)') ]]; then
  show_help && exit
fi

# Check for interaction:
if [[ -n $(echo "${@}" | grep 'interactive') ]]; then
  INTERACTIVE=1
fi

# Check that the user is not behind a proxy:
proxy_check

# INSTALL DOCKER:
if [[ $INTERACTIVE -eq 1 ]]; then
  docker='yes'
  if command -v 'docker' &> /dev/null; then
    read -rp 'Do you wish to reinstall Docker? [yes/no] ' docker
  fi
else
  docker='yes'
fi

if [[ $docker != "yes" ]]; then
  echo -e '\nDocker appears to already be installed.'
  exit
fi

if [[ $INTERACTIVE -eq 1 ]]; then
  distro_check_active
else
  distro_check_passive
fi

# CONFIGURE PACKAGE MANAGER:
pkg_manager_config

if [[ ($DISTRO_NAME != "kali") && ($USER = "root") ]]; then
  echo -e '\n[ERROR] This script should be run by a non-root user except on Kali Linux.'
  exit 1
fi

# INSTALL DEPENDENCIES:
echo -e '\n[INFO] Updating the package cache...'
${UPDATE_PKG_CACHE}
echo -e '\n[INFO] Installing any necessary dependencies...'
if [[ -n $(echo "$PKG_MANAGER" | grep 'apt') ]]; then
  ${PKG_INSTALL} sudo apt-transport-https ca-certificates curl software-properties-common
else
  ${PKG_INSTALL} sudo ca-certificates curl
fi
if [[ $DISTRO_NAME = "fedora" ]]; then
  ${PKG_INSTALL} dnf-plugins-core grubby
fi
if [[ $DISTRO_NAME = "centos" ]]; then
  ${PKG_INSTALL} yum-utils
  if [[ -z $(${PKG_MANAGER} repolist | grep -i 'Extras') ]]; then
    ${PKG_MANAGER} config-manager --set-enabled extras
    ${UPDATE_PKG_CACHE}
  fi
  ${PKG_INSTALL} device-mapper-persistent-data lvm2
fi

# DOWNLOAD DOCKER GPG KEY:
gpg_info() { echo -e '\n[INFO] Adding Docker GPG key...'; }
if [[ ($DISTRO_NAME = "debian") || ($DISTRO_NAME = "kali") ]]; then
  gpg_info
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
  error_check 'Problem adding Docker GPG key.'
elif [[ $DISTRO_NAME = "raspbian" ]]; then
  gpg_info
  curl -fsSL https://download.docker.com/linux/raspbian/gpg | sudo apt-key add -
  error_check 'Problem adding Docker GPG key.'
elif [[ $DISTRO_NAME = "fedora" ]]; then
  gpg_info
  sudo rpm --import https://download.docker.com/linux/fedora/gpg
  sudo rpmkeys --import https://download.docker.com/linux/fedora/gpg
  error_check 'Problem adding Docker GPG key.'
elif [[ $DISTRO_NAME = "centos" ]]; then
  gpg_info
  sudo rpm --import https://download.docker.com/linux/centos/gpg
  sudo rpmkeys --import https://download.docker.com/linux/centos/gpg
  error_check 'Problem adding Docker GPG key.'
elif [[ $DISTRO_NAME = "ubuntu" ]]; then
  gpg_info
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  error_check 'Problem adding Docker GPG key.'
fi

# REMOVE UNOFFICIAL PACKAGES:
if [[ $DISTRO = "macos" ]]; then
  osascript -e 'quit app "Docker"'
  remove_packages
else
  remove_packages
fi

if [[ ($DISTRO_NAME != arch) || ($DISTRO_NAME != macos) ]]; then
  # ADDING OFFICIAL REPOS:
  docker_repo() { echo -e '\n[INFO] Adding Official Docker repository...'; }
  if [[ $DISTRO_NAME = "debian" ]]; then
    docker_repo
    # sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian ${VERSION} stable"
  elif [[ $DISTRO_NAME = "raspbian" ]]; then
    docker_repo
    echo "deb https://download.docker.com/linux/raspbian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
  elif [[ $DISTRO_NAME = "kali" ]]; then
    docker_repo
    if [[ $version_id -ge 2020 ]]; then
      echo 'deb https://download.docker.com/linux/debian buster stable' | sudo tee /etc/apt/sources.list.d/docker.list
    else
      echo 'deb https://download.docker.com/linux/debian stretch stable' | sudo tee /etc/apt/sources.list.d/docker.list
    fi
  elif [[ $DISTRO_NAME = "ubuntu" ]]; then
    docker_repo
    # sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu ${VERSION} stable"
  elif [[ $DISTRO_NAME = "fedora" ]]; then
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
  elif [[ $DISTRO_NAME = "centos" ]]; then
    sudo yum config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  fi
  error_check 'Error adding Docker repository'
fi

# TOUCH WORKAROUND FOR OVERLAY2 FS ON CENTOS PRIOR TO RHEL/CentOS 6.8/7.2:
if [[ ($DISTRO_NAME = "centos") ]]; then
  sudo touch /var/lib/rpm/*
fi

# INSTALL DOCKER:
echo -e '\n[INFO] Updating the package cache...'
${UPDATE_PKG_CACHE}
echo -e '\n[INFO] Installing docker...'
if [[ $DISTRO_NAME = "arch" ]]; then
  ${PKG_INSTALL} docker
elif [[ $DISTRO_NAME = "fedora" ]]; then
  ${PKG_INSTALL} docker-ce docker-ce-cli containerd.io
  if [[ $version_id -ge 31 ]]; then
    sudo grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=0"
  fi
elif [[ $DISTRO_NAME = "centos" ]]; then
  ${PKG_INSTALL} --nobest docker-ce docker-ce-cli containerd.io
elif [[ $DISTRO_NAME = "macos" ]]; then
  if [[ -d /Applications/Docker.app ]]; then
    osascript -e 'quit app "Docker"'
    brew reinstall docker
  else
    brew cask install docker
  fi
else
  ${PKG_INSTALL} docker-ce
fi
error_check 'Error installing Docker'

# INSTALL DOCKER-COMPOSE:
if [[ -n $(echo "${@}" | grep 'with-compose') ]]; then
  if [[ ($DISTRO_NAME != "macos") && ($DISTRO_NAME != "centos") ]]; then
    echo -e '\n[INFO] Installing docker-compose...'
    ${PKG_INSTALL} docker-compose
    error_check 'Error installing Docker Compose'
  elif [[ $DISTRO_NAME = "centos" ]]; then
    ${PKG_INSTALL} python3 python3-pip
    pip3 install docker-compose --user
  fi
fi

# ADD NON-ROOT DOCKER USER:
if [[ $DISTRO_NAME != "macos" ]]; then
  if [[ -n $(echo "${@}" | grep 'interactive') ]]; then
    if [[ $LOGNAME != root ]]; then
      echo -e "\nDocker can be run by normal users without having to use 'sudo'."
      echo "You should first look into security implications of this functionality."
      echo "You can always do this later as root by running the following command:"
      echo "usermod -aG docker ${LOGNAME}"
      echo -e '\nDo you wish to add the current user to the docker group?'
      read -rp '[yes/no] ' dockeruser
    fi
  else
    dockeruser=yes
  fi
  if [[ $dockeruser = "yes" ]]; then
    sudo groupadd docker 2>/dev/null
    sudo usermod -aG docker "${LOGNAME}"
    echo -e "\n[INFO] You will need to run su - ${LOGNAME} to inherit docker group privileges."
  fi
fi

# ENABLE DOCKER:
if [[ -n $(echo "${@}" | grep 'interactive') ]]; then
  echo -e '\nDo you want Docker to start on boot?'
  read -rp '[yes/no] ' enable
else
  enable=yes
fi
if [[ $enable = "yes" ]]; then
  echo -e '\n[INFO] Enabling Docker to start on boot...'
  if [[ $DISTRO_NAME = macos ]]; then
    osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Docker.app", hidden:true}' > /dev/null 2>&1
  else
    sudo systemctl enable docker
  fi
fi

# START DOCKER
echo -e '\n[INFO] Starting Docker...'
if [[ $DISTRO_NAME = "macos" ]]; then
  open /Applications/Docker.app
else
  sudo systemctl start docker
fi

# CENTOS - CONFIGURE DOCKER TO USE OVERLAY2 DRIVER:
if [[ $DISTRO_NAME = "centos" ]]; then
  sudo systemctl stop docker
  sudo cp -au /var/lib/docker /var/lib/docker.bk
  echo -e '{\n  "storage-driver": "overlay2"\n}' | sudo tee '/etc/docker/daemon.json' >/dev/null 2>&1
  sudo systemctl start docker
fi

# FINISH
error_check 'Something went wrong.'
if [[ $DISTRO_NAME != "macos" ]]; then
  if [[ $LOGNAME != "root" ]]; then
    echo -e "\n[INFO] You may need to run su - ${USER} to inherit docker group privileges."
  fi
fi
if [[ $DISTRO_NAME = "centos" ]]; then
  echo -e '\nYou may need to create firewall rules or disable firewalld in order to enable DNS resolution inside of containers.'
  echo -e 'A reboot may be required afterwards.'
  if [[ $INTERACTIVE -eq 1 ]]; then
    read -rp 'Would you like to disable firewalld? [yes/no] ' disable_firewall
    if [[ $disable_firewall = "yes" ]]; then
      sudo systemctl stop firewalld
      sudo systemctl disable firewalld
    fi
  fi
fi
echo -e '\n[SUCCESS] Installation Complete.'
