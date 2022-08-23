declare -A _GO_handler
declare -a \
  _GO_parse_hooks \
  _GO_value_name \
  _GO_long \
  _GO_short \
  _GO_long_name \
  _GO_short_name \
  _GO_description

_GO_add_opt() {
  local fn="$1"
  local long_name="$2"
  local short_name="$3"
  local value_name="$4"
  local description="$5"

  if [[ ! -z "${GO_DEBUG:-}" ]]; then
    echo "long: --$long_name"
    echo "short: -$short_name"
    echo "value_name: $value_name"
  fi

  if [[ ! -z "$long_name" ]]; then
    if [[ ! -z "${_GO_handler["--$long_name"]+1}" ]]; then
      echo "ERROR: long opt '--$long_name' already exists"
      exit 2
    fi
    _GO_handler["--$long_name"]="$fn"
  fi
  if [[ ! -z "$short_name" ]]; then
    if [[ ! -z "${_GO_handler["-$short_name"]+1}" ]]; then
      echo "ERROR: short opt '-$short_name' already exists"
      exit 2
    fi
    _GO_handler["-$short_name"]="$fn"
  fi

  _GO_value_name+=("$value_name")
  _GO_long_name+=("$long_name")
  _GO_short_name+=("$short_name")
  _GO_description+=("$description")

  if [[ -z "$value_name" ]]; then
    if [[ ! -z "${GO_DEBUG:-}" ]]; then
      echo "no value"
    fi
    if [[ ! -z "$long_name" ]]; then
      _GO_long+=("$long_name")
    fi
    if [[ ! -z "$short_name" ]]; then
      _GO_short+=("$short_name")
    fi
  else
    if [[ ! -z "${GO_DEBUG:-}" ]]; then
      echo "has value"
    fi
    if [[ ! -z "$long_name" ]]; then
      _GO_long+=("$long_name:")
    fi
    if [[ ! -z "$short_name" ]]; then
      _GO_short+=("$short_name:")
    fi
  fi
  if [[ ! -z "${GO_DEBUG:-}" ]]; then
    echo "====="
  fi
}

GO_add_opt() {
  local fn="$1"
  local long_name="$2"
  local short_name="$3"
  local description="${4:-}"
  _GO_add_opt "$fn" "$long_name" "$short_name" "" "$description"
}

GO_add_opt_with_value() {
  local fn="$1"
  local long_name="$2"
  local short_name="$3"
  local value_name="$4"
  local description="${5:-}"
  _GO_add_opt "$fn" "$long_name" "$short_name" "$value_name" "$description"
}

GO_add_hook() {
  case "$1" in
    parse)
      _GO_parse_hooks+=("$2")
      ;;
    *)
      echo "ERROR: invalid hook: $1"
      exit 2
      ;;
  esac
}

_GO_join_by() {
  local d="${1-}" f="${2-}"
  if shift 2; then
    printf "%s" "$f" "${@/#/$d}"
  fi
}

_GO_handle_opt_help() {
  GO_print_usage
  exit 0
}

GO_print_usage() {
  case "${GO_HELP_STRATEGY:-long}" in
    short)
      GO_print_short_help
      ;;
    long)
      GO_print_long_help
      ;;
    *)
      echo "ERROR: unknown GO_HELP_STRATEGY value: $GO_HELP_STRATEGY"
      ;;
  esac
}

GO_print_short_help() {
  echo "Usage: $0 $(GO_print_help_opts_oneline)"
}

GO_print_long_help() {
  # Only print usage if GO_USAGE is either unset or not empty
  if [[ -z "${GO_USAGE+1}" ]]; then
    echo "Usage: $0"
  elif [[ ! -z "$GO_USAGE" ]]; then
    echo "$GO_USAGE"
  fi

  if [[ ! -z "${GO_HELP_PREAMBLE:-}" ]]; then
    echo "$GO_HELP_PREAMBLE"
  fi

  echo
  echo "Options:"
  GO_print_help_opts_full
}

GO_print_help_opts_full() {
  local lines=()
  for i in "${!_GO_long_name[@]}"; do
    local long="${_GO_long_name[i]}"
    local short="${_GO_short_name[i]}"
    local value="${_GO_value_name[i]}"

    local line="$(
      if [[ ! -z "$long" ]]; then
        echo -n "--$long"
      fi
      if [[ ! -z "$long" && ! -z "$short" ]]; then
        echo -n ", "
      fi
      if [[ ! -z "$short" ]]; then
        echo -n "-$short"
      fi
      if [[ ! -z "$value" ]]; then
        echo -n " $value"
      fi
    )"

    lines+=("$line")
  done

  local max=0
  for line in "${lines[@]}"; do
    local length="${#line}"
    if [[ "$length" -gt "$max" ]]; then
      max="$length"
    fi
  done

  for i in "${!lines[@]}"; do
    local line="${lines[i]}"
    local description="${_GO_description[i]}"
    echo -n "$line"
    if [[ ! -z "$description" ]]; then
      local padding=$(($max - ${#line}))
      printf ' %.0s' $(seq 0 "$padding")
      echo -n "  $description"
    fi
    echo
  done
}

GO_print_help_opts_oneline() {
  for i in "${!_GO_long_name[@]}"; do
    local long="${_GO_long_name[i]}"
    local short="${_GO_short_name[i]}"
    local value="${_GO_value_name[i]}"

    echo -n " ["
    if [[ ! -z "$long" ]]; then
      echo -n "--$long"
    fi
    if [[ ! -z "$long" && ! -z "$short" ]]; then
      echo -n "|"
    fi
    if [[ ! -z "$short" ]]; then
      echo -n "-$short"
    fi
    if [[ ! -z "$value" ]]; then
      echo -n " $value"
    fi
    echo -n "]"
  done
  echo
}

_GO_handle_opt() {
  local opt="$1"; shift
  if [[ -z "${_GO_handler["$opt"]:+1}" ]]; then
    echo "ERROR: no option option handler found for: $opt"
    exit 2
  fi
  local fn="$(echo "${_GO_handler["$opt"]}")"
  "${_GO_handler["$opt"]}" "$opt" "$@"
}

# Source: https://stackoverflow.com/a/70094930/1581233
_GO_run_command() {
  {
    IFS=$'\n' read -r -d '' stderr;
    IFS=$'\n' read -r -d '' stdout;
    (IFS=$'\n' read -r -d '' _ERRNO_; exit ${_ERRNO_});
  } < <((printf '\0%s\0%d\0' "$("$@")" "$?" 1>&2) 2>&1)
}

GO_parse() {
  if ! _GO_run_command getopt \
    -n "$(basename "$0")" \
    -l "$(_GO_join_by ',' "${_GO_long[@]}")" \
    -o "$(_GO_join_by '' "${_GO_short[@]}")" \
    -- "$@"; then
    GO_print_usage
    exit 1
  fi
  eval set -- "$stdout"

  while true; do
    if [[ "$1" == "--" ]]; then
      shift
      break
    fi

    if [[ ! -z "${GO_DEBUG:-}" ]]; then
      echo "Processing option: $1"
      if [[ ! "$1" =~ ^-.* ]]; then
        echo "WARNING: option doesn't start with a dash; check that your option handlers return the correct parameter count"
      fi
    fi

    _GO_handle_opt "$@" || shift "$?"

    if [[ "$#" -le 1 ]]; then
      echo "ERROR: failed to parse options"
      exit 2
    fi
    shift
  done

  for fn in "${_GO_parse_hooks[@]}"; do
    "$fn"
  done
}

if [[ -z "${GO_NO_HELP:-}" ]]; then
  GO_add_opt _GO_handle_opt_help "help" "h" "Displays this message"
fi
