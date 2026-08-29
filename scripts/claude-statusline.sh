#!/bin/bash
#
# Claude Code status line.
#
# Claude Code pipes a JSON snapshot of the session on stdin and renders
# whatever this script writes to stdout. It re-runs on every session change,
# debounced to roughly 300ms, so the process count matters: one jq pass for the
# whole payload and at most three git invocations.
#
#  ~/.dotfiles   main ●   auto  ▐██░░░░░░░░ 168k/1M   Opus 5 · high
#
# The context window sits ahead of the model because a single-line status line
# is truncated from the right, and the model is the part worth losing first.
#
# Targets bash 3.2, the /bin/bash that ships with macOS and the interpreter
# named in settings.json. No associative arrays, no ${var^^}, no $'\uXXXX'.

# --------------------------------------------------------------------------
# Glyphs
# --------------------------------------------------------------------------
# Nerd Font icons are spelled as UTF-8 byte escapes rather than as literal
# characters. Their Private Use Area codepoints do not survive every editor,
# clipboard and transport intact, and bash 3.2 predates $'\uXXXX'.
SL_ICON_DIR=$'\xef\x81\xbb'      # U+F07B  nf-fa-folder
SL_ICON_BRANCH=$'\xee\x82\xa0'   # U+E0A0  nf-pl-branch
SL_ICON_LOCK=$'\xef\x80\xa3'     # U+F023  nf-fa-lock
SL_ICON_UNLOCK=$'\xef\x82\x9c'   # U+F09C  nf-fa-unlock
SL_ICON_MODEL=$'\xef\x83\xa7'    # U+F0E7  nf-fa-bolt
SL_GLYPH_DIRTY=$'\xe2\x97\x8f'   # U+25CF  black circle
SL_BAR_FULL=$'\xe2\x96\x88'      # U+2588  full block
SL_BAR_EMPTY=$'\xe2\x96\x91'     # U+2591  light shade
SL_BAR_CAP=$'\xe2\x96\x90'       # U+2590  right half block
SL_ELLIPSIS=$'\xe2\x80\xa6'      # U+2026  horizontal ellipsis
SL_GLYPH_DOT=$'\xc2\xb7'      # U+00B7  middle dot

SL_BAR_WIDTH=10

# The jq pass below joins its fields on this byte. It has to be something that
# is not whitespace: `read` collapses runs of whitespace delimiters and drops
# leading ones, which silently shifts every value left as soon as one field
# comes back empty.
SL_FS=$'\x1f'                    # U+001F  unit separator

# --------------------------------------------------------------------------
# Colors
# --------------------------------------------------------------------------
# Resolved on every render rather than once at load, so that NO_COLOR set
# after this file is sourced still takes effect (the specs rely on it).
_sl_init_colors() {
  if [ -n "${NO_COLOR:-}" ]; then
    SL_RESET='' SL_DIM='' SL_CYAN='' SL_GREEN='' SL_YELLOW='' SL_RED='' SL_PURPLE='' SL_BLUE=''
  else
    SL_RESET=$'\033[0m'
    SL_DIM=$'\033[2m'
    SL_CYAN=$'\033[36m'
    SL_GREEN=$'\033[32m'
    SL_YELLOW=$'\033[33m'
    SL_RED=$'\033[31m'
    SL_PURPLE=$'\033[35m'
    SL_BLUE=$'\033[34m'
  fi
}

# True only for a string of plain digits, which conveniently rejects the -1
# that the jq pass emits for a field the session did not report.
_sl_is_num() {
  case "$1" in
    '' | *[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

_sl_pct_color() {
  _sl_init_colors
  if [ "$1" -ge 75 ]; then
    printf '%s' "$SL_RED"
  elif [ "$1" -ge 50 ]; then
    printf '%s' "$SL_YELLOW"
  else
    printf '%s' "$SL_GREEN"
  fi
}

# --------------------------------------------------------------------------
# Formatting primitives
# --------------------------------------------------------------------------

# Collapse the home prefix to ~ and elide the middle of anything deeper than
# three components, so a long path cannot push the rest of the line off screen.
_sl_shorten_path() {
  local dir="$1" lead rest tmp n head2

  if [ "$dir" = "$HOME" ]; then
    printf '~'
    return 0
  fi

  case "$dir" in
    "$HOME"/*) lead='~' rest="${dir#"$HOME"/}" ;;
    /*) lead='' rest="${dir#/}" ;;
    *) printf '%s' "$dir"; return 0 ;;
  esac

  tmp="$rest"
  n=1
  while [ "$tmp" != "${tmp#*/}" ]; do
    tmp="${tmp#*/}"
    n=$((n + 1))
  done

  if [ "$n" -le 3 ]; then
    printf '%s/%s' "$lead" "$rest"
  else
    head2="${rest%/*}"
    printf '%s/%s/%s/%s' "$lead" "$SL_ELLIPSIS" "${head2##*/}" "${rest##*/}"
  fi
}

_sl_bar() {
  local pct="$1" width="${2:-$SL_BAR_WIDTH}" filled i=0 out=''

  [ "$pct" -lt 0 ] && pct=0
  [ "$pct" -gt 100 ] && pct=100
  filled=$(((pct * width + 50) / 100))

  while [ "$i" -lt "$width" ]; do
    if [ "$i" -lt "$filled" ]; then
      out="$out$SL_BAR_FULL"
    else
      out="$out$SL_BAR_EMPTY"
    fi
    i=$((i + 1))
  done

  printf '%s' "$out"
}

# Round a token count down to something that fits: 612, 1.5k, 145k, 4.6M, 61M.
# A whole number of thousands or millions loses the ".0", so a 1000000 token
# window reads as 1M rather than 1.0M. All arithmetic is integer, because bash
# 3.2 has no floats.
_sl_humanize() {
  local n="$1" tenths whole frac unit

  if [ "$n" -lt 1000 ]; then
    printf '%d' "$n"
    return 0
  elif [ "$n" -lt 9950 ]; then
    tenths=$(((n + 50) / 100))
    unit='k'
  elif [ "$n" -lt 999500 ]; then
    printf '%dk' $(((n + 500) / 1000))
    return 0
  elif [ "$n" -lt 9950000 ]; then
    tenths=$(((n + 50000) / 100000))
    unit='M'
  else
    printf '%dM' $(((n + 500000) / 1000000))
    return 0
  fi

  whole=$((tenths / 10))
  frac=$((tenths % 10))
  if [ "$frac" -eq 0 ]; then
    printf '%d%s' "$whole" "$unit"
  else
    printf '%d.%d%s' "$whole" "$frac" "$unit"
  fi
}

# Seconds until a rate limit resets, rounded down to one coarse unit: 45m, 2h,
# 3d. Rounding down keeps the figure a promise the window can keep — "2h" means
# at least two hours are left, never one and a half dressed up as two. A -1
# stands for a reset time the session did not report, and renders as nothing.
_sl_reset_short() {
  local s="$1"

  _sl_is_num "$s" || return 0

  if [ "$s" -lt 3600 ]; then
    printf '%dm' $((s / 60))
  elif [ "$s" -lt 86400 ]; then
    printf '%dh' $((s / 3600))
  else
    printf '%dd' $((s / 86400))
  fi
}

# "Opus 5 (1M context)" is too wide for a status line; the parenthetical is
# the part that carries no decision-relevant information.
_sl_model_short() {
  printf '%s' "${1%% (*}"
}

_sl_mode_label() {
  _sl_init_colors
  case "$1" in
    auto) printf '%s%s auto%s' "$SL_DIM" "$SL_ICON_UNLOCK" "$SL_RESET" ;;
    plan) printf '%s%s plan%s' "$SL_BLUE" "$SL_ICON_LOCK" "$SL_RESET" ;;
    acceptEdits) printf '%s%s edits%s' "$SL_YELLOW" "$SL_ICON_UNLOCK" "$SL_RESET" ;;
    bypassPermissions) printf '%s%s bypass%s' "$SL_RED" "$SL_ICON_UNLOCK" "$SL_RESET" ;;
    *) : ;;
  esac
}

# One plan rate limit: "5h 31% (2h)". Shares the thresholds of the context bar,
# so a number that is worth worrying about looks the same wherever it appears.
_sl_limit_segment() {
  _sl_init_colors
  local label="$1" pct="$2" secs="$3" shade left

  _sl_is_num "$pct" || return 0

  shade=$(_sl_pct_color "$pct")
  printf '%s%s %d%%%s' "$shade" "$label" "$pct" "$SL_RESET"

  left=$(_sl_reset_short "$secs")
  [ -n "$left" ] && printf '%s (%s)%s' "$SL_DIM" "$left" "$SL_RESET"

  return 0
}

_sl_git_segment() {
  _sl_init_colors
  local dir="$1" branch

  [ -d "$dir" ] || return 0

  branch=$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null) ||
    branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null) ||
    return 0
  [ -n "$branch" ] || return 0

  if ! git -C "$dir" diff --quiet 2>/dev/null ||
    ! git -C "$dir" diff --cached --quiet 2>/dev/null; then
    printf '%s%s %s %s%s' "$SL_RED" "$SL_ICON_BRANCH" "$branch" "$SL_GLYPH_DIRTY" "$SL_RESET"
  else
    printf '%s%s %s%s' "$SL_PURPLE" "$SL_ICON_BRANCH" "$branch" "$SL_RESET"
  fi
}

# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------

_sl_render() {
  _sl_init_colors

  local json="$1" fields line segment shade
  local cwd pct used total mode model effort
  local pct5h secs5h pct7d secs7d five seven

  # context_window.used_percentage is authoritative for the bar. Claude Code
  # computes it as round(total_input_tokens / context_window_size * 100), so
  # the bar and the numbers beside it cannot disagree.
  fields=$(printf '%s' "$json" | jq -r --arg fs "$SL_FS" '
    def num(v): if v == null then -1 else (v | round) end;

    # resets_at is a Unix epoch in the payloads this was checked against
    # (Claude Code 2.1.236). An ISO 8601 string is accepted too, since a build
    # that spells it 2026-08-27T15:00:00.902275+00:00 would otherwise drop the
    # field silently. fromdateiso8601 refuses that form -- it takes whole
    # seconds and a literal Z -- hence the capture, which drops the fractional
    # part and folds the offset back in by hand. Doing it here rather than in
    # bash keeps the render to one jq call and sidesteps BSD date, which cannot
    # parse it either.
    def epoch(s):
      (s | capture("^(?<t>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(?:\\.[0-9]+)?(?<z>Z|(?<sg>[+-])(?<oh>[0-9]{2}):(?<om>[0-9]{2}))$"))
      | ((.t + "Z") | fromdateiso8601)
        - (if .z == "Z" then 0
           else ((.oh | tonumber) * 3600 + (.om | tonumber) * 60) * (if .sg == "-" then -1 else 1 end)
           end);

    # The array is what makes this safe. A capture that matches nothing yields an
    # empty stream, not an error, so an unrecognized timestamp would silently
    # drop a field and shift every later one left past the read below.
    def secs(v):
      [ v | (numbers, (strings | try epoch(.) catch empty)) ]
      | if length == 0 then -1
        else ((.[0] - now) | if . < 0 then 0 else floor end)
        end;

    [ (.workspace.current_dir // .cwd // ""),
      num(.context_window.used_percentage),
      num(.context_window.total_input_tokens),
      num(.context_window.context_window_size),
      (.permission_mode // ""),
      (.model.display_name // ""),
      (.effort.level // ""),
      num(.rate_limits.five_hour.used_percentage),
      secs(.rate_limits.five_hour.resets_at),
      num(.rate_limits.seven_day.used_percentage),
      secs(.rate_limits.seven_day.resets_at)
    ] | map(tostring) | join($fs)' 2>/dev/null) || return 0
  [ -n "$fields" ] || return 0

  IFS="$SL_FS" read -r cwd pct used total mode model effort \
    pct5h secs5h pct7d secs7d <<<"$fields"

  line="${SL_CYAN}${SL_ICON_DIR} $(_sl_shorten_path "$cwd")${SL_RESET}"

  segment=$(_sl_git_segment "$cwd")
  [ -n "$segment" ] && line="$line  $segment"

  segment=$(_sl_mode_label "$mode")
  [ -n "$segment" ] && line="$line  $segment"

  if _sl_is_num "$used" && _sl_is_num "$total" && [ "$total" -gt 0 ]; then
    _sl_is_num "$pct" || pct=$((used * 100 / total))
    shade=$(_sl_pct_color "$pct")
    line="$line  ${SL_DIM}${SL_BAR_CAP}${SL_RESET}${shade}$(_sl_bar "$pct")${SL_RESET}"
    line="$line ${shade}$(_sl_humanize "$used")/$(_sl_humanize "$total")${SL_RESET}"
  fi

  # Plan limits sit after the context window: both answer "how much room is
  # left", and the session limit is the one that ends the day early.
  five=$(_sl_limit_segment '5h' "$pct5h" "$secs5h")
  seven=$(_sl_limit_segment '7d' "$pct7d" "$secs7d")
  if [ -n "$five" ] && [ -n "$seven" ]; then
    line="$line  $five ${SL_DIM}${SL_GLYPH_DOT}${SL_RESET} $seven"
  elif [ -n "$five$seven" ]; then
    line="$line  $five$seven"
  fi

  if [ -n "$model" ]; then
    segment="${SL_ICON_MODEL} $(_sl_model_short "$model")"
    [ -n "$effort" ] && segment="$segment · $effort"
    line="$line  ${SL_DIM}${segment}${SL_RESET}"
  fi

  printf '%s' "$line"
}

_sl_main() {
  _sl_render "$(cat)"
}

# shellspec sources this file to test the functions above; skip the entry point.
${__SOURCED__:+return}

_sl_main "$@"
