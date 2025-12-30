#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034
# SC2004,SC2154,SC2181
# bash /volume1/homes/admin/scripts/bash/syno.dailypass.sh

set -u
SCRIPT_VERSION=1.1.0

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
  while (( b )); do
    t=$(( a % b ))
    a=$b
    b=$t
  done
  printf '%d' "$a"
}

print_password_for_mm_dd() {                                                                      # Inputs: month day (decimal integers)
  local month=$1 day=$2
  printf '%16s %x%02d-%02x%02d\n' \
    "$(printf '%02d/%02d password:' "$month" "$day")" \
    "$month" "$month" "$day" "$(gcd "$month" "$day")"
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

resolve_start_iso_from_mmdd() {                                                                   # Input: MM/DD
  local mmdd=$1
  if [[ ! $mmdd =~ ^[0-1][0-9]/[0-3][0-9]$ ]]; then                                               # Basic format check
    return 1
  fi

  local mm dd yyyy candi_date cand_epoch today_epoch
  mm=${mmdd%/*}
  dd=${mmdd#*/}
  yyyy=$(date +%Y)
  candi_date="${yyyy}-${mm}-${dd}"
  cand_epoch=$(date_to_epoch "$candi_date" 2>/dev/null || true)                                    # Validate candidate date parses
  [[ -n "$cand_epoch" ]] || return 1

  today_epoch=$(date_to_epoch "$(date +%Y-%m-%d)" 2>/dev/null || true)
  [[ -n "$today_epoch" ]] || return 1

  if (( cand_epoch < today_epoch )); then                                                         # If date already passed, roll to next year
    yyyy=$((yyyy + 1))
    candi_date="${yyyy}-${mm}-${dd}"
    cand_epoch=$(date_to_epoch "$candi_date" 2>/dev/null || true)
    [[ -n "$cand_epoch" ]] || return 1
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

print_help_wrap() { # <resume_col> <right_margin> <left_text> <right_text>                        # FUNCTION TO PRINT WRAPPED HELP LINE
  local resume_col=$1
  local right_margin=$2
  local cols wrap wrapped
  cols=$(get_term_cols)
  wrap=$(( cols - right_margin - resume_col ))
  (( wrap < 20 )) && wrap=20                                                                      # Sanity floor
  wrapped=$(printf '%s\n' "$4" | fold -s -w "$wrap")
  printf '    %-32s %s\n' "$3" "$(printf '%s\n' "$wrapped" | sed -n '1p')" >&2                    # First line: left column + first wrapped line
  printf '%s\n' "$wrapped" |                                                                      # Continuation lines:
    sed -n '2,$p' |                                                                               # Right margin wrap
    awk -v col="$resume_col" '{ printf "%*s%s\n", col, "", $0 }' >&2                              # Indent to resume column
}

print_username_hint() {
  printf '%16s %s\n' 'access:' 'telnet port 23'
  printf '%16s %s\n' 'username:' 'root or admin'
}
print_reset_hint() {
  printf '%16s %x%02d-%02x%02d (if date reset)\n\n' \
    "$(printf ' ')" "01" "01" "01" "$(gcd "01" "01")"
}

usage() {
  printf 'Usage: %s [-d [MM/DD | -y [YYYY]] [-h]\n\n' "$srcFileNam" >&2
  printf '  Options:\n\n' >&2
  print_help_wrap 37 2 "-d, --day MM/DD"  "Print the password for today or the next occurrence of MM/DD"
  print_help_wrap 37 2 "-y, --year YYYY"  "Print all passwords for the year or a specific YYYY"
  print_help_wrap 37 2 "-h, --help"       "Print this help text and exit"
  printf '\n' >&2
  exit 2
}

mode=""        # "day" or "year"
day_arg=""     # optional MM/DD
year_arg=""    # optional YYYY

while (($#)); do
  case "$1" in
    -d|--day)
      [[ -z "$mode" || "$mode" == "day" ]] || {
        printf 'Error: Options -d/--day and -y/--year are mutually exclusive.\n\n' >&2
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
        printf 'Error: Options -d/--day and -y/--year are mutually exclusive.\n\n' >&2
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
  if [[ -n "$day_arg" ]]; then
    start_iso=$(resolve_start_iso_from_mmdd "$day_arg") || {
      printf 'Error: invalid date "%s"\n' "$day_arg" >&2
      exit 1
    }
  else
    start_iso=$(date +%Y-%m-%d)
  fi

  IFS='-' read -r _ mm dd <<<"$start_iso"
  month=$((10#$mm))
  day=$((10#$dd))
  print_username_hint
  print_password_for_mm_dd "$month" "$day"
  print_reset_hint
  exit 0
fi

if [[ $mode == "year" ]]; then
  start_iso="${year_arg}-01-01"
  limit=$(days_in_year "$year_arg")

print_username_hint

  for ((i=0; i<limit; i++)); do
    mm_dd=$(mm_dd_from_base_plus_offset "$start_iso" "$i") || {
      printf 'Error: unsupported "date" implementation on this system.\n' >&2
      exit 1
    }
    IFS=' ' read -r mm dd <<<"$mm_dd"
    print_password_for_mm_dd $((10#$mm)) $((10#$dd))
  done

  print_reset_hint
  exit 0
fi
