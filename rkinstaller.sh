#!/usr/bin/env bash

# globals
pkg=$(basename $0)                                      # pkg (script) full name
pkg_root="$(echo $pkg | awk -F '.' '{print $1}')"       # pkg without file extention
pkg_path=$(cd $(dirname $0); pwd -P)                    # location of pkg
TMPDIR='/tmp'
CALLER="$(who am i | awk '{print $1}')"                 # Username assuming root
NOW=$(date +"%Y-%m-%d %H:%M")

# confiugration file
CONFIG_DIR="$HOME/.config/rkhunter"
CONFIG_FILE='config.json'
declare -A config_dict

# logging
LOG_DIR="/var/log"
LOG_FILE="$LOG_DIR/$pkg_root.log"

# rkhunter system properties database
SYSPROP_DATABASE="/var/lib/rkhunter/db/rkhunter.dat"

# rkhunter components
RKVERSION='1.4.6'        # rkhunter version
URL="https://sourceforge.net/projects/rkhunter/files/rkhunter/$RKVERSION"
base="rkhunter-$RKVERSION"
gzip=$base'.tar.gz'
checksum=$gzip'.sha256'
perl_script="$pkg_path/core/configure_perl.sh"
skdet_script="$pkg_path/core/configure_skdet.sh"

# installer version
source $pkg_path/core/_version.sh
VERSION=$__version__
# references for standard functionality
source $pkg_path/core/std_functions.sh
# exit codes
source $pkg_path/core/exitcodes.sh
# formmating
source $pkg_path/core/colors.sh
# script version info (must be last file sourced)
source $pkg_path/core/_version.sh

# special colors
ORANGE='\033[0;33m'
header=$(echo -e ${bold}${brightred})
bd=$(echo -e ${reset}${bold})                           # bold
by=$(echo -e ${yellow})                                 # bright yellow
ul=$(echo -e ${underline})                              # underline
bodytext=${reset}

# --- declarations ------------------------------------------------------------


function help_menu(){
    cat <<EOM

                          ${header}Rkhunter ${bd}Installer${bodytext}

  ${title}DESCRIPTION${bodytext}

        Bash utility to install latest version of rkhunter on local machine.
        See Rkhunter official project site: ${url}http://rkhunter.sourceforge.net${bodytext}

  ${title}SYNOPSIS${bodytext}

          $  sh ${title}$pkg${bodytext}   --install   [ --layout {${by}/usr${reset} | ${by}/usr/bin${reset}} ]

                          -d | --download
                          -i | --install
                         [-c | --clean      ]
                         [-C ] --configure  ]
                         [-f | --force      ]
                         [-h | --help       ]
                         [-l | --layout     ]
                         [-q | --quiet      ]
                         [-r | --remove     ]

  ${title}OPTIONS${bodytext}
        ${title}-c${reset},${title}--clean${bodytext}:  Remove installation artifacts. Clean up automatically
            executes after installation.

        ${title}-C${reset},${title}--configure${bodytext} <value>:  Configure used with one of the following
            values. Use --configure by itself to find out more detail

            o ${title}local${reset} - Configure a new local configuration file. Must
                be used with --force option if local configuration file
                already exists:

                    $ ${bd}$pkg${bodytext} --configure ${by}local${bodytext}

            o ${title}display${reset} - Display the local configuration file if exits:

                    $ ${bd}$pkg${bodytext} --configure ${by}display${bodytext}

            o ${title}perl${reset} - Manually install missing Rkhunter perl module
                library dependencies:

                    $ ${bd}$pkg${bodytext} --configure ${by}perl${bodytext}

            o ${title}skdet${reset} - Compile the skdet C Library dependency:

                    $ ${bd}$pkg${bodytext} --configure ${by}skdet${bodytext}

            o ${title}unhide${reset} - Compile the unhide C Library dependency:

                    $ ${bd}$pkg${bodytext} --configure ${by}unhide${bodytext}

        ${title}-d${reset},${title}--download${bodytext}:  Download all installation artificts, then exit.

        ${title}-f${reset},${title}--force${reset} (parameter):  Force an operation indicated by other com-
            mand switch parameters

        ${title}-l${reset},${title}--layout${reset} (parameter): Installation directory parameter used only
            when installing rkhunter (--install). Example:

                $ ${bd}$pkg${bodytext} --install ${by}--layout /usr${bodytext}

            If omitted during installation, defaults to ${white}/usr/local/bin${bodytext}

        ${title}-q${reset},${title}--quiet${reset} (parameter): Supress all stdout output. For use in unat-
            tended scripts or configuration management operations

        ${title}-r${reset},${title}--remove${reset} (parameter): Remove Rkhunter and components
  _________________________________________________________________________

                ${ul}Note${bodytext}: this installer must be run as root.
  _________________________________________________________________________

EOM
    #
    # <-- end function put_rule_help -->
}

function parse_parameters() {
    if [[ ! "$@" ]]; then
        help_menu
        exit 0
    else
        while [ $# -gt 0 ]; do
            case $1 in
                -h | --help)
                    help_menu
                    shift 1
                    exit 0
                    ;;
                -c | --clean)
                    CLEAN_UP="true"
                    shift 1
                    ;;
                -C | --configure)
                    if [ $2 ]; then
                        case $2 in
                            "local" | "file" | "uninstall" | "UNINSTALL" | "uninstaller" | "UNINSTALLER")
                                CONFIGURE_UNINSTALL="true"
                                shift 2
                                ;;
                            "display" | "show" | "file")
                                CONFIGURE_DISPLAY="true"
                                shift 2
                                ;;
                            "perl" | "Perl")
                                CONFIGURE_PERL="true"
                                shift 2
                                ;;
                            "skdet" | "Skdet")
                                CONFIGURE_SKDET="true"
                                shift 2
                                ;;
                            "unhide" | "Unhide")
                                CONFIGURE_UNHIDE="true"
                                shift 2
                                ;;
                            *)
                                std_error_exit "unknown parameter. Exiting" $E_DEPENDENCY
                                ;;
                        esac
                    else
                        CONFIGURATION="true"
                        shift 1
                    fi
                    ;;
                -d | --download)
                    DOWNLOAD_ONLY="true"
                    shift 1
                    ;;
                -f | --force)
                    FORCE="true"
                    shift 1
                    ;;
                -l | --layout)
                    if [ $2 ]; then
                        LAYOUT="$2"
                    else
                        std_error_exit "You must supply a path with the layout parameter. Example:
                        \n\t\t$ sh rkhunter-install.sh --layout /usr" 1
                    fi
                    shift 2
                    ;;
                -i | --install)
                    INSTALL="true"
                    shift 1
                    ;;
                -q | --quiet)
                    QUIET="true"
                    shift 1
                    ;;
                -r | --remove)
                    UNINSTALL="true"
                    shift 1
                    ;;
                *)
                    std_error_exit "unknown parameter. Exiting" $E_DEPENDENCY
                    ;;
            esac
        done
    fi
    # set default for layout
    if [ ! $LAYOUT ]; then
        LAYOUT="default"
    fi
    #
    # <-- end function parse_parameters -->
}

function binary_depcheck(){
    ## validate binary dependencies installed
    local check_list=( "$@" )
    local msg
    #
    for prog in "${check_list[@]}"; do
        if ! type "$prog" > /dev/null 2>&1; then
            msg="${title}$prog${reset} is required and not found in the PATH. Aborting (code $E_DEPENDENCY)"
            std_error_exit "$msg" $E_DEPENDENCY
        fi
    done
    #
    # <<-- end function binary_depcheck -->>
}

function clean_up(){
    ## rmove installation files ##
    local dir="$1"
    #
    if [ $dir ]; then
        rm -fr $dir
    else
        cd $pkg_path
        std_message "Remove installation artificts" "INFO"
        for residual in $base $base'.tar' $gzip $checksum; do
            rm -fr $residual
            std_message "Removing $residual." "INFO" $LOG_FILE
        done
    fi
}

function configuration_file(){
    ## parse config file parameters ##
    local config_dir="$1"
    local config_file="$2"
    #
    if [ "$config_dir" = "" ] || [ "$config_file" = "" ]; then
        config_dir=$CONFIG_DIR
        config_file=$CONFIG_FILE
    fi
    if [[ ! -d "$config_dir" ]]; then
        if ! mkdir -p "$config_dir"; then
            std_error_exit "$pkg: failed to make local config directory: $config_dir. Exit" $E_DEPENDENCY
        else
            set_file_permissions $config_dir
        fi
    fi
    if [ ! -f "$config_dir/$config_file" ]; then
        return 1
    else
        if [ "$(stat -c %U $config_file 2>/dev/null)" = "root" ] && [ $CALLER ]; then
            set_file_permissions $config_file
        fi
        return 0
    fi
}

function configure_display(){
    ## displayes local conf file ##
    local config_path="$CONFIG_DIR/$CONFIG_FILE"
    if configuration_file; then
        echo -e "\n  ${BOLD}CONFIG_FILE${UNBOLD}:  ${yellow}$config_path${reset}\n"
        cat $config_path 2>/dev/null | jq .
        echo -e "\n"
    else
        std_message "No local configuration found. Not yet generated" "INFO"
    fi
}

function configure_perl(){
    ## update rkhunter perl module dependencies ##
    local choice
    #
    if [ $QUIET ]; then
        source $pkg_path/core/configure_perl.sh $QUIET
        if configure_perl_main; then
            GENERATE_SYSPROP_DB="true"          # set global to regenerate system properites db
            return 0
        else
            unset GENERATE_SYSPROP_DB
            return 1
        fi
    else
        std_message "RKhunter has a dependency on many Perl modules which may
          or may not be installed on your system." "INFO"
        read -p "    Do you want to install missing perl modules? [y]: " choice

        if [ -z $choice ] || [ "$choice" = "y" ]; then
            # perl update script
            source $pkg_path/core/configure_perl.sh $QUIET
            if configure_perl_main; then
                GENERATE_SYSPROP_DB="true"          # set global to regenerate system properites db
                return 0
            else
                unset GENERATE_SYSPROP_DB
                return 1
            fi
        else
            std_message "User cancel. Exit" "INFO"
            exit 0
        fi
    fi
}


function configure_unhide(){
    ## update rkhunter perl module dependencies ##
    local choice
    local tabs='\t'
    local by=$(echo -e ${bold}${wgray})
    #
    if is_installed "unhide"; then
        std_message "Exit unhide configure - unhide already compiled and installed" "INFO" $LOG_FILE
        return 0
    fi
    # if not installed; compile & install it
    if [ $QUIET ]; then
        source $pkg_path/core/configure_unhide.sh $QUIET
        if configure_unhide_main; then
            std_message "Removing Unhide build artifacts" "INFO" $LOG_FILE
            sleep 2
            clean_up "$TMPDIR/unhide"
            GENERATE_SYSPROP_DB="true"          # set global to regenerate system properites db
            return 0
        else
            unset GENERATE_SYSPROP_DB
            return 1
        fi
    else
        std_message "RKhunter has a dependency on a C library named ${by}unhide${bodytext} which
          is used to discover hidden processes in memeory. This library
          must be compiled and installed on your system.\n
          \n$tabs What is ${by}unhide${reset}? ${url}http://www.unhide-forensics.info/?Linux${bodytext}\n" "INFO"
        read -p "    Do you want to compile and install unhide? [y]: " choice

        if [ -z $choice ] || [ "$choice" = "y" ]; then
            # perl update script
            source $pkg_path/core/configure_unhide.sh $QUIET
            if configure_unhide_main; then
                std_message "Removing Unhide build artifacts" "INFO" $LOG_FILE
                sleep 2
                clean_up "$TMPDIR/unhide"
                GENERATE_SYSPROP_DB="true"          # set global to regenerate system properites db
                return 0
            else
                unset GENERATE_SYSPROP_DB
                return 1
            fi
        else
            std_message "User cancel. Exit" "INFO"
            exit 0
        fi
    fi
}

function configure_skdet(){
    ## configure dependent rootkit c module, skdet ##
    local choice
    #
    if is_installed "skdet"; then
        std_message "Exit skdet configure - skdet already compiled and installed" "INFO" $LOG_FILE
        return 0
    fi
    # not installed previously
    if [ $QUIET ]; then
        source $pkg_path/core/configure_skdet.sh $QUIET
        if configure_skdet_main; then
            std_logger "Removing Skdet build artifacts" "INFO" $LOG_FILE
            sleep 2
            clean_up "$TMPDIR/skdet"
            GENERATE_SYSPROP_DB="true"          # set global to regenerate system properites db
            return 0
        else
            unset GENERATE_SYSPROP_DB
            return 1
        fi
    else
        std_message "RKhunter has a dependency on a C library named ${yellow}Skdet${bodytext}
              which must be compiled and installed on your system." "INFO"
        read -p "    Do you want to install and configure Skdet? [y]: " choice
        if [ -z $choice ] || [ "$choice" = "y" ]; then
            # perl update script
            source $pkg_path/core/configure_skdet.sh $QUIET
            if configure_skdet_main; then
                std_message "Removing Skdet build artifacts" "INFO" $LOG_FILE
                sleep 2
                clean_up "$TMPDIR/skdet"
                GENERATE_SYSPROP_DB="true"          # set global to regenerate system properites db
                return 0
            else
                unset GENERATE_SYSPROP_DB
                return 1
            fi
        else
            std_message "User cancel. Exit" "INFO"
            exit 0
        fi
    fi
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
    if [ ! -d "$log_dir" ]; then
        if ! mkdir -p "$log_dir"; then
            std_error_exit "$pkg: failed to make log directory: $log_dir. Exit" $E_DEPENDENCY
        fi
    fi
    if [ ! -f $log_file ]; then
        if ! touch $log_file 2>/dev/null; then
            std_error_exit "$pkg: failed to seed log file: $log_file. Exit" $E_DEPENDENCY
        fi
    else
        if [ "$(stat -c %U $log_file)" = "root" ] && [ $CALLER ]; then
            chown $CALLER:$CALLER $log_file
        fi
    fi

    ## configuration file path
    configuration_file $CONFIG_DIR $CONFIG_FILE

    ## check for required cli tools ##
    binary_depcheck grep gcc jq perl sha256sum wget

    ## dependent installer modules
    if [ ! -f "$perl_script" ]; then
        std_warn "$perl_script script dependency not found"
    elif [ ! -f "$skdet_script" ]; then
        std_warn "$skdet_script script dependency not found"
    fi
    # success
    std_logger "$pkg: all dependencies satisfied." "INFO" $log_file

    #
    # <<-- end function depcheck -->>
}

function determine_layout(){
    ## post-install discovery of layout parameter ##
    #
    #   See
    #       $ sh installer.sh --examples
    #       $ sh installer.sh --layout xyz --show  (shows binary installation locations)
    #
    local install_dir=$(which rkhunter)
    #
    case $install_dir in
        "/usr/local/bin/rkhunter")
            LAYOUT="default"
            ;;
        "/usr/bin/rkhunter")
            LAYOUT="/usr"
            ;;
        "/bin/rkhunter")
            LAYOUT="/bin"
            ;;
        "/usr/sbin/rkhunter")
            LAYOUT="custom"
            ;;
        *)
            LAYOUT="default" ;;
    esac
}

function download(){
    ## download rkhunter required components
    local file1="$1"
    local file2="$2"
    #
    for file in $file1 $file2; do
        if [ -f $file ]; then
            std_message "Pre-existing ${title}$file${reset} file found -- downloaded successfully" "INFO"
        else
            wget $URL/$file
            if [ -f $file ]; then
                std_message "${title}$file${reset} downloaded successfully" "INFO"
            else
                std_message "${title}$file${reset} download ${red}FAIL${reset}" "WARN"
            fi
        fi
    done
    return 0
}

function install_rkhunter(){
    ## dynamic malware scanner ##
    local layout="$1"
    local result
    #
    result=$(sha256sum -c $checksum | awk '{print $2}')

    if [ "$result" = "OK" ]; then
        gunzip $gzip
        tar -xvf $base'.tar'
        cd $base
        sh installer.sh --layout $layout --install
    else
        std_message "rkhunter integrity check failure" "WARN"
    fi

    # store installer in case of need for uninstaller in future
    configure_uninstaller "installer.sh" $layout "$CONFIG_DIR/$CONFIG_FILE"

    # test installation
    if [ $(which rkhunter 2>/dev/null) ]; then
        std_message "${title}rkhunter installed successfully${reset}" "INFO"
        CLEAN_UP="true"
    fi
}

function propupd_baseline(){
    ## create system file properites database ##
    local database="/var/lib/rkhunter/db/rkhunter.dat"
    local rkh=$(which rkhunter)
    #
    if [ "$GENERATE_SYSPROP_DB" = "true" ]; then
        # check for if system properites db exists
        if [ ! -f $database ]; then
            $SUDO $rkh --propupd
            std_message "Created system properites database ($database)" "INFO" $LOG_FILE
        else
            # regenerate system file properties database
            std_message "Regenerating Rkhunter system file properties db" "INFO" $LOG_FILE
            $SUDO $rkh --propupd
        fi
        SYSPROP_GENERATED_DATE=$(date -d @"$(sudo stat -c %Y $database)")
    else
        return 1
    fi
}

function perl_version(){
    ## disvover installed perl binary version ##
    local perl_bin=$(which perl)
    local version_quotes
    local version
    #
    version_quotes="$($perl_bin -V:version | awk -F '=' '{print $2}' | rev | cut -c 3-10)"
    version=$(echo $version_quotes | rev | cut -c 2-10)
    echo $version
}

function set_file_permissions(){
    ## sets file permissions to calling user's id ##
    local path="$1"
    local mode="$2"
    if ! $mode; then mode=700; fi
    chmod -R $mode $path
    chown -R $CALLER:$CALLER $path
    return 0
}

function configure_uninstaller(){
    ## post-install setup of uninstaller for future use ##
    local uninstall_script="$1"         # rkhunter official installer
    local layout_parameter="$2"         # layout parameter used during install
    local config_path="$3"              # path to config_file
    declare -A config_dict              # key, value dictionary
    #
    if [ -f $config_path ] && [ ! $FORCE ]; then
        std_message "Configuration file ($config_path) exists, use --force to regenerate local config file. Exit" "INFO" $LOG_FILE
        exit 0
    else
        if unpack; then
            # copy installer to configuration directory for future use as uninstaller
            cp $uninstall_script "$CONFIG_DIR/uninstall.sh"
        else
            std_error_exit "Unknown problem during unpacking of rkhunter component download & unpack. Exit" $E_CONFIG
        fi
        # proceed with creating configuration file
        config_dict["rkhunter-install"]=$VERSION
        config_dict["rkhunter"]=$RKVERSION
        config_dict["INSTALL_DATE"]=$NOW
        config_dict["PERL_VERSION"]=$(perl_version)
        config_dict["CONFIG_DIR"]=$CONFIG_DIR
        config_dict["UNINSTALL_SCRIPT_PATH"]="$CONFIG_DIR/$uninstall_script"

        # layout parameter
        config_dict["LAYOUT"]=$layout_parameter

        # system properites entry
        if [ -f $SYSPROP_DATABASE ]; then
            PROPUPD_DATE=$(date -d @"$(sudo stat -c %Y $SYSPROP_DATABASE)")
            config_dict["SYSPROP_DATABASE"]=$SYSPROP_DATABASE
            config_dict["SYSPROP_DATE"]=$PROPUPD_DATE
        fi

        # write configuration file
        array2json config_dict $config_path

        if configuration_file $CONFIG_DIR $CONFIG_FILE; then
            std_message "Uninstaller Configuration ${green}COMPLETE${reset}" "INFO" $LOG_FILE
            return 0
        else
            std_message "Problem configuring uninstaller" "WARN" $LOG_FILE
            return 1
        fi
    fi
}


function unpack(){
    ## unpacks gzip and does integrity check (sha256) ##
    local result
    #
    result=$(sha256sum -c $checksum | awk '{print $2}')
    # integrity check pass; unpack
    if [ "$result" = "OK" ]; then
        gunzip $gzip
        tar -xvf $base'.tar'
        cd $base
        return 0
    else
        std_error_exit "rkhunter integrity check failure. Exit" $E_CONFIG
        return 1
    fi
}

function latest_version(){
    ## check to see if latest version of installed binary ##
    local binary="$1"
    local ver_installed="$(sudo $binary --version 2>/dev/null | head -n1 | awk '{print $3}')"
    #
    if [ "$ver_installed" = "$RKVERSION" ]; then
        std_message "Installed $binary executable (version $ver_installed) is latest version. Exit" "INFO" $LOG_FILE
        return 0
    elif [ "$ver_installed" -gt "$RKVERSION" ]; then
        std_message "Installed $binary executable is higher version ($ver_installed) than supported by this
        \tinstall utility ($RKVERSION). Exit" "INFO" $LOG_FILE
        return 0
    elif [ "$ver_installed" -lt "$RKVERSION" ]; then
        std_message "Installed $binary executable is version $ver_installed. Latest is $RKVERSION" "INFO" $LOG_FILE
        return 1
    elif [ ! "$ver_installed" ]; then
        return 1
    fi
}


# --- main ------------------------------------------------------------


depcheck $LOG_DIR $LOG_FILE
parse_parameters $@

## operations not requiring root privileges ##

if [ "$DOWNLOAD_ONLY" ]; then
    download $gzip $checksum
    exit 0

elif [ $CONFIGURE_DISPLAY ]; then
    configure_display
    exit 0

elif [[ $CONFIGURATION && ! $CONFIGURE_DISPLAY && ! $CONFIGURE_SKDET && ! $CONFIGURE_UNINSTALL ]]; then
    if ! configuration_file; then
        std_message "Config file not found, possible rkhunter installer has not run before.\n
        \tIf it has been executed run:\n
        \t\t$ sudo $pkg --configure uninstall\n
        \tto generate a local configuration file." "INFO"
        exit $E_CONFIG
    else
        std_message "${title}--configure${bodytext}  <value>\n
        \tOption must be used with one of the following values:
        \n\n\t\t    o ${yellow}local${bodytext}: configure local rkhunter-install conf file
        \n\t\t    o ${yellow}unhide${bodytext}: compile and install Unhide C library
        \n\t\t    o ${yellow}perl${bodytext}: configure perl module dependencies
        \n\t\t    o ${yellow}skdet${bodytext}: compile and install Skdet C library
        \n\t\t    o ${yellow}display${bodytext}: display local installer conf file\n" "INFO"
    fi
    exit 0
fi


## operations requiring root ##


if [ $EUID -ne 0 ]; then
    std_message "You must run this installer as root. Exit" "WARN"
    exit 1
fi

if [ "$CONFIGURE_PERL" ]; then
    configure_perl

elif [ $CONFIGURE_UNINSTALL ]; then
    download $gzip $checksum
    determine_layout
    configure_uninstaller "installer.sh" $LAYOUT "$CONFIG_DIR/$CONFIG_FILE"
    clean_up

elif [ $CONFIGURE_SKDET ]; then
    configure_skdet
    propupd_baseline

elif [ $CONFIGURE_UNHIDE ]; then
    configure_unhide
    propupd_baseline

elif [ "$INSTALL" ]; then
    if is_installed "rkhunter" && latest_version "rkhunter"; then
        std_message "Rkhunter installed AND latest version. Checking C library dependencies" "INFO" $LOG_FILE
        unset GENERATE_SYSPROP_DB
        configure_perl
        configure_skdet
        configure_unhide
        propupd_baseline
        configuration_file
        configure_uninstaller "installer.sh" $LAYOUT "$CONFIG_DIR/$CONFIG_FILE"
    else
        unset GENERATE_SYSPROP_DB
        cp -r $pkg_path/core $TMPDIR/
        configure_skdet
        configure_unhide
        download $gzip $checksum
        install_rkhunter $LAYOUT
        configure_perl
        propupd_baseline
        configuration_file
        configure_uninstaller "installer.sh" $LAYOUT "$CONFIG_DIR/$CONFIG_FILE"
    fi

elif [ "$UNINSTALL" ]; then
    remove_rkhunter $LAYOUT
fi

if [ "$CLEAN_UP" ]; then
    clean_up
fi

# <-- end -->
exit 0
