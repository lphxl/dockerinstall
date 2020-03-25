![Platform: Linux](https://img.shields.io/badge/platform-Linux%20and%20MacOS-blue)
![Dependencies: BASH](https://img.shields.io/badge/dependencies-BASH-blue)
![Version: Latest](https://img.shields.io/badge/version-latest-green)
![Follow @rubynorails on Twitter](https://img.shields.io/twitter/follow/rubynorails?label=follow&style=social)


![logo](./logo.png?raw=true)


# The Almost Universal Docker Installer

**Why this script is better than the official [Docker Convenience Scripts](https://docs.docker.com/install/linux/docker-ce/centos/#install-using-the-convenience-script):**

- It installs latest **STABLE** release (instead of *Edge* or *Testing* release).
- It has the ability to re-install or uninstall previous Docker installations.
- It has the ability to install Homebrew for MacOS with Docker Desktop installed via Cask.
- I created it before there were ever any *official convenience scripts*, so it's got a good track record.

I've never tried the official convenience scripts, because I have no reason to install an unstable version of Docker.

I can't say for sure, because I've never even looked at Docker's convenience scripts, but I would be genuinely surprised if they supported MacOS, Kali, and Arch.

---

## Tested and Supported Operating Systems:

- MacOS 10.8+
- Ubuntu
- Debian 8+
- Raspbian 8+
- Centos/RHEL/Amazon Linux
- Fedora 30+
- Arch
- Kali 2018+ based on Debian Stretch

## Installation

```
git clone https://github.com/phx/dockerinstall.git
cd dockerinstall
./install_docker.sh --interactive
```

## Usage

```
Usage: ./install_docker.sh [--interactive | --with-compose]
Installs Docker and/or docker-compose on supported Linux distributions.

--interactive	Allows more installation options.

--with-compose	Additionally installs docker-compose.

--help	        Shows this help dialog.

If run without parameters, docker will be installed,
the current user will be added to the docker group,
and docker will be enabled to start on boot.
```
