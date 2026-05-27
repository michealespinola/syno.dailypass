#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034
# SC2004,SC2154,SC2181
# bash /volume1/homes/admin/scripts/bash/syno.dailypass.sh

set -u
SCRIPT_VERSION=1.3.0

get_source_info() {                                                                               # FUNCTION TO GET SOURCE SCRIPT INFORMATION
  srcScrpVer=${SCRIPT_VERSION}                                                                    # Source script version
  srcFullPth=$(readlink -f "${BASH_SOURCE[0]}")                                                   # Source script absolute path of script
  srcDirctry=$(dirname "$srcFullPth")                                                             # Source script directory containing script
  srcFileNam=${srcFullPth##*/}                                                                    # Source script script file name
}
get_source_info

printf "\n%s\n\n" "SYNO DAILY TELNET PASSWORD SCRIPT v$srcScrpVer"                                # Print our glorious header because we are full of ourselves

gcd() {                                                                                           # FUNCTION TO GET ITERATIVE EUCLIDEAN ALGORITHM (GREATEST COMMON DIVISOR)
  local a=$1 b=$2 t
  while ((b)); do
    t=$((a % b))
    a=$b
    b=$t
  done
  gcdResult=$a
}

format_password_for_mm_dd() {                                                                     # Inputs: month day (decimal integers)
  local month=$1 day=$2 label

  printf -v label 'Password %02d/%02d:' "$month" "$day"
  gcd "$month" "$day"

  printf -v passwordLine '%16s %x%02d-%02x%02d\n' \
    "$label" \
    "$month" "$month" "$day" "$gcdResult"
}

print_password_for_mm_dd() {                                                                      # Inputs: month day (decimal integers)
  format_password_for_mm_dd "$1" "$2"
  printf '%s' "$passwordLine"
}

is_gnu_date() {
  date -d '1970-01-01' +%s >/dev/null 2>&1
}

date_to_epoch() {                                                                                 # Input: YYYY-MM-DD
  local iso=$1
  if is_gnu_date; then
    date -d "$iso" +%s
  else
    date -j -f '%Y-%m-%d' "$iso" +%s
  fi
}

is_leap_year() { # $1 = YYYY
  local y=$1
  (( (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0) ))
}

days_in_year() { # $1 = YYYY
  local y=$1
  if is_leap_year "$y"; then
    printf '366\n'
  else
    printf '365\n'
  fi
}

mm_dd_from_base_plus_offset() {                                                                   # Inputs: base YYYY-MM-DD, offset days
  local base_iso=$1 offset=$2
  if is_gnu_date; then
    date -d "${base_iso} +${offset} days" '+%m %d'
  else
    date -j -f '%Y-%m-%d' "$base_iso" -v +"${offset}"d '+%m %d'
  fi
}

print_passwords_for_year() {                                                                      # Input: YYYY
  local year=$1 month day maxDay
  local output=""
  local -a monthDays=(0 31 28 31 30 31 30 31 31 30 31 30 31)

  if is_leap_year "$year"; then
    monthDays[2]=29
  fi

  for ((month = 1; month <= 12; month++)); do
    maxDay=${monthDays[month]}

    for ((day = 1; day <= maxDay; day++)); do
      format_password_for_mm_dd "$month" "$day"
      output+=$passwordLine
    done
  done

  printf '%s' "$output"
}

resolve_start_iso_from_mmdd() {                                                                   # Input: MM/DD
  local mmdd=$1
  if [[ ! $mmdd =~ ^[0-1][0-9]/[0-3][0-9]$ ]]; then                                               # Basic format check
    return 1
  fi

  local mm dd yyyy candi_date candi_epoc todays_epoc
  mm=${mmdd%/*}
  dd=${mmdd#*/}
  yyyy=$(date +%Y)
  candi_date="${yyyy}-${mm}-${dd}"
  candi_epoc=$(date_to_epoch "$candi_date" 2>/dev/null || true)                                    # Validate candidate date parses
  [[ -n "$candi_epoc" ]] || return 1

  todays_epoc=$(date_to_epoch "$(date +%Y-%m-%d)" 2>/dev/null || true)
  [[ -n "$todays_epoc" ]] || return 1

  if (( candi_epoc < todays_epoc )); then                                                         # If date already passed, roll to next year
    yyyy=$((yyyy + 1))
    candi_date="${yyyy}-${mm}-${dd}"
    candi_epoc=$(date_to_epoch "$candi_date" 2>/dev/null || true)
    [[ -n "$candi_epoc" ]] || return 1
  fi

  printf '%s' "$candi_date"
}                                                                                                 # Output: YYYY-MM-DD (next occurrence in current year, otherwise next year)

get_term_cols() {                                                                                 # FUNCTION TO GET TERMINAL COLUMN WIDTH
  local cols
  cols=$(stty size 2>/dev/null | awk '{print $2}')                                                # 1) stty (works when stdout is a tty)
  if [[ $cols =~ ^[0-9]+$ ]] && (( cols > 0 )); then
    printf '%s\n' "$cols"
    return
  fi
  if [[ ${COLUMNS:-} =~ ^[0-9]+$ ]] && (( COLUMNS > 0 )); then                                    # 2) COLUMNS env var (sometimes set by shells)
    printf '%s\n' "$COLUMNS"
    return
  fi
  printf '80\n'                                                                                   # 3) Standard fallback
}

print_help_wrap() { # <resume_col> <right_margin> <left_text> <right_text> [fd]                   # FUNCTION TO PRINT WRAPPED LINE
  local resume_col=$1
  local right_margin=$2
  local output_fd=${5:-2}
  local cols wrap wrapped text_col

  cols=$(get_term_cols)
  text_col=$((resume_col + 1))
  wrap=$((cols - right_margin - text_col))
  ((wrap < 20)) && wrap=20                                                                        # Sanity floor

  wrapped=$(printf '%s\n' "$4" | fold -s -w "$wrap")

  printf '%-'"$resume_col"'s %s\n' \
    "$3" \
    "$(printf '%s\n' "$wrapped" | sed -n '1p')" >&"$output_fd"                                      # First line: left column + first wrapped line

  printf '%s\n' "$wrapped" |                                                                      # Continuation lines:
    sed -n '2,$p' |                                                                               # Right margin wrap
    awk -v col="$text_col" '{ printf "%*s%s\n", col, "", $0 }' >&"$output_fd"                         # Indent to resume column
}

print_username_hint() {
  local target=${1:-'<IPADDRESS>'}
  local label

  printf -v label '%16s' 'Initiate:'
  print_help_wrap 16 2 "$label" "http://${target}:5000/webman/start_telnet.cgi" 1

  printf -v label '%16s' 'Access:'
  print_help_wrap 16 2 "$label" "telnet ${target} 23" 1

  printf '%16s %s\n' 'Username:' 'root'
  printf '\n%16s\n' 'Recovery Mode'
}

print_reset_hint() {
  local month=1 day=1

  gcd "$month" "$day"
  printf '%16s %x%02d-%02x%02d (Pre-Configure Mode)\n\n' \
    ' ' "$month" "$month" "$day" "$gcdResult"
}

is_ipv4_address() {                                                                               # Input: IPv4 address
  local ip=$1 octet
  local -a octets

  [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1

  IFS='.' read -r -a octets <<<"$ip"
  for octet in "${octets[@]}"; do
    (( 10#$octet <= 255 )) || return 1
  done
}

print_day_information() {                                                                         # Inputs: optional MM/DD, optional target IP
  local requested_day=${1:-} target_ip=${2:-}
  local start_iso mm dd month day

  if [[ -n $requested_day ]]; then
    start_iso=$(resolve_start_iso_from_mmdd "$requested_day") || {
      printf 'Error: invalid date "%s"\n' "$requested_day" >&2
      return 1
    }
  else
    start_iso=$(date +%Y-%m-%d)
  fi

  IFS='-' read -r _ mm dd <<<"$start_iso"
  month=$((10#$mm))
  day=$((10#$dd))
  print_username_hint "$target_ip"
  print_password_for_mm_dd "$month" "$day"
  print_reset_hint
}

connect_to_nas_telnet() {                                                                         # Input: IPv4 address
  local ip=$1 initiate_url response curlStatus label

  command -v curl >/dev/null 2>&1 || {
    printf 'Error: curl is required to initiate the telnet daemon.\n' >&2
    return 1
  }

  command -v telnet >/dev/null 2>&1 || {
    printf 'Error: telnet is required to connect to the NAS.\n' >&2
    return 1
  }

  initiate_url="http://${ip}:5000/webman/start_telnet.cgi"
  printf -v label '%16s' 'Initiating:'
  print_help_wrap 16 2 "$label" "$initiate_url" 1

  response=$(curl -fsS --connect-timeout 5 --max-time 10 "$initiate_url" 2>&1)
  curlStatus=$?

  if [[ -z $response ]] && (( curlStatus != 0 )); then
    printf -v response 'curl exited with status %d' "$curlStatus"
  fi

  printf -v label '%16s' 'Response:'
  print_help_wrap 16 2 "$label" "$response" 1

  printf -v label '%16s' 'Connecting:'
  print_help_wrap 16 2 "$label" "telnet ${ip} 23" 1
  printf '\n'

  telnet "$ip" 23
}

usage() {
  printf 'Usage: %s [-d [MM/DD] | -y [YYYY] | -c <IPADDRESS>] [-h]\n\n' "$srcFileNam" >&2
  printf '  Options:\n\n' >&2
  print_help_wrap 24 2 "    -d, --day [MM/DD]"     "Print the password for today or next MM/DD"
  print_help_wrap 24 2 "    -y, --year [YYYY]"     "Print all passwords for the year or a specific YYYY"
  print_help_wrap 24 2 "    -c, --connect <IP>"    "Print today's password, initiate telnet on the target NAS, and connect to it"
  print_help_wrap 24 2 "    -h, --help"            "Print this help text and exit"
  printf '\n' >&2
  exit 2
}

mode=""        # "day", "year", or "connect"
day_arg=""     # optional MM/DD
year_arg=""    # optional YYYY
connect_ip=""  # required IPv4 address for -c/--connect

while (($#)); do
  case "$1" in
    -d|--day)
      [[ -z "$mode" || "$mode" == "day" ]] || {
        printf 'Error: Options -d/--day, -y/--year, and -c/--connect are mutually exclusive.\n\n' >&2
        exit 1
      }
      mode="day"
      shift
      if (($#)) && [[ $1 =~ ^[0-1][0-9]/[0-3][0-9]$ ]]; then
        day_arg=$1
        shift
      fi
      ;;

    -y|--year)
      [[ -z "$mode" || "$mode" == "year" ]] || {
        printf 'Error: Options -d/--day, -y/--year, and -c/--connect are mutually exclusive.\n\n' >&2
        exit 1
      }
      mode="year"
      shift
      if (($#)) && [[ $1 =~ ^[0-9]{4}$ ]]; then
        year_arg=$1
        shift
      else
        year_arg=$(date +%Y)
      fi
      ;;

    -c|--connect)
      [[ -z "$mode" || "$mode" == "connect" ]] || {
        printf 'Error: Options -d/--day, -y/--year, and -c/--connect are mutually exclusive.\n\n' >&2
        exit 1
      }
      mode="connect"
      shift
      if (($#)) && is_ipv4_address "$1"; then
        connect_ip=$1
        shift
      else
        printf 'Error: -c/--connect requires a valid IPv4 address.\n\n' >&2
        exit 1
      fi
      ;;

    -h|--help)
      usage
      ;;

    *)
      usage
      ;;
  esac
done

if [[ -z "$mode" ]]; then
  usage
fi

if [[ $mode == "day" ]]; then
  print_day_information "$day_arg" || exit 1
  exit 0
fi

if [[ $mode == "connect" ]]; then
  print_day_information "" "$connect_ip" || exit 1
  connect_to_nas_telnet "$connect_ip"
  exit $?
fi

if [[ $mode == "year" ]]; then
  print_username_hint
  print_passwords_for_year "$year_arg"
  print_reset_hint
  exit 0
fi
