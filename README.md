# The Almost Universal Docker Installer

Supported Operating Systems:

- Debian
- Raspbian
- Ubuntu
- Kali 2018+ based on Debian Stretch
- Arch
- MacOS

(RPM-based distro support coming soon.)

```
Usage: ./install_docker.sh [--interactive | --with-compose]
Installs Docker and/or docker-compose on supported Linux distributions.

-h --help	Shows this help dialog.

--interactive	Allows more installation options.

--with-compose	Additionally installs docker-compose.

If run without parameters, docker will be installed,
the current user will be added to the docker group,
and docker will be enabled to start on boot.
```
