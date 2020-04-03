#!/bin/bash
# realpath() included to allow portability to macos {{{
# adapted from https://github.com/mkropat/sh-realpath
# Used under https://github.com/mkropat/sh-realpath/blob/master/LICENSE.txt
realpath() {
    canonicalize_path "$(resolve_symlinks "$1")"
}

resolve_symlinks() {
    _resolve_symlinks "$1"
}

_resolve_symlinks() {
    _assert_no_path_cycles "$@" || return

    local dir_context path
    if path=$(readlink -- "$1")
    then
        dir_context=$(dirname -- "$1")
        _resolve_symlinks "$(_prepend_dir_context_if_necessary "$dir_context" "$path")" "$@"
    else
        printf '%s\n' "$1"
    fi
}

_prepend_dir_context_if_necessary() {
    if [ "$1" = . ]; then
        printf '%s\n' "$2"
    else
        _prepend_path_if_relative "$1" "$2"
    fi
}

_prepend_path_if_relative() {
    case "$2" in
        /* ) printf '%s\n' "$2" ;;
         * ) printf '%s\n' "$1/$2" ;;
    esac
}

_assert_no_path_cycles() {
    local target path

    target=$1
    shift

    for path in "$@"; do
        if [ "$path" = "$target" ]; then
            return 1
        fi
    done
}

canonicalize_path() {
    if [ -d "$1" ]; then
        _canonicalize_dir_path "$1"
    else
        _canonicalize_file_path "$1"
    fi
}

_canonicalize_dir_path() {
    (cd "$1" 2>/dev/null && pwd -P)
}

_canonicalize_file_path() {
    local dir file
    dir=$(dirname -- "$1")
    file=$(basename -- "$1")
    (cd "$dir" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$file")
}
# }}} end of realpath

me=${BASH_SOURCE[0]}
[ -L "$me" ] && me=$(realpath "$me")
here=$(cd "$(dirname "$me")" && pwd)

die() {
    local -i code
    code=$1
    shift
    echo "Error! $*" >&2
    echo
    usage >&2
    # shellcheck disable=SC2086
    exit $code
}

usage() {
    echo "$0 ASCIIDOC_FILE_TO_CONVERT"
}

debug() {
    local -i level
    level=$1
    shift
    if [ -z "$CONFLUENTIAL_DEBUG" ]
    then
        # Print level 0 stuff even when debug isn't set
        # shellcheck disable=SC2086
        if [ $level -eq 0 ]
        then
            echo "$*" >&2
        fi
    else
        # When debug _is_ set, print all debug messages
        echo "$*" >&2
    fi
}

file_to_convert=$1
[ -z "$file_to_convert" ] && die 1 "No file name to convert given"
[ -f "$file_to_convert" ] || die 2 "File ${file_to_convert} does not exist"
bare_file=${file_to_convert%.*}

# If this debug var is set, do not clean up the tmpdir
if [ -z "$CONFLUENTIAL_DEBUG" ]
then
    trap 'rm -rf "$dir" "$outdir"' EXIT
fi

# Temporary directory for storing the pre-converted file
dir=$(mktemp -d)
debug 1 "Using $dir for temporary storage of asciidoc"
cp "$file_to_convert" "$dir"/main.adoc

pushd "$here/asciidoc-confluence-publisher-converter" || die 4 "Could not cd to $here/asciidoc-confluence-publisher-converter"
mvn compile exec:java -e -Dexec.args=\"asciidocRootFolder="$dir"\"
popd || die 5 "Could not return to working directory"
outdir="/tmp/confluence-converts/$(basename "$dir")"
debug 1 "Converted to $outdir"

html=$(ls "$outdir"/assets/*/main.html)
[ -f "$html" ] || die 3 "Cannot find main.html in $outdir. Try running with CONFLUENTIAL_DEBUG and inspect the output directory"

xhtml="${bare_file}.xhtml"
if [ -f "$xhtml" ]
then
    read -r -p "$xhtml already exists. Overwrite? (y/N) " yn
    if [[ "$yn" =~ ^[Yy] ]]
    then
        debug 0 "Overwriting $xhtml"
    else
        debug 0 "Ok, exiting"
    fi
fi

cp "$html" "$xhtml" || die 6 "Unable to cp $html to $xhtml"
debug 0 "Wrote $xhtml"
# vim: set et sw=4 ts=4 sts=4 syntax=sh foldmethod=marker :
