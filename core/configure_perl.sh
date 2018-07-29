#!/usr/bin/env bash

#_________________________________________________________________________
#                                                                         |
#  Author:   Blake Huber                                                  |
#  Purpose:  # Perl Module Updates | rkhunter                             |
#  Requires: rkhunter, prom                                               |
#  Environment Variables (required, global):                              |
#  User:     $user                                                        |
#  Output:   CLI                                                          |
#  Error:    stderr                                                       |
#  Log:  $pkg_path/logs/prom.log                                          |
#_________________________________________________________________________|


#  Verify DISTRO; install Develpment tools (AML) || build essentials, etc (installs make)
#  Install cpan if not present using distro-specific pkg mgr
#  Update cpan
#  Run perl script to configure cpan if not configured previously.  (possible solution, may want to install cpanm per the link (see below)


# globals
pkg=$(basename $0)                                      # pkg (script) full name
pkg_root="$(echo $pkg | awk -F '.' '{print $1}')"       # pkg without file extention
pkg_path=$(cd $(dirname $0); pwd -P)                    # location of pkg
host=$(hostname)
system=$(uname)
TMPDIR='/tmp'
perlconf_version='1.2'
QUIET="$1"                                              # Supress output to stdout; from caller

# arrays
declare -a ARR_MODULES

# logging
LOG_DIR="$HOME/logs"
if [ ! $LOG_FILE ]; then LOG_FILE="$LOG_DIR/$pkg_root.log"; fi

# source dependencies
if [ $(echo $pkg_path | grep core) ]; then
    # called standalone
    source $pkg_path/colors.sh
    source $pkg_path/exitcodes.sh
    source $pkg_path/std_functions.sh
else
    # called by another script
    source $pkg_path/core/colors.sh
    source $pkg_path/core/exitcodes.sh
    source $pkg_path/core/std_functions.sh
fi


# ---  declarations  -------------------------------------------------------------------------------


function binary_depcheck(){
    ## validate binary dependencies installed
    local check_list=( "$@" )
    local msg
    #
    for prog in "${check_list[@]}"; do
        if ! type "$prog" > /dev/null 2>&1; then
            msg="${title}$prog${bodytext} is required and not found in the PATH. Aborting (code $E_DEPENDENCY)"
            std_error_exit "$msg" $E_DEPENDENCY
        fi
    done
    #
    # <<-- end function binary_depcheck -->>
}


function depcheck(){
    ## validate cis report dependencies ##
    local log_dir="$1"
    local log_file="$2"
    local msg
    #
    ## test default shell ##
    if [ ! -n "$BASH" ]; then
        # shell other than bash
        msg="Default shell appears to be something other than bash. Please rerun with bash. Aborting (code $E_BADSHELL)"
        std_error_exit "$msg" $E_BADSHELL
    fi
    ## logging prerequisites  ##
    if [[ ! -d "$log_dir" ]]; then
        if ! mkdir -p "$log_dir"; then
            std_error_exit "$pkg: failed to make log directory: $log_dir. Exit" $E_DEPENDENCY
        fi
    fi
    if [ ! -f $log_file ]; then
        if ! touch $log_file 2>/dev/null; then
            std_error_exit "$pkg: failed to seed log file: $log_file. Exit" $E_DEPENDENCY
        fi
    fi
    ## check for required cli tools ##
    binary_depcheck perl rkhunter
    # success
    std_logger "$pkg: dependency check satisfied." "INFO" $log_file
    #
    # <<-- end function depcheck -->>
}


function cpan_install(){
    ## os-specific installation of CPAN perl module mgr ##
    local choice
    local os_major="$(echo $(linux_distro) | awk '{print $1}')"
    #
    if [ ! $QUIET ]; then
        std_message "perl Module Manager, CPAN, is not installed on the sytem.  CPAN is required." "INFO"
        read -p "    Do you want to install CPAN?  [yes]: " choice
        if [ -z $choice ] || [ "$choice" = "yes"] || [ "$choice" = "y"]; then
            std_message "Installing perl-CPAN perl module mgr" "INFO" $LOG_FILE
        else
            std_error_exit "User cancel. Exit" $E_DEPENDENCY
        fi
    else
        std_logger "Installing perl-CPAN perl module mgr" "INFO" $LOG_FILE
    fi
    if [ "$( echo $OS_MAJOR | grep -i amazonlinux)" ]; then
        yum install -y "perl-CPAN"
    elif [ "$( echo $OS_MAJOR | grep -i ubuntu)" ]; then
        apt install -y "perl-CPAN"
    elif [ "$( echo $OS_MAJOR | grep -i redhat)" ]; then
        yum install -y "perl-CPAN"
    elif [ "$( echo $OS_MAJOR | grep -i fedora)" ]; then
        dnf install -y "perl-CPAN"
    fi
    std_message "Later in the installation process you will be required to configure cpan.
    \tIn general, you can accept the defaults to all questions" "INFO"
}


function is_installed(){
    ## validate if binary previously installed  ##
    local binary="$1"
    local location=$(which $binary 2>/dev/null)
    if [ $location ]; then
        std_message "$binary is already compiled and installed:  $location" "INFO" $LOG_FILE
        return 0
    else
        return 1
    fi
}


function os_distro(){
    ## determine os linux distribution ##
    local tmpvar
    tmpvar=$(linux_distro)
    OS_MAJOR=$(echo $tmpvar | awk '{print $1}')
    OS_MINOR=$(echo $tmpvar | awk '{print $2}')
    std_message "OS Major Version: $OS_MAJOR" "INFO" $LOG_FILE
    std_message "OS Minor Version: $OS_MINOR" "INFO" $LOG_FILE
    return 0
}


function verify_config(){
    ## verify all perl modules installed ##
    local result_file="$1"
    #
    if [ $(grep -i MISSING $result_file) ]; then
        return 1
    else
        # perl configuration status
        std_message "Perl Module Config for Rkhunter ${green}COMPLETE${bodytext}" "INFO" $LOG_FILE
        return 0
    fi
}


function root_permissions(){
    ## validates required root privileges ##
    if [ $EUID -ne 0 ]; then
        std_message "You must run this installer as root or access root privileges via sudo. Exit" "WARN"
        read -p "    Continue? [quit]: " CHOICE
        if [ -z $CHOICE ] || [ "$CHOICE" = "quit" ] || [ "$CHOICE" = "q" ]; then
            std_message "Re-run as root or execute with sudo:
            \n\t\t$ sudo sh $pkg" "INFO"
            exit 0
        else
            SUDO="sudo"
        fi
    else
        SUDO=''
    fi
    return 0
}


# --- main ----------------------------------------------------------------------------------------


function configure_perl_main(){
    ## main exectuable structure for return to caller ##
    root_permissions
    depcheck $LOG_DIR $LOG_FILE
    os_distro

    std_message "Validing perl-CPAN perl module manger installation dependency" "INFO" $LOG_FILE
    if ! is_installed "cpan"; then cpan_install; fi

    # ----- begin ----- #

    cd $TMPDIR
    RK=$($SUDO which rkhunter)

    # generate list of missing packages:
    std_message "Generating list of missing ${yellow}Perl${reset} Modules. Most malware scans will
          run without these; however, Adding them will increase accuracy
          of scan tests performed by Rkhunter." "INFO"

    if [ $QUIET ]; then
        sudo $RK --list perl 2>/dev/null  | tail -n +3 | grep MISSING | awk '{print $1}' > $TMPDIR/perl_pkg.list
        std_logger "Missing perl modules list:\n $(cat $TMPDIR/perl_pkg.list)" "INFO" $LOG_FILE
    else
        echo -e "\n${title}Rkhunter${bodytext} ${yellow}Perl${reset} Module Dependency Status\n" | indent04
        sudo $RK --list perl 2>/dev/null  | tail -n +3 | tee /dev/tty | grep MISSING | awk '{print $1}' > $TMPDIR/perl_pkg.list
        std_logger "Missing perl modules list:\n $(cat $TMPDIR/perl_pkg.list)" "INFO" $LOG_FILE
    fi

    num_modules=$(cat $TMPDIR/perl_pkg.list | wc -l)

    if [ "$num_modules" = "0" ]; then
        std_message "All perl module dependencies are installed." "INFO" $LOG_FILE
        return 0
    else
        if [ $QUIET ]; then
            std_logger "Skipping user prompt, quiet set (QUIET = $QUIET)" "INFO" $LOG_FILE
        else
            std_message "There are dependencies on ${title}$num_modules${reset} missing modules." "INFO" $LOG_FILE
            read -p "     Do you want to install these missing Perl modules?  [y]:" CHOICE
            if [ -z $CHOICE ] || [ "$CHOICE" = "y" ]; then
                std_message "Begin Perl Module Updates... " "INFO" $LOG_FILE
            else
                std_message "Cancelled by user" "INFO" $LOG_FILE
                exit 1
            fi
        fi
        # build array of all missing modules
        ARR_MODULES=$(cat $TMPDIR/perl_pkg.list)
        cpan_bin=$(which cpan)

        for module in ${ARR_MODULES[@]}; do
            std_message "Installing perl module $module" "INFO" $LOG_FILE
            sleep 2
            if [ $QUET ]; then
                $SUDO $cpan_bin -i $module > /dev/null
                std_logger "cpan installation msgs supressed" "INFO" $LOG_FILE
            else
                $SUDO $cpan_bin -i $module
            fi
        done

        if [ $QUET ]; then
            echo -e "Rkhunter Perl Module Dependency Status" >> $LOG_FILE
            $SUDO $RK --list perl 2>/dev/null | tail -n +3 | tee $LOG_FILE > $TMPDIR/perlresult.txt
            if verify_config $TMPDIR/perlresult.txt; then return 0; else return 1; fi
        else
            # print perl module report
            echo -e "\n${title}Rkhunter${bodytext} Perl Module Dependency Status\n" | indent10
            $SUDO $RK --list perl 2>/dev/null | tail -n +3  | tee /dev/tty > $TMPDIR/perlresult.txt
            if verify_config $TMPDIR/perlresult.txt; then return 0; else return 1; fi
        fi
    fi
}
