#!/bin/bash
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
        help-read-config
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

  [[ $shouldUnsetFirst == true ]] && unset $configNameBase
  declare -g -A $configNameBase
  declare -a configHashes=($configNameBase)
  declare -a configContexts=()
  local contextName= contextSuffix= isContextMatched=

  assignKey() {
    local escapedValue isAppending assignmentOperator='='
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
    local key="$1" value="$2"
    escapedValue="$(echo -E "$value" | sed 's/\([\\"$]\)/\\\1/g')"
    local assignmentRightSide="${assignmentOperator}\"${escapedValue}\""
    eval "${configNameBase}${contextSuffix}[${key}]${assignmentRightSide}"
    if [[ -n $contextSuffix && $isContextMatched == true ]]
    then
      eval "${configNameBase}[${key}]${assignmentRightSide}"
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

help-read-config()
{
  echo "SUMMARY: Create associative arrays from config input from STDIN or FILE."
  echo "USAGE: read-config [-c,--context=CONTEXT…] [-n,--name=NAME] [-f FILE] [-v…] [-h]"
  echo "BEHAVIOR, OPTIONS:"
  echo "  If no NAME is specified, it defaults to 'config'."
  echo "  Associative arrays (hashes) are created:"
  echo "  * NAME: containing the main config, joined with any CONTEXTs matching -c CONTEXT"
  echo "  * NAME_CONTEXT…: one for each CONTEXT in the config input (where the _CONTEXT suffix has '_' (underscore) in place of any non-alphanumeric characters.)"
  echo
  echo "  Indexed arrays (lists) are also created:"
  echo "  * _NAME_hashes: the names of the associative arrays"
  echo "  * _NAME_contexts: the unaltered names of the contexts in the config input"
  echo "  * _NAME_comments: any comment or unknown lines in the config input"
  echo
  echo "  If one or more CONTEXT is given with -c, then matching contexts are combined into the primary config array."
  echo "  Without \`-u\`,\`--unset\`, any array that exists before the command is run will be added to."
  echo "  FILE may be \`-\` to read from STDIN (same as the default when -f FILE is omitted)."
  echo "  Show verbose output with -v… (e.g. -vv for more info). Show this help with -h or --help."
  echo
  echo "CONFIG FORMAT:"
  echo "  The config format is akin to TOML, but stupider."
  echo "  * Definitions are 'KEY=VALUE', without space around '=', and without quotation."
  echo "  * Lines in square brackets begin a CONTEXT."
  echo "  * Indentation is ignored everywhere."
  echo "  * Lines ending with '\\' backslashes carry over VALUE definitions into the next line."
  echo "  * A line beginning with '#' is a comment; the '#' may be indented."
  echo "  * Lines not understood by the format are also considered comments."
  echo
  echo "CONFIG EXAMPLE:"
  echo "  title=Sample config file"
  echo "  myName=Nobody"
  echo "  [home]"
  echo "    Whoops, bad line\\"
  echo "    myName=Nick\\"
  echo "      name \\"
  echo "      for days"
  echo "  [office]"
  echo "    myName=Nicholas"
  echo "  [office.overtime]"
  echo "    # serious business"
  echo "    myName=Nicholas, Sir"
	echo
  echo "read via \`read-config -v -c office\`, results in:"
  echo "  # [read-config] MATCH context: office"
  echo "  declare -A config=([myName]=\"Nicholas\" [title]=\"Sample config file\" )"
  echo "  declare -A config_home=([myName]=\"Nickname for days\" )"
  echo "  declare -A config_office=([myName]=\"Nicholas\" )"
  echo "  declare -A config_office_overtime=([myName]=\"Nicholas, Sir\" )"
  echo "  declare -a _config_hashes=([0]=\"config\" [1]=\"config_home\" [2]=\"config_office\" [3]=\"config_office_overtime\")"
  echo "  declare -a _config_contexts=([0]=\"home\" [1]=\"office\" [2]=\"office.overtime\")"
  echo "  declare -a _config_comments=([0]=\"Whoops, bad line\\\\\" [1]=\"# serious business\")"
  echo
  echo "NOTE: Definitions won't reach the call context if read-config is in a subshell, such as \`echo key=value | read-config\`. You might do \`read-config <<<\"\$(echo key=value)\"\` instead."
  echo
  echo "(read-config version 0.6.3 2026-03-12)"
}
