#!/usr/bin/env bash

#
#   EXIT ERROR CODES -- source via script
#       ERROR CODES, version 1.2
#

# error codes
E_OK=0                             # exit code if normal exit conditions
E_DEPENDENCY=1                     # exit code if missing required ec2cdependency
E_NOLOG=2                          # exit code if failure to create log dir, log file
E_BADSHELL=3                       # exit code if incorrect shell detected
E_AUTH=4                           # exit code if authentication failure
E_CONFIG=5                         # exit code if configuration file missing or corrupted
E_USER_CANCEL=7                    # exit code if user cancel
E_BADARG=8                         # exit code if bad input parameter
E_NETWORK_ACCESS=9                 # exit code if no network access from current location
E_EXPIRED_CREDS=10                 # exit code if temporary credentials no longer valid
E_MISC=11                          # exit code if miscellaneous (unspecified) error
