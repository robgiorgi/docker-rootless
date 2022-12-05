# docker-rootless
Installation Scripts for Rootless Docker
---------------------
The installation requires to parts: one part to be executed with sudo permissions
(here I assume you are added as sudoers with no password check) and one part to be
executed for each user who needs the Rootless Docker.

* PART-1: system wide installation
```bash
sudo ./docker-sysinit.sh
```
If everything goes well, an 'OK' message is printed at the end of the script.

* PART-2: per-user installation
```bash
./docker-userinit.sh
```
If everything goes well, an 'OK' message is printed at the end of the script.
IMPORTANT NOTE: in order to execute the docker-userinit.sh on another user,
it is necessary to actually create a login session (e.g., via ssh or machinectl):
somethink like 'su - <user>' and then docker-userinit.sh will not work!

Please note that these two scripts are in a 'beta' version. They have been tested on
- `Fedora 37`
- `Ubuntu 22.04` 
- `Ubuntu 20.04` 
- `Ubuntu 18.04` 
- `Ubuntu 16.04` 

You are welcome to improve these scripts! :-)
For further documentation I recommend the official Docker documentation:
- https://docs.docker.com/engine/security/rootless/
