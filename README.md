# console-install-tool
Tool to automatically install the Onion Console and it's components on the Omega devices

# Usage
The script will check for features to be installed in /etc/config/onion console section (i.e. install, setup, nodered, etc)

If there are any features that should be there (onion.console.[feature]=1) but are not installed (opkg does not find package), the script will install the package. If there are features that should not be there but are there, the script will remove the package.

The script also runs at boot, checking for every feature. Particularly, it will also check for post-boot install (onion.console.install=2).



* This functionality needs to be fixed!

The script will also run when any changes occur to the config file (onion.console.[...]), either through the setup-wizard or directly changing the config file by manually writing to file or using UCI
