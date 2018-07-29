#!/usr/bin/env bash

#------------------------------------------------------------------------------
#
#   Note:  to be used with dependent modules
#
#       - colors.sh
#       - exitcodes.sh
#
#       Dependencies must be sourced from the same calling script
#       as this std_functions.sh
#
#   Global Variables provided by the Caller:
#       - LOG_FILE      # std_logger writes to this file
#       - QUIET         # Value = "true" to supress stdout from these reference functions
#
#------------------------------------------------------------------------------

 # pkg reported in logs will be the basename of the caller
pkg=$(basename $0 2>/dev/null)
pkg_root="$(echo $pkg | awk -F '.' '{print $1}')"       # pkg without file extention
pkg_path=$(cd $(dirname $0 2>/dev/null); pwd -P)
host=$(hostname)
system=$(uname)

# this file
VERSION="2.5.1"

if [ ! $pkg ] || [ ! $pkg_path ]; then
    echo -e "\npkg and pkg_path errors - both are null"
    exit
fi

function array2json(){
    ## converts associative array to single-level (no nested keys) json file output ##
    #
    #   Caller syntax:
    #       $ array2json config_dict $config_path/configuration_file
    #
    #   where:
    #       $ declare -A config_dict        # config_dict is assoc array, declared in main script
    #
    local -n array_dict=$1      # local assoc array must use -n opt
    local output_file=$2        # location
    local ct                    # counter
    local max_keys              # num keys in array
    #
    echo -e "{" > $output_file
    ct=1
    max_keys=${#array_dict[@]}
    for key in ${!array_dict[@]}; do
        if [ $ct == $max_keys ]; then
            # last key, no comma
            echo "\"${key}\": \"${array_dict[${key}]}\"" | indent04 >> $output_file
        else
            echo "\"${key}\": \"${array_dict[${key}]}\"," | indent04 >> $output_file
        fi
        ct=$(( $ct + 1 ))
    done
    echo -e "}" >> $output_file
    #
    # <-- end function array2json -->
}

function authenticated(){
    ## validates authentication using iam user or role ##
    local profilename="$1"
    local response
    #
    response=$(aws sts get-caller-identity --profile $profilename 2>&1)
    if [ "$(echo $response | grep Invalid)" ]; then
        std_message "The IAM profile provided ($profilename) failed to authenticate to AWS. Exit (Code $E_AUTH)" "AUTH"
        return 1
    elif [ "$(echo $response | grep found)" ]; then
        std_message "The IAM user or role ($profilename) cannot be found in your local awscli config. Exit (Code $E_BADARG)" "AUTH"
        return 1
    elif [ "$(echo $response | grep Expired)" ]; then
        std_message "The sts temporary credentials for the role provided ($profilename) have expired. Exit (Code $E_AUTH)" "INFO"
        return 1
    else
        return 0
    fi
}


function convert_time(){
    # time format conversion (http://stackoverflow.com/users/1030675/choroba)
    num=$1
    min=0
    hour=0
    day=0
    if((num>59));then
        ((sec=num%60))
        ((num=num/60))
        if((num>59));then
            ((min=num%60))
            ((num=num/60))
            if((num>23));then
                ((hour=num%24))
                ((day=num/24))
            else
                ((hour=num))
            fi
        else
            ((min=num))
        fi
    else
        ((sec=num))
    fi
    echo "$day"d,"$hour"h,"$min"m
    #
    # <-- end function convert_time -->
    #
}

function convert_time_months(){
    # time format conversion (http://stackoverflow.com/users/1030675/choroba)
    num=$1
    min=0
    hour=0
    day=0
    mo=0
    if((num>59));then
        ((sec=num%60))
        ((num=num/60))
        if((num>59));then
            ((min=num%60))
            ((num=num/60))
            if((num>23));then
                ((hour=num%24))
                ((day=num/24))
                ((num=num/24))
                if((num>30)); then
                  ((day=num%31))
                  ((mo=num/30))
              else
                  ((day=num))
              fi
            else
                ((hour=num))
            fi
        else
            ((min=num))
        fi
    else
        ((sec=num))
    fi
    if (( $mo > 0 )); then
        echo "$mo"m,"$day"d
    else
        echo "$day"d,"$hour"h,"$min"m
    fi
    #
    # <-- end function convert_time -->
    #
}


function delay_spinner(){
    # vars
    local PROGRESSTXT
    if [ ! "$1" ]; then
        PROGRESSTXT="  Please wait..."
    else
        PROGRESSTXT="$1"
    fi
    # visual progress marker function
    # http://stackoverflow.com/users/2869509/wizurd
    # vars
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    echo -e "\n\n"
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "\r$PROGRESSTXT[%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    #
    # <-- end function ec2cli_spinner -->
    #
}


function environment_info(){
    local prefix=$1
    local dep=$2
    local log_file="$3"
    local version_info
    local awscli_ver
    local boto_ver
    local python_ver
    #
    version_info=$(aws --version 2>&1)
    awscli_ver=$(echo $version_info | awk '{print $1}')
    boto_ver=$(echo $version_info | awk '{print $4}')
    python_ver=$(echo $version_info | awk '{print $2}')
    #
    if [[ $dep == "aws" ]]; then
        std_logger "awscli version detected: $awscli_ver" $prefix $log_file
        std_logger "Python runtime detected: $python_ver" $prefix $log_file
        std_logger "Kernel detected: $(echo $version_info | awk '{print $3}')" $prefix $log_file
        std_logger "boto library detected: $boto_ver" $prefix $log_file

    elif [[ $dep == "awscli" ]]; then
        std_message "awscli version detected: ${accent}${BOLD}$awscli_ver${UNBOLD}${reset}" $prefix $log_file | indent04
        std_message "boto library detected: ${accent}${BOLD}$boto_ver${UNBOLD}${reset}" $prefix $log_file | indent04
        std_message "Python runtime detected: ${accent}${BOLD}$python_ver${UNBOLD}${reset}" $prefix $log_file | indent04

    elif [[ $dep == "os" ]]; then
        std_message "Kernel detected: ${title}$(echo $version_info | awk '{print $3}')${reset}" $prefix $log_file | indent04

    elif [[ $dep == "jq" ]]; then
        version_info=$(jq --version 2>&1)
        std_message "JSON parser detected: ${title}$(echo $version_info)${reset}" $prefix $log_file | indent04

    else
        std_logger "Detected: $($prog --version | head -1)" $prefix $log_file
    fi
    #
    #<-- end function environment_info -->
}


function is_installed(){
    ## validate if binary previously installed  ##
    local binary="$1"
    local location=$(which $binary 2>/dev/null)
    if [ $location ]; then
        std_message "$binary is installed:  $location" "INFO" $LOG_FILE
        return 0
    else
        return 1
    fi
}


function linux_distro(){
    ## determine linux os distribution ##
    local os_major
    local os_minor

    ## AMAZON Linux ##
    if [ "$(grep -i amazon /etc/os-release  | head -n 1)" ]; then
        os_major="amazonlinux"
        if [ "$(grep VERSION_ID /etc/os-release | awk -F '=' '{print $2}')" = '"2"' ]; then
            os_minor="$(grep VERSION /etc/os-release | grep -v VERSION_ID | awk -F '=' '{print $2}')"
            os_minor=$(echo $os_minor | cut -c 2-15 | rev | cut -c 2-15 | rev)
        elif [ "$(grep VERSION_ID /etc/os-release | awk -F '=' '{print $2}')" = '"1"' ]; then
            os_minor="$(grep VERSION /etc/os-release | grep -v VERSION_ID | awk -F '=' '{print $2}')"
            os_minor=$(echo $os_minor | cut -c 2-15 | rev | cut -c 2-15 | rev)
        else os_minor="unknown"; fi

    ## REDHAT Linux ##
    elif [ $(grep -i redhat /etc/os-release  | head -n 1) ]; then
        os_major="redhat"
        os_minor="future"

    ## UBUNTU, ubuntu variants ##
    elif [ "$(grep -i ubuntu /etc/os-release)" ]; then
        os_major="ubuntu"
        if [ "$(grep -i mint /etc/os-release | head -n1)" ]; then
            os_minor="linuxmint"
        elif [ "$(grep -i ubuntu_codename /etc/os-release | awk -F '=' '{print $2}')" ]; then
            os_minor="$(grep -i ubuntu_codename /etc/os-release | awk -F '=' '{print $2}')"
        else
            os_minor="unknown"; fi

    ## distribution not determined ##
    else
        os_major="unknown"; os_minor="unknown"
    fi
    # set distribution type in environment
    export OS_DISTRO="$os_major"
    std_logger "Operating system identified as Major Version: $os_major, Minor Version: $os_minor" "INFO" $LOG_FILE
    # return major, minor disto versions
    echo "$os_major $os_minor"
}


function print_header(){
    ## print formatted report header ##
    local title="$1"
    local width="$2"
    local reportfile="$3"
    #
    #if (( $(tput cols) > 480 )); then
    #    printf "%-10s %*s\n" $(echo -e ${frame}) "$(($width - 1))" '' | tr ' ' _ | indent02 > $reportfile
    #else
        printf "%-10s %*s" $(echo -e ${frame}) "$(($width - 1))" '' | tr ' ' _ | indent02 > $reportfile
    #fi
    echo -e "${bodytext}" >> $reportfile
    echo -ne ${title} >> $reportfile
    echo -e "${frame}" >> $reportfile
    printf '%*s' "$width" '' | tr ' ' _  | indent02 >> $reportfile
    echo -e "${bodytext}" >> $reportfile
}

function print_footer(){
    ## print formatted report footer ##
    local footer="$1"
    local width="$2"
    #
    printf "%-10s %*s\n" $(echo -e ${frame}) "$(($width - 1))" '' | tr ' ' _ | indent02
    echo -e "${bodytext}"
    echo -ne $footer | indent20
    echo -e "${frame}"
    printf '%*s\n' "$width" '' | tr ' ' _ | indent02
    echo -e "${bodytext}"
}

function print_separator(){
    ## prints single bar separator of width ##
    local width="$1"
    echo -e "${frame}"
    printf "%-10s %*s" $(echo -e ${frame}) "$(($width - 1))" '' | tr ' ' _ | indent02
    echo -e "${bodytext}\n"

}


function std_logger(){
    local msg="$1"
    local prefix="$2"
    local log_file="$3"
    #
    if [ ! $prefix ]; then
        prefix="INFO"
    fi
    if [ ! -f $log_file ]; then
        # create log file
        touch $log_file
        if [ ! -f $log_file ]; then
            echo "[$prefix]: $pkg ($VERSION): failure to call std_logger, $log_file location not writeable"
            exit $E_DIR
        fi
    else
        echo "$(date +'%Y-%m-%d %T') $host - $pkg - $VERSION - [$prefix]: $msg" >> "$log_file"
    fi
}

function std_message(){
    #
    # Caller formats:
    #
    #   Logging to File | std_message "xyz message" "INFO" "/pathto/log_file"
    #
    #   No Logging  | std_message "xyz message" "INFO"
    #
    local msg="$1"
    local prefix="$2"
    local log_file="$3"
    local format="$4"
    #
    if [ $log_file ]; then
        std_logger "$msg" "$prefix" "$log_file"
    fi
    [[ $QUIET ]] && return
    shift
    pref="----"
    if [[ $1 ]]; then
        pref="${1:0:5}"
        shift
    fi
    if [ $format ]; then
        echo -e "${yellow}[ $cyan$pref$yellow ]$reset  $msg" | indent04
    else
        echo -e "\n${yellow}[ $cyan$pref$yellow ]$reset  $msg\n" | indent04
    fi
}

function std_error(){
    local msg="$1"
    std_logger "$msg" "ERROR" $LOG_FILE
    echo -e "\n${yellow}[ ${red}ERROR${yellow} ]$reset  $msg\n" | indent04
}

function std_warn(){
    local msg="$1"
    std_logger "$msg" "WARN" $LOG_FILE
    if [ "$3" ]; then
        # there is a second line of the msg, to be printed by the caller
        echo -e "\n${yellow}[ ${red}WARN${yellow} ]$reset  $msg" | indent04
    else
        # msg is only 1 line sent by the caller
        echo -e "\n${yellow}[ ${red}WARN${yellow} ]$reset  $msg\n" | indent04
    fi
}

function std_error_exit(){
    local msg="$1"
    local status="$2"
    std_error "$msg"
    exit $status
}
