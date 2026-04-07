getDescendantPIDs()
{
  # ---
  # summary: Echoes given PIDs + all descendents
  # version: 0.0.2
  # uuid: 4f0a59a2-3ef1-4762-8167-cee8e7d111a3
  # comment: |
  #   Similar output to
  #   `pstree -p $pid | grep -o '([0-9]\+)' | grep -o '[0-9]\+'`
  #   <https://unix.stackexchange.com/a/83008>,
  #   with fewer assumptions.
  # ...
  local parentPIDs=("$@")
  local allPIDs=()
  local childPIDs=()
  local pidList=
  while true
  do
    for ppid in ${parentPIDs[@]}
    do
      # Don't output parent IDs not still running.
      kill -0 $ppid &>/dev/null \
        && allPIDs+=($ppid)
    done
    IFS=,
    pidList=${parentPIDs[*]}
    IFS="$oIFS"
    childPIDs=($(pgrep -P $pidList))
    [[ $? -eq 0 && ${#childPIDs[@]} -gt 0 ]] \
      || break
    allPIDs+=(${childPIDs[@]})
    parentPIDs=(${childPIDs[@]})
  done
  echo ${allPIDs[*]}
}
