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
Usage: syno.dailypass.sh [-d [MM/DD] | -y [YYYY] | -c <IPADDRESS>] [-h]

  Options:

    -d, --day [MM/DD]    Print the password for today or next MM/DD
    -y, --year [YYYY]    Print all passwords for the year or a specific YYYY
    -c, --connect <IP>   Print today's password, initiate telnet on the target
                         NAS, and connect to it
    -h, --help           Print this help text and exit
```

### Utilization and example output

#### Password of the day

```
# bash syno.dailypass.sh -d

SYNO DAILY TELNET PASSWORD SCRIPT v1.3.0

       Initiate: http://<IPADDRESS>:5000/webman/start_telnet.cgi
         Access: telnet <IPADDRESS> 23
       Username: root

   Recovery Mode
 Password 05/27: 505-1b01
                 101-0101 (Pre-Configure Mode)
```

or...

#### Passwords for the year

```

# bash syno.dailypass.sh -y

SYNO DAILY TELNET PASSWORD SCRIPT v1.3.0

       Initiate: http://<IPADDRESS>:5000/webman/start_telnet.cgi
         Access: telnet <IPADDRESS> 23
       Username: root

   Recovery Mode
 Password 01/01: 101-0101
 Password 01/02: 101-0201
 Password 01/03: 101-0301
 Password 01/04: 101-0401
 Password 01/05: 101-0501
 Password 01/06: 101-0601
 Password 01/07: 101-0701
 Password 01/08: 101-0801
 Password 01/09: 101-0901
 Password 01/10: 101-0a01
 Password 01/11: 101-0b01
[...]
 Password 12/21: c12-1503
 Password 12/22: c12-1602
 Password 12/23: c12-1701
 Password 12/24: c12-1812
 Password 12/25: c12-1901
 Password 12/26: c12-1a02
 Password 12/27: c12-1b03
 Password 12/28: c12-1c04
 Password 12/29: c12-1d01
 Password 12/30: c12-1e06
 Password 12/31: c12-1f01
                 101-0101 (Pre-Configure Mode)
```

### Observation: This script is overkill

Absolutely. This script is indeed overkill. Along with its very simplistic core feature of generating a code, I further developed this script as a testing and discovery platform for various coding and terminal issues that I was encountering in other scripts.
