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

# Video/Audio cutter
vidcut() {
  setopt local_options pipe_fail

  local url="" start_time="" end_time=""
  local output_name="output"
  local format="mp4"
  local auth_method="" browser="firefox" cookies_file=""

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -u|--url) url="$2"; shift ;;
      -s|--start) start_time="$2"; shift ;;
      -e|--end) end_time="$2"; shift ;;
      -o|--output) output_name="$2"; shift ;;
      -f|--format) format="$2"; shift ;;
      -b|--browser)
        auth_method="browser"
        [[ -n "$2" && "$2" != -* ]] && browser="$2" && shift
        ;;
      --cookies) auth_method="file"; cookies_file="$2"; shift ;;
      -h|--help)
        cat <<EOF
Usage: vidcut -u <URL> -s <START_TIME> -e <END_TIME> [OPTIONS]
Options:
  -o, --output          Output filename (default: output)
  -f, --format          Output format: mp3, mp4 (default: mp4)
  -b, --browser [name]  Use cookies from browser (default: firefox)
                        Browsers: firefox, chrome, brave, edge, safari
      --cookies <path>  Use cookies file
  -h, --help            Show this help message

Examples:
  vidcut -u <URL> -s 1:51 -e 2:37
  vidcut -u <URL> -s 1:51 -e 2:37 -b
  vidcut -u <URL> -s 1:51 -e 2:37 -b chrome
  vidcut -u <URL> -s 1:51 -e 2:37 --cookies ~/cookies.txt
EOF
        return 0 ;;
      *) echo "Unknown parameter: $1 (use -h for help)"; return 1 ;;
    esac
    shift
  done

  if [[ -z "$url" || -z "$start_time" || -z "$end_time" ]]; then
    echo "🚨 Error: Required arguments missing! Use -h for help"
    return 1
  fi

  local format_desc
  local -a yt_args
  case "$format" in
    mp3)
      format_desc="🎵 audio"
      yt_args=(-f 'bestaudio/best' --extract-audio --audio-format mp3 --audio-quality 2)
      ;;
    mp4)
      format_desc="🎬 video"
      # iOS Photos requires H.264 + AAC in mp4 with faststart.
      # --download-sections invokes FFmpegFD, not a post-processor, so
      # faststart goes via --downloader-args, not --postprocessor-args.
      yt_args=(
        -f 'bv*[vcodec^=avc1]+ba[ext=m4a]/b[vcodec^=avc1][ext=mp4]/b[ext=mp4]'
        --merge-output-format mp4
        --downloader-args 'ffmpeg:-movflags +faststart'
      )
      ;;
    *)
      echo "❌ Unsupported format: $format (use mp3 or mp4)"
      return 1 ;;
  esac

  local -a auth_args=()
  _parse_auth "$auth_method" "$browser" "$cookies_file"

  echo "Cutting ${format_desc} to ${output_name}.${format}..."
  yt-dlp --download-sections "*${start_time}-${end_time}" \
    "${yt_args[@]}" \
    "${auth_args[@]}" \
    --force-overwrite \
    -o "${output_name}.%(ext)s" \
    "$url"
  echo "✅ Done!"
}

# Cut and crop YouTube video for Instagram Stories (9:16)
storycut() {
  setopt local_options pipe_fail

  local url="" start_time="" end_time=""
  local output_name=""
  local crop_pos="center"
  local auth_method="" browser="firefox" cookies_file=""

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -u|--url) url="$2"; shift ;;
      -s|--start) start_time="$2"; shift ;;
      -e|--end) end_time="$2"; shift ;;
      -o|--output) output_name="$2"; shift ;;
      -c|--crop) crop_pos="$2"; shift ;;
      -b|--browser)
        auth_method="browser"
        [[ -n "$2" && "$2" != -* ]] && browser="$2" && shift
        ;;
      --cookies) auth_method="file"; cookies_file="$2"; shift ;;
      -h|--help)
        cat <<EOF
Usage: storycut -u <URL> -s <START_TIME> -e <END_TIME> [OPTIONS]
Options:
  -c, --crop            Crop position: left, center, right, 0-100, or blur (default: center)
  -o, --output          Output filename (default: video title)
  -b, --browser [name]  Use cookies from browser (default: firefox)
                        Browsers: firefox, chrome, brave, edge, safari
      --cookies <path>  Use cookies file
  -h, --help            Show this help message

Examples:
  storycut -u <URL> -s 0:10 -e 0:25
  storycut -u <URL> -s 0:10 -e 0:25 -b
  storycut -u <URL> -s 0:10 -e 0:25 -b chrome -c blur
  storycut -u <URL> -s 0:10 -e 0:25 --cookies ~/cookies.txt
EOF
        return 0 ;;
      *) echo "Unknown parameter: $1 (use -h for help)"; return 1 ;;
    esac
    shift
  done

  if [[ -z "$url" || -z "$start_time" || -z "$end_time" ]]; then
    echo "🚨 Error: Required arguments missing! Use -h for help"
    return 1
  fi

  # Build video filter
  local vf
  if [[ "$crop_pos" == "blur" ]]; then
    vf="split[bg][fg];[bg]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,boxblur=20:5[bg];[fg]scale=1080:1920:force_original_aspect_ratio=decrease[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2"
  else
    local crop_x
    if ! crop_x=$(_crop_x "$crop_pos"); then
      echo "❌ Invalid crop position: $crop_pos (use left, center, right, blur, or 0-100)"
      return 1
    fi
    vf="crop=ih*9/16:ih:${crop_x}:0,scale=1080:1920"
  fi

  local -a auth_args=()
  _parse_auth "$auth_method" "$browser" "$cookies_file"

  echo "Fetching stream URLs..."
  local video_url audio_url
  video_url=$(yt-dlp "${auth_args[@]}" -f 'bestvideo[ext=mp4]/bestvideo' --get-url "$url")
  audio_url=$(yt-dlp "${auth_args[@]}" -f 'bestaudio[ext=m4a]/bestaudio' --get-url "$url")

  if [[ -z "$output_name" ]]; then
    output_name=$(yt-dlp "${auth_args[@]}" --get-title "$url" | sed 's/[\/\\:*?"<>|]/_/g')
  fi

  echo "🎬 Cutting to 9:16 (mode: ${crop_pos})..."
  if [[ "$crop_pos" == "blur" ]]; then
    ffmpeg -ss "$start_time" -to "$end_time" -i "$video_url" \
           -ss "$start_time" -to "$end_time" -i "$audio_url" \
           -filter_complex "[0:v]${vf}[out]" \
           -map "[out]" -map 1:a \
           -c:v libx264 -preset fast -crf 18 \
           -c:a aac -b:a 192k \
           "${output_name}.mp4" -y
  else
    ffmpeg -ss "$start_time" -to "$end_time" -i "$video_url" \
           -ss "$start_time" -to "$end_time" -i "$audio_url" \
           -map 0:v -map 1:a \
           -vf "$vf" \
           -c:v libx264 -preset fast -crf 18 \
           -c:a aac -b:a 192k \
           "${output_name}.mp4" -y
  fi
  echo "✅ Done: ${output_name}.mp4"
}

# Create Telegram sticker from video
makesticker() {
  setopt local_options pipe_fail

  local input="$1"
  local max_duration=3
  local max_size_kb=256

  if [[ -z "$input" || ! -f "$input" ]]; then
    echo "Usage: makesticker <input_file>"
    return 1
  fi

  local output="${input%.*}_sticker.webm"
  local passlog="${input%.*}_passlog"

  # Get input duration
  local input_duration
  input_duration=$(ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$input" 2>/dev/null)

  if [[ -z "$input_duration" ]]; then
    echo "❌ Failed to get duration from: $input"
    return 1
  fi

  # Calculate actual duration (min of input and max allowed)
  local duration
  duration=$(_duration_min "$input_duration" "$max_duration")

  # Calculate target bitrate: (max_size_kb * 8 * 0.95) / duration kbit/s
  local bitrate
  bitrate=$(_sticker_bitrate "$max_size_kb" "$duration")

  echo "Input duration: ${input_duration}s"
  echo "Output duration: ${duration}s"
  echo "Target bitrate: ${bitrate}k"
  echo ""

  local vf="scale=if(gte(iw\,ih)\,512\,-1):if(gte(ih\,iw)\,512\,-1)"

  # Pass 1: analysis
  echo "=== Pass 1/2: Analyzing ==="
  ffmpeg -y -i "$input" -t "$duration" -r 30 -c:v libvpx-vp9 -an \
    -vf "$vf" -b:v "${bitrate}k" -maxrate "${bitrate}k" -bufsize "${bitrate}k" \
    -pass 1 -passlogfile "$passlog" -f null /dev/null

  if [[ $? -ne 0 ]]; then
    echo "❌ Pass 1 failed"
    rm -f "${passlog}"*.log
    return 1
  fi

  # Pass 2: encoding
  echo ""
  echo "=== Pass 2/2: Encoding ==="
  ffmpeg -y -i "$input" -t "$duration" -r 30 -c:v libvpx-vp9 -an \
    -vf "$vf" -b:v "${bitrate}k" -maxrate "${bitrate}k" -bufsize "${bitrate}k" \
    -pass 2 -passlogfile "$passlog" "$output"

  local result=$?

  # Cleanup passlog files
  rm -f "${passlog}"*.log

  if [[ $result -eq 0 ]]; then
    local size_kb
    size_kb=$(du -k "$output" | cut -f1)
    echo ""
    echo "✅ Created: $output (${size_kb}KB)"
  else
    echo "❌ Failed to create sticker"
    return 1
  fi
}
