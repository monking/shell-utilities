containsAny() {
	# ---
	# name: containsAny
	# description: Exits 0 if any PATTERN matches any VALUE.
	# summary: containsAny [OPTIONS] PATTERN… -- VALUE…
	# date: 2024-12-26T13:34:11-08
	# uuid: 58db8c39-a538-42fb-84a9-efce6475df5b
	# ...
  local set=();
  local constantGrepArgs=();
  local patternsFullLiteral=();
  local patternsGrep=();
  local patternsGrepFixed=();
  while [[ $# -gt 0 ]]; do
    case $1 in
      --) shift; set+=("$@"); break;;
      -q|--quiet|--silent|-E|--extended-regexp) constantGrepArgs+="$1";;
      -g) patternsGrep+=("$2"); shift;;
      -F|--fixed-strings) patternsGrepFixed+=("$2"); shift;; # QUIRK: Using grep arg names, but also expecting 2nd arg (CL 2024-12-26).
      *) patternsFullLiteral+=("$1");;
    esac
    shift;
  done
  #>&2 echo "[containsAny] set(${#set[@]}) = ${set[*]}";
  #>&2 echo "[containsAny] patternsFullLiteral(${#patternsFullLiteral[@]}) = ${patternsFullLiteral[*]}";
  #>&2 echo "[containsAny] patternsGrep(${#patternsGrep[@]}) = ${patternsGrep[*]}";
  #>&2 echo "[containsAny] patternsGrepFixed(${#patternsGrepFixed[@]}) = ${patternsGrepFixed[*]}";
  local item text pattern
  for item in "${set[@]}"; do
    for text in "${patternsFullLiteral[@]}"; do
      if [[ "$item" == "$text" ]]; then
        return 0;
      fi
    done
    for pattern in "${patternsGrepFixed[@]}"; do
      if echo -n "$item" | grep "${constantGrepArgs[@]}" -F "$pattern"; then
        return 0;
      fi
    done
    for pattern in "${patternsGrep[@]}"; do
      if echo -n "$item" | grep "${constantGrepArgs[@]}" "$pattern"; then
        return 0;
      fi
    done
  done
  return 1;
}
