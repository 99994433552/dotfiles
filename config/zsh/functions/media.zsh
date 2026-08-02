# ============================================================================
# Download Functions
# ============================================================================

# YouTube downloader with optimizations
ydl() {
  local output_format="%(title)s.%(ext)s"
  local check_cert=true

  while [[ "$1" == -* ]]; do
    case "$1" in
      -m|--movie)
        output_format="${PWD##*/}.%(ext)s"
        shift ;;
      --no-check)
        check_cert=false
        shift ;;
      *) break ;;
    esac
  done

  local cert_flag=""
  [[ "$check_cert" == false ]] && cert_flag="--no-check-certificate"

  noglob yt-dlp $cert_flag \
    -o "$output_format" \
    -f 'bestvideo[ext=mp4][vcodec^=avc]+bestaudio[ext=m4a]/best[ext=mp4]/best' \
    --merge-output-format mp4 \
    --recode-video mp4 \
    --postprocessor-args 'ffmpeg:-c:v libx264 -preset fast -crf 18 -c:a aac' \
    --concurrent-fragments 16 \
    --downloader aria2c \
    --downloader-args 'aria2c:--min-split-size=1M --max-connection-per-server=16 --max-concurrent-downloads=16 --split=16' \
    "$@"
}

# Download with a custom referer
dlref() {
  local url="$1" referer="${2:-https://lms.skvot.io/}"
  if [[ -z "$url" ]]; then
    echo "Usage: dlref <url> [referer]"
    return 1
  fi
  yt-dlp "$url" --referer "$referer"
}

skvotdl() { dlref "$1" "https://lms.skvot.io/"; }

# Download YouTube channel as MP3
ytmp3() {
  setopt local_options pipe_fail

  local auth_method="file"
  local browser="firefox"
  local cookies_file="cookies.txt"
  local sleep_min=5
  local sleep_max=30
  local sleep_req=2

  # Parse options
  while [[ "$1" == -* ]]; do
    case "$1" in
      -b|--browser)
        auth_method="browser"
        [[ -n "$2" && "$2" != -* ]] && browser="$2" && shift
        shift ;;
      -o|--oauth)
        auth_method="oauth"
        shift ;;
      -f|--file)
        auth_method="file"
        [[ -n "$2" && "$2" != -* ]] && cookies_file="$2" && shift
        shift ;;
      -s|--sleep)
        sleep_min="$2"; shift 2 ;;
      -S|--sleep-max)
        sleep_max="$2"; shift 2 ;;
      -r|--sleep-requests)
        sleep_req="$2"; shift 2 ;;
      -h|--help)
        cat <<EOF
Usage: ytmp3 [OPTIONS] <channel_url>

Auth options:
  -b, --browser [name]  Use cookies from browser (default: firefox)
                        Browsers: firefox, chrome, brave, edge, safari
  -o, --oauth           Use OAuth authentication
  -f, --file [path]     Use cookies file (default: cookies.txt)

Rate limit options:
  -s, --sleep N         Min sleep between videos in seconds (default: 5)
  -S, --sleep-max N     Max sleep between videos in seconds (default: 30)
  -r, --sleep-requests N  Sleep between API requests in seconds (default: 2)

Examples:
  ytmp3 https://www.youtube.com/@channel/videos
  ytmp3 -b chrome https://www.youtube.com/@channel/videos
  ytmp3 -o https://www.youtube.com/@channel/videos
  ytmp3 -s 10 -S 60 https://www.youtube.com/@channel/videos
EOF
        return 0 ;;
      *) echo "Unknown option: $1 (use -h for help)"; return 1 ;;
    esac
  done

  local url="$1"
  if [[ -z "$url" ]]; then
    echo "Usage: ytmp3 [OPTIONS] <channel_url> (use -h for help)"
    return 1
  fi

  # Extract channel name from URL
  local dirname
  dirname=$(_channel_name "$url")

  if [[ -z "$dirname" || "$dirname" == "$url" ]]; then
    echo "Could not extract channel name. Enter directory name:"
    read -r dirname
  fi

  # Build auth argument
  local -a auth_args=()
  _parse_auth "$auth_method" "$browser" "$cookies_file"

  echo "📁 Downloading to: $dirname/"
  echo "🔑 Auth: $auth_method"
  echo "⏱️  Sleep: ${sleep_min}-${sleep_max}s (requests: ${sleep_req}s)"
  mkdir -p "$dirname"

  yt-dlp -x --audio-format mp3 --audio-quality 192K \
    --embed-thumbnail --add-metadata \
    --sleep-interval "$sleep_min" --max-sleep-interval "$sleep_max" \
    --sleep-requests "$sleep_req" \
    "${auth_args[@]}" \
    --download-archive "${dirname}/archive.txt" \
    --downloader aria2c --downloader-args aria2c:"-x 16 -s 16" \
    -o "${dirname}/%(title)s.%(ext)s" \
    "$url"
}
