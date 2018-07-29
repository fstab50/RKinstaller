# unhide
* * *

## Rkhunter Dependency

`unhide` is a C library must be compiled and installed locally to allow rkhunter to find hidden processes.

You can find out more from the official [Rkhunter unhide page](https://sourceforge.net/p/rkhunter/wiki/unhide)

* * *

## Instructions

This script must be executed by running one of the following two `rkhunter-install.sh` installation modes:

#### 1. Full Install

```bash

$ sudo sh rkhunter-install.sh --install

```

#### 2. `unhide` Module Configuration

Alternatively, if you have rkhunter installed and just want to compile and install the `unhide` binary:

```bash

$ sudo sh rkhunter-install.sh --configure unhide

```
* * *

## Root Permissions

Elevated permissions are required for all installation modes.

* * *
