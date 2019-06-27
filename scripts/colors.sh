#!/usr/bin/env bash

#------------------------------------------------------------------------------
#
#   colors.sh module | std colors for bash
#
#------------------------------------------------------------------------------
#   Bright ansi color codes:
#       Bright Black: \u001b[30;1m
#       Bright Red: \u001b[31;1m
#       Bright Green: \u001b[32;1m
#       Bright Yellow: \u001b[33;1m
#       Bright Blue: \u001b[34;1m
#       Bright Magenta: \u001b[35;1m
#       Bright Cyan: \u001b[36;1m
#       Bright White: \u001b[37;1m
#
#       Reset: \u001b[0m
#------------------------------------------------------------------------------

VERSION="1.8"


# Formatting
blue=$(tput setaf 4)
cyan=$(tput setaf 6)
green=$(tput setaf 2)
purple=$(tput setaf 5)
red=$(tput setaf 1)
white=$(tput setaf 7)
yellow=$(tput setaf 3)
orange='\033[38;5;95;38;5;214m'
gray=$(tput setaf 008)
wgray='\033[38;5;95;38;5;250m'                  # white-gray
lgray='\033[38;5;95;38;5;245m'                  # light gray
dgray='\033[38;5;95;38;5;8m'                    # dark gray
reset=$(tput sgr0)

# bright colors
brightblue='\033[38;5;51m'
brightcyan='\033[38;5;36m'
brightgreen='\033[38;5;95;38;5;46m'
bluepurple='\033[38;5;68m'
brightred='\u001b[31;1m'
brightyellow='\033[38;5;11m'
brightyellow2='\033[38;5;95;38;5;226m'
brightyellowgreen='\033[38;5;95;38;5;155m'
brightwhite='\033[38;5;15m'
resetansi='\u001b[0m'
RESET=$(echo -e ${resetansi})

# font format
bold='\u001b[1m'                                # ansi format
underline='\u001b[4m'                           # ansi format
BOLD=`tput bold`
UNBOLD=`tput sgr0`

# Initialize ansi colors
title=$(echo -e ${bold}${white})
url=$(echo -e ${underline}${brightblue})
options=$(echo -e ${white})
commands=$(echo -e ${brightcyan})               # use for ansi escape color codes

# frame codes (use for tables)                  SYNTAX:  color:format (bold, etc)
blue_frame=$(echo -e ${brightblue})
bluebold_frame=$(echo -e ${bold}${brightblue})
green_frame=$(echo -e ${brightgreen})            # use for tables; green border faming
greenbold_frame=$(echo -e ${bold}${brightgreen}) # use for tables; green bold border faming
orange_frame=$(echo -e ${orange})                # use for tables; orange border faming
orangebold_frame=$(echo -e ${bold}${orange})     # use for tables; orange bold border faming
white_frame=$(echo -e ${brightwhite})            # use for tables; white border faming
whitebold_frame=$(echo -e ${bold}${brightwhite}) # use for tables; white bold border faming

bodytext=$(echo -e ${reset}${wgray})             # main body text; set to reset for native xterm
bg=$(echo -e ${brightgreen})                     # brightgreen foreground cmd
bgb=$(echo -e ${bold}${brightgreen})             # bold brightgreen foreground cmd

# initialize default color scheme
accent=$(tput setaf 008)                         # ansi format
ansi_orange=$(echo -e ${orange})                 # use for ansi escape color codes


# --- declarations  ------------------------------------------------------------


# indent, x spaces
function indent02() { sed 's/^/  /'; }
function indent04() { sed 's/^/    /'; }
function indent10() { sed 's/^/          /'; }
function indent15() { sed 's/^/               /'; }
function indent18() { sed 's/^/                  /'; }
function indent20() { sed 's/^/                    /'; }
function indent25() { sed 's/^/                         /'; }
