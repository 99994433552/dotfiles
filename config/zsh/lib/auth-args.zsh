# _parse_auth <method> <browser> <cookies_file>
# Populates the caller-local array `auth_args` with yt-dlp auth flags.
# Relies on zsh dynamic scope: caller must `local -a auth_args` first.
_parse_auth() {
  local method="$1" browser="$2" cookies_file="$3"
  case "$method" in
    browser) auth_args=(--cookies-from-browser "$browser") ;;
    file)    auth_args=(--cookies "$cookies_file") ;;
    oauth)   auth_args=(--username oauth --password '') ;;
  esac
}
