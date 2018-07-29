# skdet
* * *

## Rkhunter Dependency

Skdet must be configured to allow checks for following rootkits:

* SucKIT
* Adore
* Adore-NG
* UNFshit
* UNFkmem
* frontkey

You can find out more from the official [Rkhunter skdet page](https://sourceforge.net/p/rkhunter/wiki/skdet)

* * *
## Instructions

This script must be executed by running one of the following two `rkhunter-install.sh` installation modes:

#### 1. Full Install

```bash

$ sudo sh rkhunter-install.sh --install

```

#### 2. `skdet` Module Configuration

Alternatively, if you have rkhunter installed and just want to compile and install the `skdet` binary:

```bash

$ sudo sh rkhunter-install.sh --configure unhide

```

* * *

## Root Permissions

Elevated permissions are required for all installation modes.

* * *
