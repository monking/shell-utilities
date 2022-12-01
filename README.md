- `canon`: recursively resolve any symlinks to get the "canonical" path
- `git-branch-grep`: grep branches, returns the best match, or gives feedback when it fails
- `git-bundle-helper`: a somewhat outdated helper to create git bundles, and optionally encrypt them with `bcrypt` (the outdated part).
- `git-todo`: search for _new_ notes in source code (compared with a "main" git branch)
- `make-it-manifest`: generate a list of all files in a directory, optionally with MD5 sums and Git commit hashes
- `tree-tab`: transform `tree` output to tab-indented list
- `web-search`: search a few preset sites using the `lynx` command-line browser
	- `duck` -> `web-search`: search duckduckgo.com
	- `etym` -> `web-search`: search etymonline.com
	- `goog` -> `web-search`: search google.com
	- `wiki` -> `web-search`: search en.wikipedia.org
- `youtube-playlist-sync`: automate `youtube-dl` to mirror a YouTube playlist as a `.m3u8` file
- `yt`: stream or download using `youtube-dl`

## `sumdir`+`checkdir`

Call `sumdir` to calculate hash/checksum values for files in a directory.  
Then call `checkdir` in that same directory to verify files, and list changed/mismatched files.

NOTE: The output of `sumdir` is also intended to be generic, so that you can use other commands besides `checkdir` to verify the sums files(sha256sum/shasum/b2sum/…). The relevant command is included in a comment at the top of the output file's contents, for the user's future reference.

### sumdir

```
USAGE: sumdir [OPTIONS] [help] [PATH...]

OPTIONS:
  -h|--help|help     Show this help
  -a CMD             Hashing algorithm to use. Currently supported: 'sha256', 'b2'.
  -r                 Recurse into directory
  -L                 Dereference symlinks
  -1|--single        Remove existing *SUM* sumfiles in this directory
                      (trash-cli, falls back to rm).
                      Only this directory, even with -r.
  -o|--out TEMPLATE  Output file name template. See 'TEMPLATES' below for
        substitution patterns.
  -l                 Include hostname and PWD in output sumfile.
                      Affected by -L.
  -z|--tz TZ         Set timezone for timestamp; default 'UTC'
  -f|--dateformat    Set format for timestamp (per GNU coreutils date)
  -v|--verbose       Increase the detail of the info output to STDERR
  --verbose=N        Set the verbose level
  -x|--exclude PATTERN   Exclude files by name, per find '! -name PATTERN'
  -X|--exclude-path PATTERN  Exclude files by name, per find '! -path PATTERN';
                      usually of form '*PATTERN*'
  --length N         Digest length in bits (b2sum only). Digests appear 1/4 this length in hexadecimal.
                      Default and maximum is 512 (for an output 128 chars long).
                      This is the same as setting the env var SUMDIR_OPT_LIST_SUM_OPTS='--length:N'.
  --                 After this, all further arguments are passed to 'find'
  --bk               Same as -f '%d..%ASUM'
  --version          Output version information

DESCRIPTION:
  If no PATH is specified, the current directory ($PWD) is used.
  
  If no SUMFILE is specified, .*SUM* and *SUM* is globbed, and the newest one is used.
  
  TEMPLATES
   The following strings are substituted for dynamic values:
   '%d' or '{}'  =>  Datetime as formatted by -f
   '%a'  =>  Algorithm ('sha256', 'b2', …)
   '%A'  =>  Algorithm uppercase ('SHA256', 'B2', …)
   
  
  ENVIRONMENT VARIABLES
   *_SHOULD_* options expect true or false values.
   *_LIST_* options must be specified colon-separated like PATH.
  
   You may set any of the options above by using the following environment variables.
   They are shown here with their default values, if available.
   SUMDIR_ALGORITHM='sha256'
   SUMDIR_DATE_FORMAT='+%Y%m%dT%H%M%SZ'
   SUMDIR_LIST_EXCLUDE_NAME='.DS_Store:.thumbnails'
   SUMDIR_LIST_EXCLUDE_PATH='*/.git/*:*/node_modules/*'
   SUMDIR_LIST_SUM_OPTS
   SUMDIR_OUTPUT_FILE_TEMPLATE='.SUM%A--%d'
   SUMDIR_SHOULD_DEREFERENCE='false'
   SUMDIR_SHOULD_INCLUDE_LOCATION_IN_OUTPUT='false'
   SUMDIR_SHOULD_RECURSE='false'
   SUMDIR_SHOULD_SINGLE_HASH_FILE='false'
   SUMDIR_TIMEZONE='UTC'
   SUMDIR_VERBOSE='0'
```
<small>^ output from `sumdir --help` from v0.1.0 2022-12-01</small>

### checkdir

```
USAGE: checkdir [OPTIONS] [SUMFILE]

OPTIONS:
  --help|help|-h  Show this help
  --version       Show the script version

DESCRIPTION:
  If no SUMFILE is specified, .*SHA256SUM* and *SHA256SUM* is globbed, and the newest one is used.
```
<small>^ output from `checkdir --help` from v0.0.4 2022-12-01</small>
