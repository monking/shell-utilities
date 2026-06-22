#!/bin/bash

READ_CONFIG_VERSION=0.7.0
READ_CONFIG_MODIFIED=2026-06-19

shopt -s extglob # For +() pattern matching (stripping indentation, mushing -vv together).

read-config()
{
  local oIFS="$IFS"
  local IFS="$oIFS"
  local activeContexts=()
  local catArgs=()
  local configComments=()
  local configNameBase=config
  local key value
  local shouldUnsetFirst=false
  local verbose=0

  while [[ $# -gt 0 ]]
  do
    case $1 in
      -h|--help)
        echo "$HELP_READ_CONFIG" | less
        return
        ;;
      -f)
        local sourcePath="$2"
        [[ $sourcePath =~ ^\./ ]] && sourcePath="$PWD/${sourcePath#./}"
        catArgs+=("$sourcePath")
        shift
        ;;
      -c)
        IFS=','
        activeContexts+=($2)
        IFS="$oIFS"
        shift
        ;;
      --context=*)
        IFS=','
        activeContexts+=(${1#--context=})
        IFS="$oIFS"
        ;;
      -n)
        configNameBase="$2"
        shift
        ;;
      --name=*) configNameBase="${1#--name=}";;
      -u|--unset) shouldUnsetFirst=true;;
      -+(v)) let verbose+=$((${#1} - 1));;
      *) configComments+=("Unknown argument: $1");;
    esac
    shift
  done

  if [[ $shouldUnsetFirst == true ]]
  then
    local existingMaps
    eval "existingMaps=(\${_${configNameBase}_maps[@]})"
    if [[ ${#existingMaps[@]} -gt 0 ]]
    then
      for mapName in "${existingMaps[@]}"
      do
        unset $mapName
      done
    else
      unset $configNameBase
    fi
  fi
  declare -g -A $configNameBase
  declare -a configMaps=($configNameBase)
  declare -a configContexts=()
  local contextName= contextSuffix= isContextMatched=

  assignKey() {
    local isAppending assignmentOperator='='
    local valuePrefix
    while [[ $# -ge 3 ]]
    do
      case $1 in
        --sep=*)
          valuePrefix="${1#*=}"
          ;;
        --append)
          assignmentOperator='+='
          ;;
        --)
          shift
          break
          ;;
        *) break;;
      esac
      shift
    done
    local escapedKey="$(printf %q "$1")"
    local assignmentRightSide="${assignmentOperator}$(printf %q "${valuePrefix}${2}")"
    eval "${configNameBase}${contextSuffix}[${escapedKey}]${assignmentRightSide}"
    if [[ -n $contextSuffix && $isContextMatched == true ]]
    then
      eval "${configNameBase}[${escapedKey}]${assignmentRightSide}"
    fi
  }

  [[ $verbose -ge 1 && ${#catArgs[@]} -ge 1 ]] && >&2 echo "# [read-config] Reading config from: ${catArgs[*]}"

  local isAppendingToKey= assignArgs=()

  while read -r line
  do
    [[ $verbose -ge 2 ]] && >&2 echo "# [read-config] line: $line"
    assignArgs=()
    if [[ -n $isAppendingToKey ]]
    then
      key="$isAppendingToKey"
      value="${line#+([[:space:]])}"
      if [[ $value =~ \\$ ]]
      then
        value="${value%\\}"
      else
        isAppendingToKey=
      fi
      assignKey --append "$key" "$value" # trim leading spaces
      continue
    fi
    case $line in
      '') continue;;
      *([[:space:]])\#*) configComments+=("$line");;
      *([[:space:]])\[*\])
        contextName="${line//[\[\]]/}" # trim brackets
        isContextMatched=false
        for givenContext in "${activeContexts[@]}"
        do
        if [[ $givenContext == $contextName ]]
        then
          isContextMatched=true
          if [[ $verbose -ge 1 ]]
          then
            >&2 echo "# [read-config] MATCH context: $contextName"
          fi
          break
        fi
        done
        contextSuffix="_${contextName//[^[:alnum:]]/_}" # substitute underscores for non-alphanumeric characters
        [[ $shouldUnsetFirst == true ]] && unset "${configNameBase}${contextSuffix}"
        eval "declare -g -A \"${configNameBase}${contextSuffix}\""
        configMaps+=("${configNameBase}${contextSuffix}")
        configContexts+=("$contextName")
        ;;
      *=*)
        key="${line%%=*}"
        if [[ $key =~ \+$ ]]
        then
          key="${key%+}"
          assignArgs+=(--append --sep=$'\n')
        fi
        key="${key##+([[:space:]])}" # trim leading spaces
        value="${line#*=}"
        [[ ${value:0:1} == '~' ]] && value="${HOME}${value#\~}"
        if [[ $value =~ \\$ ]]
        then
          isAppendingToKey="$key"
          value="${value%\\}"
        fi
        assignArgs+=("$key" "$value")
        assignKey "${assignArgs[@]}"
        assignArgs=()
        ;;
      *) configComments+=("$line");;
    esac
  done <<<"$(cat "${catArgs[@]}")"

  local mapDef="$(declare -p configMaps)"
  [[ $shouldUnsetFirst == true ]] && unset "_${configNameBase}_maps"
  mapDef="${mapDef/configMaps/-g _${configNameBase}_maps}"
  eval "${mapDef}"

  local contextsDef="$(declare -p configContexts)"
  [[ $shouldUnsetFirst == true ]] && unset "_${configNameBase}_contexts"
  contextsDef="${contextsDef/configContexts/-g _${configNameBase}_contexts}"
  eval "${contextsDef}"

  local commentsDef="$(declare -p configComments)"
  [[ $shouldUnsetFirst == true ]] && unset "_${configNameBase}_comments"
  commentsDef="${commentsDef/configComments/-g _${configNameBase}_comments}"
  eval "${commentsDef}"

  local allDefined=("${configMaps[@]}" "_${configNameBase}_maps" "_${configNameBase}_contexts" "_${configNameBase}_comments")

  if [[ $verbose -ge 1 ]]
  then
    declare -p "${allDefined[@]}"
  fi
}

HELP_READ_CONFIG="$(cat <<'EOF_HELP'
SUMMARY: Read config text into shell variables.
USAGE: read-config [-c,--context=CONTEXT[,…] [-n,--name=NAME] [-f FILE] [-v…] [-h]
BEHAVIOR, OPTIONS:
  If no NAME is specified, it defaults to 'config'.
  Associative arrays (maps) are created:
  * NAME: containing the main config, joined with any CONTEXTs matching -c CONTEXT
  * NAME_CONTEXT…: one for each CONTEXT in the config input (where the _CONTEXT suffix has '_' (underscore) in place of any non-alphanumeric characters.)

  Indexed arrays (lists) are also created:
  * _NAME_maps: the names of the associative arrays
  * _NAME_contexts: the unaltered names of the contexts in the config input
  * _NAME_comments: any comment or unknown lines in the config input

  If one or more CONTEXT is given (either multiple -c, or as comma-separated list),
    then matching contexts are combined into the primary config array.
  Without `-u`,`--unset`, any array that exists before the command is run will be added to.
  FILE may be `-` to read from STDIN (same as the default when -f FILE is omitted).
  Show verbose output with -v… (e.g. -vv for more info). Show this help with -h or --help.

CONFIG FORMAT:
  The config format is akin to TOML, but stupider.
  * Definitions are KEY=VALUE, without space around '=', and without quotation.
  * Indentation is ignored everywhere.
  * Lines in [square brackets] begin a CONTEXT.
  * A '~' tilde at the beginning of a VALUE will be substituted with $HOME.
  * Lines ending with '\' backslash carry over VALUE definitions into the next line.
  * Definitions may be appended with KEY+=VALUE. VALUEs are appended on a new line.
  * Definitions occur in the config line order, not the -c CONTEXT argument order.
  * A line beginning with '#' is a comment; the '#' may be indented.
  * Comments cannot be on the same line as a value. A '#' on a VALUE line is part of the VALUE.
  * Lines not understood by the format are treated as comments.
  * CONTEXT may not contain commas, but may contain spaces and other punctuation.

EXAMPLE:
```
read-config -v -c overtime,home < <(cat <<'EOF'
  title=Sample config file
  myName=Nobody
  [home]
    Whoops, bad line\
    title+=* No commute
    myName=Nick\
      name \
      for days
    # Note that space before '\' wrap remains.
  [office]
    myName=Nicholas
    title+=* Serious business.
  [overtime]
    title+=* For the long haul.
EOF
)
# [read-config] MATCH context: home
# [read-config] MATCH context: overtime
declare -A config=([myName]="Nickname for days" [title]=$'Sample config file\n* No commute\n* For the long haul.' )
declare -A config_home=([myName]="Nickname for days" [title]=$'\n* No commute' )
declare -A config_office=([myName]="Nicholas" [title]=$'\n* Serious business.' )
declare -A config_overtime=([title]=$'\n* For the long haul.' )
declare -a _config_maps=([0]="config" [1]="config_home" [2]="config_office" [3]="config_overtime")
declare -a _config_contexts=([0]="home" [1]="office" [2]="overtime")
declare -a _config_comments=([0]="Whoops, bad line\\" [1]="# Note that space before '\\' wrap remains.")
```
(END EXAMPLE)

NOTE: If read-config is run in a subshell, its results will not exist outside that subshell.
  For example, `echo key=value | read-config;` will not work as intended.
  You might do `read-config < <(echo key=value)` instead.
  For more about subshells and pipelines, see:
    https://www.gnu.org/software/bash/manual/html_node/Pipelines.html#Pipelines-1:~:text=its%20own%20subshell
EOF_HELP
)

(read-config version ${READ_CONFIG_VERSION} ${READ_CONFIG_MODIFIED})"
