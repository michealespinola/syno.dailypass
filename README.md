# syno.dailypass.sh

A bash script that deterministically computes and prints the Synology daily telnet recovery password for a given date or year. It supports generating the password for a single day or for every day in a full calendar year, using only the calendar date and a fixed algorithm. The script is fully self-contained and performs no access or system modifications.

### Purpose

This script exists to reproduce the Synology daily recovery password locally and on demand, without relying on external services or support channels via Synology. It is intended for legitimate administrative and recovery scenarios where you already have authorized access to the system and need to compute the daily password for a known date.

* It's only purpose and use is while attempting to access the DSM in a pre-configuration or recovery mode.

### Requirements

- Standard linux utilities: `date`, `printf`, `awk`, `sed`, `fold`, `stty`
- Should work on any linux-type systems

### Usage

```
Usage: syno.dailypass.sh [-d [MM/DD | -y [YYYY]] [-h]

  Options:

    -d, --day MM/DD                  Print the password for today or the next
                                     occurrence of MM/DD
    -y, --year YYYY                  Print all passwords for the year or a
                                     specific year
    -h, --help                       Print this help text and exit
```

### Utilization and example output

```
# bash syno.dailypass.sh -d

SYNO DAILY TELNET PASSWORD SCRIPT v1.0.0

         access: telnet port 23
       username: root or admin
 12/29 password: c12-1d01
                 101-0101 (if date reset)

```
or...
```
# bash syno.dailypass.sh -y

SYNO DAILY TELNET PASSWORD SCRIPT v1.0.0

         access: telnet port 23
       username: root or admin
 01/01 password: 101-0101
 01/02 password: 101-0201
 01/03 password: 101-0301
 01/04 password: 101-0401
 01/05 password: 101-0501
 01/06 password: 101-0601
 01/07 password: 101-0701
 01/08 password: 101-0801
 01/09 password: 101-0901
 01/10 password: 101-0a01
 01/11 password: 101-0b01
[...]
 12/21 password: c12-1503
 12/22 password: c12-1602
 12/23 password: c12-1701
 12/24 password: c12-1812
 12/25 password: c12-1901
 12/26 password: c12-1a02
 12/27 password: c12-1b03
 12/28 password: c12-1c04
 12/29 password: c12-1d01
 12/30 password: c12-1e06
 12/31 password: c12-1f01
                 101-0101 (if date reset)
```
