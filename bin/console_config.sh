#!/bin/sh

trap "exit 1" EXIT
export TOP_PID=$$

bVerbose=0
bUsage=0
bConsoleinstall_2=0
bUpdated=0

UCI=/sbin/uci
UBUS=/bin/ubus

CONFIG_FILE=/etc/config/onion

CONSOLE=console # change to console later

_Print () {
    if [ $bVerbose == 1 ]; then
        echo $1 >&2
    fi
}

_Usage () {
    _Print ""
    _Print " Attempts to automatically manage opkg package installations based on uci configuration files"
    _Print ""
    _Print "To be used in conjunction with Omega setup wizard"
    _Print ""
}

Check_wwan () {
    waitcount=0
    waitflag=0

    while [ "$waitcount" -le 12 ] &&
        [ "$waitflag" == 0 ]; do
        local resWifi=$($UBUS call network.interface.wwan status | grep up | grep true)
        local resEth=$($UBUS call network.interface.wan status | grep up | grep true)
        if [ "$resWifi" == "" ] &&  [ "$resEth" == "" ];

        then
            sleep 5
            waitcount=$(($waitcount + 1))
        else
            _Print "radio0 is up"
            waitflag=1
        fi
    done
    echo $waitflag
}


Get_console_line () {
    res=$(grep -nr $CONSOLE $CONFIG_FILE)
    result=$(echo $res | sed s/:.*// )
    echo $result
}

Check_setup_inst () {
    package=$1
    res=$($UCI show onion.$CONSOLE.$package | grep -o "'.*'")
    if [ "$res" == "'0'" ]; then
        echo 0
    else
        echo 1
    fi

}

Check_opkg_inst () {
    package="-$1"
    if [ "$package" == "install" ]; then
        #package="base"
        package="" # for testing with Onion-Console
    fi
    res=$(opkg list-installed | grep "onion-$CONSOLE$package")
    if [ "$res" == "" ]; then
        echo 0
    else
        echo 1
    fi
}

Install_opkg () {
    package="onion-console-$1"
    nothing=$(opkg install "$package")
    echo $nothing
}

Remove_opkg () {
    package="onion-console-$1"
    nothing=$(opkg remove "$package")
}

Get_console_config () {
    res=$($UCI show onion.$CONSOLE)
    echo $res
}

Manage_inst () {
    package=$1
    touch /tmp/started_manage
    check_config=$(Check_setup_inst "$package")
    check_opkg=$(Check_opkg_inst "$package")
    _Print "check_config = $check_config, check_opkg = $check_opkg"
    if [ "$check_config" == "1" ]; then
        if [ "$check_opkg" == "0" ]; then
            if [ $bUpdated == 0 ]; then
                _Print "updating opkg"
                $(opkg update &> /dev/null)
                bUpdated=1
            else
                _Print "opkg updated... proceeding to installation"
            fi
            # if [ "$update_check" != "" ]; then
            #     _Print "opkg update unsuccessful... aborting"
            #     exit 0
            # fi
            # uncomment the line below to actually install package through opkg
            if [ "$1" == "install" ]; then
                #package="base"
                # lazar@onion.io: highjacking this to install Onion-OS
                nothing=$(opkg install onion-os)
            else
                nothing=$(Install_opkg "$package")
            fi
            _Print "installing $package"

            # restart rpcd to complete console base installation
            if [ "$1" == "install" ]; then
                # Check if the console is already installed
                _Print "$nothing"
                if [ "$nothing" == "Package onion-console-base (0.2-1) installed in root is up to date." ]; then
                    _Print "$nothing"
                else
                    $(/etc/init.d/rpcd restart)
                fi
            fi
        else
            _Print "current configuration for $package validated"
        fi
    fi
    if [ "$check_config" == "0" ]; then
        if [ "$check_opkg" == "1" ]; then
            if [ $bUpdated == 0 ]; then
                _Print "updating opkg"
                $(opkg update &> /dev/null)
                bUpdated=1
            else
                _Print "opkg updated... proceeding to installation"
            fi
            # if [ "$update_check" != "" ]; then
            #     _Print "opkg update unsuccessful... aborting"
            #     exit 0
            # fi
            # uncomment the line below to actually remove package through opkg
            if [ "$1" == "install" ]; then
                package="base"
            fi
            nothing=$(Remove_opkg "$package")
            _Print "removing $package"
        else
            _Print "current configuration for $package validated"
        fi
    fi
}

Check_install_uci () {
    res=$($UCI get onion.$CONSOLE.install)
    if [ "$res" == "2" ]; then
        echo 2
    else
        echo 0
    fi

}

###############
## MAIN CODE ##
###############
# parse arguments
while [ "$1" != "" ]
do
    case "$1" in
        -v|--v|verbose|-verbose|--verbose)
            bVerbose=1
            shift
        ;;
        -h|--h|help|-help|--help)
            bVerbose=1
            bUsage=1
            shift
        ;;
        -console_install|--console_install|console_install)
            bConsoleinstall_2=1
            shift
        ;;
        *)
            echo "ERROR: Invalid Argument: $1"
            shift
            exit
        ;;
    esac
done

if [ $bUsage == 1 ]; then
    _Usage
    exit
fi

#_Print "$(Get_console_line)"
#console_line=$(Get_console_line)
#_Print "$(sed "$((console_line))!d" $CONFIG_FILE)"
#_Print "$(sed "$((console_line+1))!d" $CONFIG_FILE)"
#_Print "$(sed "$((console_line+2))!d" $CONFIG_FILE)"
#_Print "$(sed "$((console_line+3))!d" $CONFIG_FILE)"
#_Print "$(sed "$((console_line+4))!d" $CONFIG_FILE)"
#_Print "$(sed "$((console_line+5))!d" $CONFIG_FILE)"
#_Print "$(sed "$((console_line+6))!d" $CONFIG_FILE)"

#_Print ""

config=$(Get_console_config)
_Print "$config"
_Print ""

check_wwan=$(Check_wwan)
if [ "$check_wwan" == "0" ]; then
    exit
fi

if [ $bConsoleinstall_2 == 1 ]; then
    install=$(Check_install_uci)
    if [ $install == 2 ]; then
        _Print "Installing onion-console-base"
    # uncomment the line below to actually install the console for install=2 option
        nothing=$(opkg update &> /dev/null)
        nothing=$(Install_opkg base)
        nothing=$($UCI set onion.$CONSOLE.install=1)

        nothing=$($UCI commit)
        _Print "UCI committed"
        # restart rpcd to complete console installation
        $(/etc/init.d/rpcd restart)
    else
        _Print "console already installed... check without -console_install flag"
    fi
fi

# _Print ""
# Manage_inst "setup"

_Print ""
Manage_inst "install"

_Print ""
Manage_inst "editor"

_Print ""
Manage_inst "terminal"

_Print ""
Manage_inst "webcam"

_Print ""
Manage_inst "nodered"
