# ---
# name: debounce
# summary: Return a cached result if calling the same command again.
# dateModified: 2025-09-23T17:37:13Z
# uuid: 81264472-75a3-43ea-a9a0-2462f9663c21
# comment: Tested in Bash version 5.2.21. Debounces 1500~ Hz.
# ---
declare -A debounceStatuses
declare -A debounceResults
declare -A debounceTimes
debounce()
{
  if [[ $# -eq 0 || $1 == -h || $1 == --help ]]
  then
    >&2 echo "USAGE: debounce SECONDS COMMAND…; # If SECONDS is '0', use cache indefinitely."
    return 1
  fi
  local oIFS="$IFS" status result keep now commandKey previousTime
  local IFS=' '
  keep=$1
  shift
  now=$(date '+%s')
  IFS='_'
  commandKey="$*"
  IFS=' '
  previousTime=${debounceTimes[$commandKey]}
  if [[ -n $previousTime ]]
  then
    if [[ $keep == 0 || $((now - previousTime)) -le $keep ]]
    then
      status=${debounceStatuses[$commandKey]}
      result="${debounceResults[$commandKey]}"
      [[ -n $result ]] && echo "$result"
      return $status
    fi
  fi
  result="$("$@")"
  status=$?
  debounceResults[$commandKey]="$result"
  debounceStatuses[$commandKey]=$status
  debounceTimes[$commandKey]=$now
  [[ -n $result ]] && echo "$result"
  return $status
}

## $ bash --version | head -1 # GNU bash, version 5.2.21(1)-release (x86_64-pc-linux-gnu)
## $ for i in {1..10000}; do debounce 1 date '+%s.%N'; done | uniq -c
##   1241 1758648773.461707839
##   1591 1758648775.001673869
##   1639 1758648777.001492688
##   1601 1758648779.001412630
##   1501 1758648781.002362345
##   1498 1758648783.001434399
##    929 1758648785.002029052
