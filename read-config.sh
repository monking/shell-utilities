#!/bin/bash

READ_CONFIG_VERSION=0.6.6
READ_CONFIG_MODIFIED=2026-04-22

shopt -s extglob # For +() pattern matching (stripping indentation, mushing -vv together).
read-config()
{
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
        echo "$HELP_READ_CONFIG"
        return
        ;;
      -f)
        local sourcePath="$2"
        [[ $sourcePath =~ ^\./ ]] && sourcePath="$PWD/${sourcePath#./}"
        catArgs+=("$sourcePath")
        shift
        ;;
      -c)
        activeContexts+=("$2")
        shift
        ;;
      --context=*) activeContexts+="${1#--context=}";;
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
    local existingHashes
    eval "existingHashes=(\${_${configNameBase}_hashes[@]})"
    if [[ ${#existingHashes[@]} -gt 0 ]]
    then
      for hashName in "${existingHashes[@]}"
      do
        unset $hashName
      done
    else
      unset $configNameBase
    fi
  fi
  declare -g -A $configNameBase
  declare -a configHashes=($configNameBase)
  declare -a configContexts=()
  local contextName= contextSuffix= isContextMatched=

  assignKey() {
    local isAppending assignmentOperator='='
    while [[ $# -ge 3 ]]
    do
    case $1 in
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
    local assignmentRightSide="${assignmentOperator}$(printf %q "$2")"
    eval "${configNameBase}${contextSuffix}[${escapedKey}]${assignmentRightSide}"
    if [[ -n $contextSuffix && $isContextMatched == true ]]
    then
      eval "${configNameBase}[${escapedKey}]${assignmentRightSide}"
    fi
  }

  [[ $verbose -ge 1 && ${#catArgs[@]} -ge 1 ]] && >&2 echo "# [read-config] Reading config from: ${catArgs[*]}"

  local isAppendingToKey=

  while read -r line
  do
    [[ $verbose -ge 2 ]] && >&2 echo "# [read-config] line: $line"
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
        configHashes+=("${configNameBase}${contextSuffix}")
        configContexts+=("$contextName")
        ;;
      *=*)
        key="${line%%=*}"
        key="${key##+([[:space:]])}" # trim leading spaces
        value="${line#*=}"
        [[ ${value:0:1} == '~' ]] && value="${HOME}${value#\~}"
        if [[ $value =~ \\$ ]]
        then
          isAppendingToKey="$key"
          value="${value%\\}"
        fi
        assignKey "$key" "$value"
        ;;
      *)
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
        else
          configComments+=("$line")
        fi
    esac
  done <<<"$(cat "${catArgs[@]}")"

  local hashDef="$(declare -p configHashes)"
  [[ $shouldUnsetFirst == true ]] && unset "_${configNameBase}_hashes"
  hashDef="${hashDef/configHashes/-g _${configNameBase}_hashes}"
  eval "${hashDef}"

  local contextsDef="$(declare -p configContexts)"
  [[ $shouldUnsetFirst == true ]] && unset "_${configNameBase}_contexts"
  contextsDef="${contextsDef/configContexts/-g _${configNameBase}_contexts}"
  eval "${contextsDef}"

  local commentsDef="$(declare -p configComments)"
  [[ $shouldUnsetFirst == true ]] && unset "_${configNameBase}_comments"
  commentsDef="${commentsDef/configComments/-g _${configNameBase}_comments}"
  eval "${commentsDef}"

  local allDefined=("${configHashes[@]}" "_${configNameBase}_hashes" "_${configNameBase}_contexts" "_${configNameBase}_comments")

  if [[ $verbose -ge 1 ]]
  then
    declare -p "${allDefined[@]}"
  fi
}

HELP_READ_CONFIG="$(cat <<'EOF_HELP'
SUMMARY: Read config text into shell variables.
USAGE: read-config [-c,--context=CONTEXT…] [-n,--name=NAME] [-f FILE] [-v…] [-h]
BEHAVIOR, OPTIONS:
  If no NAME is specified, it defaults to 'config'.
  Associative arrays (hashes) are created:
  * NAME: containing the main config, joined with any CONTEXTs matching -c CONTEXT
  * NAME_CONTEXT…: one for each CONTEXT in the config input (where the _CONTEXT suffix has '_' (underscore) in place of any non-alphanumeric characters.)

  Indexed arrays (lists) are also created:
  * _NAME_hashes: the names of the associative arrays
  * _NAME_contexts: the unaltered names of the contexts in the config input
  * _NAME_comments: any comment or unknown lines in the config input

  If one or more CONTEXT is given with -c, then matching contexts are combined into the primary config array.
  Without `-u`,`--unset`, any array that exists before the command is run will be added to.
  FILE may be `-` to read from STDIN (same as the default when -f FILE is omitted).
  Show verbose output with -v… (e.g. -vv for more info). Show this help with -h or --help.

CONFIG FORMAT:
  The config format is akin to TOML, but stupider.
  * Definitions are 'KEY=VALUE', without space around '=', and without quotation.
  * VALUE beginning with '~' will have $HOME substituted for '~'
  * Lines in square brackets begin a CONTEXT.
  * Indentation is ignored everywhere.
  * Lines ending with '\' backslashes carry over VALUE definitions into the next line.
  * A line beginning with '#' is a comment; the '#' may be indented.
  * A '#' after a non-whitespace character is part of the value. Comments cannot be on the same line as a value.
  * Lines not understood by the format are also considered comments.

CONFIG EXAMPLE:
  title=Sample config file
  myName=Nobody
  [home]
    Whoops, bad line\
    myName=Nick\
      name \
      for days
  [office]
    myName=Nicholas
  [office.overtime]
    # serious business
    myName=Nicholas, Sir

read via `read-config -v -c office`, results in:
  # [read-config] MATCH context: office
  declare -A config=([myName]="Nicholas" [title]="Sample config file" )
  declare -A config_home=([myName]="Nickname for days" )
  declare -A config_office=([myName]="Nicholas" )
  declare -A config_office_overtime=([myName]="Nicholas, Sir" )
  declare -a _config_hashes=([0]="config" [1]="config_home" [2]="config_office" [3]="config_office_overtime")
  declare -a _config_contexts=([0]="home" [1]="office" [2]="office.overtime")
  declare -a _config_comments=([0]="Whoops, bad line\\" [1]="# serious business")

NOTE: If read-config is run in a subshell, such as in a pipeline like `echo key=value | read-config`*, its results will not exist outside that subshell. You might do `read-config < <(echo key=value)` instead.
  * For more about subshells and pipelines, see <https://www.gnu.org/software/bash/manual/html_node/Pipelines.html#Pipelines-1:~:text=its%20own%20subshell>
EOF_HELP
)

(read-config version ${READ_CONFIG_VERSION} ${READ_CONFIG_MODIFIED})"
