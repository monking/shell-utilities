# shell-utilities

These are extracts from my homespun scripts which I've prepared for general use
by anyone.

- [`canon`](./canon): recursively resolve any symlinks to get the "canonical" path
- [`date-week`](./date-week): Wrapper for GNU date which parses ISO Week dates (e.g. '2025W023').
- [`git-branch-grep`](./git-branch-grep): grep branches, returns the best match, or gives feedback when it fails
- [`git-todo`](./git-todo): search for _new_ notes in source code (compared with a "main" git branch)
- [`read-config`](./read-config.sh): read config text into shell variables.
- [`sumdir`](./sumdir) & [`checkdir`](./checkdir): generate & verify hashes for files, with good defaults (uses `.SUM*` files)
- [`sync`](./sync): copy files per any/several `.sync.conf` files.
- [`tree-tab`](./tree-tab): transform [`tree`](https://oldmanprogrammer.net/source.php?dir=projects/tree) output to tab-indented list
- [`youtube-playlist-sync`](./youtube-playlist-sync): Mirror a YouTube playlist as a `.m3u8` file, using `yt-dlp` (or `youtube-dl`)

…and more [outdated scripts](#outdated-scripts-sunsetting)

## `sumdir`+`checkdir`

Call `sumdir` to calculate hash/checksum values for files in a directory.  
Then call `checkdir` in that same directory to verify files, and list changed/mismatched files.

NOTE: The output of `sumdir` is also intended to be generic, so that you can use other commands besides `checkdir` to verify the sums files (sha256sum/shasum/b2sum/…). The relevant command is included in a comment at the top of the output file's contents, for the user's future reference.

### sumdir

```
USAGE: sumdir [OPTIONS] [PATH...]
PURPOSE: Coordinates the generation and output of many checksums.

OPTIONS:
  -h,--help,help
      Show this help
  
  -a CMD
      Hashing algorithm to use. Currently supported: 'sha256', 'b2'. env: SUMDIR_ALGORITHM.
  
  -r                
      into directory. env: SUMDIR_SHOULD_RECURSE
  
  -L                
      symlinks. env: SUMDIR_SHOULD_DEREFERENCE
  
  -1,--single
      Remove existing *SUM* SUMFILEs in this directory (trash-cli, falls back to rm). Only this directory, even with -r. env: SUMDIR_SHOULD_SINGLE_HASH_FILE
  
  -o,--out TEMPLATE
      Output file name template. See 'TEMPLATES' below for substitution patterns. env: SUMDIR_OUTPUT_FILE_TEMPLATE
  
  -l                
      hostname and PWD in output SUMFILE. Affected by -L. env: SUMDIR_SHOULD_INCLUDE_LOCATION_IN_OUTPUT
  
  -z,--tz TZ
      Set timezone for timestamp; default 'UTC'. env: SUMDIR_TIMEZONE
  
  -f,--dateformat
      Set format for timestamp (per GNU coreutils date). env: SUMDIR_DATE_FORMAT
  
  -v,--verbose[=N]  
      the detail of the info output to STDERR. env: SUMDIR_VERBOSE
  
  -x,--exclude PATTERN
      Exclude files by name, per find '! -name PATTERN'. env: SUMDIR_LIST_EXCLUDE_NAME
  
  -X,--exclude-path PATTERN
      Exclude files by name, per find '! -path PATTERN'; usually of form '*PATTERN*'. env: SUMDIR_LIST_EXCLUDE_PATH
  
  --length N        
      length in bits (b2sum only). Digests appear 1/4 this length in hexadecimal.
                      Default and maximum is 512 (for an output 128 chars long).
                      This is the same as setting the env var SUMDIR_LIST_B2_OPTS='--length:N'.
       env: SUMDIR_LIST_%A_OPTS, where %A is the algorithm in upper case (SHA256 or B2).
  --
      After this, all further arguments are passed to 'find'
  
  --bk
      Same as -f '%d..%ASUM'
  
  --version
      Output version information

DESCRIPTION:
  If no PATH is specified, the current directory ($PWD) is used.
  
  If no SUMFILE is specified, .*SUM* and *SUM* is globbed, and the newest one is used.
  
  TEMPLATES
   The following strings are substituted for dynamic values:
   '%d' or '{}'  =>  Datetime as formatted by -f
   '%a'  =>  Algorithm ('sha256', 'b2', …)
   '%A'  =>  Algorithm uppercase ('SHA256', 'B2', …)
   
  
  ENVIRONMENT VARIABLES
   *_SHOULD_* options expect 'true' or 'false' values.
   *_LIST_* options must be colon-separated like PATH.
  
   You may set any of the options above by using the following environment variables.
   They are shown here with their default values, if available.
   SUMDIR_ALGORITHM='sha256'
   SUMDIR_DATE_FORMAT='+%Y%m%dT%H%M%SZ'
   SUMDIR_LIST_EXCLUDE_NAME='.DS_Store:.thumbnails'
   SUMDIR_LIST_EXCLUDE_PATH='*/.git/*:*/node_modules/*'
   SUMDIR_LIST_B2_OPTS
   SUMDIR_LIST_SHA_OPTS
   SUMDIR_OUTPUT_FILE_TEMPLATE='.SUM%A--%d'
   SUMDIR_SHOULD_DEREFERENCE='false'
   SUMDIR_SHOULD_INCLUDE_LOCATION_IN_OUTPUT='false'
   SUMDIR_SHOULD_RECURSE='false'
   SUMDIR_SHOULD_SINGLE_HASH_FILE='false'
   SUMDIR_TIMEZONE='UTC'
   SUMDIR_VERBOSE='0'

EXAMPLES:
  $ sumdir -r -o ./externalDrive-%d /mnt/externalDrive
    # Sum files from a different location, and save output in the current directory.
```
<small>^ output from `sumdir --help` from v0.1.7 2024-12-26</small>

### checkdir

```
USAGE: checkdir [OPTIONS] [SUMFILE…]

OPTIONS:
  --help|help|-h  Show this help.
  --version       Show the script version.
  -a ALG          Set encryption algorithm.
  -e              Only check if files in SUMFILE exist, and output missing filenames.
  -l              Only output the SUMFILE path found/selected.
  -v              Show more verbose output.

DESCRIPTION:
  If no SUMFILE is specified, .*SHA256SUM* and *SHA256SUM* is globbed in the current directory, and the newest one is used.
```
<small>^ output from `checkdir --help` from v0.1.1 2024-12-26</small>


### read-config

```
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
  * Lines in square brackets begin a CONTEXT.
  * Indentation is ignored everywhere.
  * Lines ending with '\' backslashes carry over VALUE definitions into the next line.
  * A line beginning with '#' is a comment; the '#' may be indented.
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

NOTE: Definitions won't reach the call context if read-config is in a subshell, such as `echo key=value | read-config`. You might do `read-config <<<"$(echo key=value)"` instead.

(read-config version 0.6.3 2026-03-12)
```


### sync

```
SYNOPSIS: Copies files from wherever a .sync.conf file is found.

USAGE: sync [-h|--help] [-d PATH] [-n|--dry-run] [-y|--no-prompt] [-v[v…]|--verbose|-q|--quiet]

CONFIG (see shell-utilities/read-config.sh):
  destination=PATH
  subdir=DATEFORMAT
  exclude=PATTERN or ('PATTERN'…)
  keepcopy=true|false
  postprocess=COMMAND # where $1 is the destination (sub)directory. Runs after all sync operations.
  [HOSTNAME] groups

OPTIONS:
  -h,--help  Show this help.
  -d PATH  Path to directory to search for .sync.conf files. Defaults to $PWD.
  -n,--dry-run  Make no changes, move no files. Find .sync.conf files, and print commands. Implies -y.
  -y,--no-prompt  Begin syncing without prompting the user first.
  -v,--verbose  Show more info. Can be used multiple times.
  -q,--quiet  Suppress most output.

VERSION: 0.4.4 2026-03-12
```

## outdated scripts (sunsetting)

Some scripts may be retired from this collection **if** (any of these):
- they're not maintained
- their use case is better served by a better utility
- they tend to have undefined behavior
- they have uncommon dependencies

The following scripts have been moved into the `.disused` folder:
- [`git-bundle-helper`](./.disused/git-bundle-helper): a somewhat outdated helper to create git bundles, and optionally encrypt them with `bcrypt` (the outdated part).
- [`make-it-manifest`](./.disused/make-it-manifest): generate a list of all files in a directory, optionally with MD5 sums and Git commit hashes
- [`web-search`](./.disused/web-search): search a few preset sites using the `lynx` command-line browser
	- `duck` -> `web-search`: Search duckduckgo.com
	- `etym` -> `web-search`: Search etymonline.com
	- `goog` -> `web-search`: Search google.com
	- `wiki` -> `web-search`: Search en.wikipedia.org
- [`yt`](./.disused/yt): stream or download using `yt-dlp` (or `youtube-dl`)
