# Create and change directory
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# Prefix filenames with directory name: dirname_filename.ext
prefix_dirname() {
  local dirname="${PWD##*/}"
  local files=()
  local skipped=0

  # Collect regular files (no hidden, must have extension)
  for file in *(N.); do
    if [[ "$file" != "${file%.*}" ]]; then
      files+=("$file")
    else
      ((skipped++))
    fi
  done

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "🚫 No files to rename"
    [[ $skipped -gt 0 ]] && echo "⏭️  Skipped $skipped files without extension"
    return 1
  fi

  # Preview first 3 files
  echo "📁 Directory: $dirname"
  echo "📝 Preview (first 3):"
  local -a previews=()
  for file in "${files[@]}"; do
    previews+=("$file → ${dirname}_${file%.*}.${file##*.}")
  done
  _preview 3 "${previews[@]}"
  [[ $skipped -gt 0 ]] && echo "⏭️  Skipping $skipped files without extension"

  if ! _confirm "Continue?"; then
    echo "❌ Cancelled"
    return 0
  fi

  # Rename files
  local count=0
  for file in "${files[@]}"; do
    local base="${file%.*}"
    local ext="${file##*.}"
    local newname="${dirname}_${base}.${ext}"
    mv -- "$file" "$newname" && ((count++))
  done

  echo "✅ Renamed $count files"
}

# Unlock directory with confirmation
unlockdir() {
  setopt local_options no_unset pipe_fail
  local target_dir="${1:-.}"

  if [[ ! -d "$target_dir" ]]; then
    echo "❌ Directory not found: $target_dir"
    return 1
  fi

  local real_path=$(realpath "$target_dir")
  echo "⚠️  About to unlock: $real_path"

  if _confirm "Continue?"; then
    echo "🔓 Unlocking..."
    chflags -R nouchg "$target_dir" && chmod -R u+w "$target_dir"
    echo "✅ Done!"
  else
    echo "❌ Cancelled"
  fi
}

# Clean music junk files (metadata, playlists, system files)
cleanmusic() {
  local extensions=(
    # Playlists & metadata
    "*.cue" "*.m3u8" "*.m3u" "*.log" "*.nfo"
    "*.sfv" "*.ffp" "*.md5" "*.accurip"
    # Web & torrent
    "*.url" "*.torrent"
    # Windows
    "Thumbs.db" "desktop.ini" "*.db"
    # macOS
    ".DS_Store" "._*"
  )
  local files=()

  # Collect all matching files
  for ext in "${extensions[@]}"; do
    while IFS= read -r -d '' file; do
      files+=("$file")
    done < <(find . -name "$ext" -print0 2>/dev/null)
  done

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "🚫 No files to delete"
    return 0
  fi

  # Show preview
  echo "📝 Files to delete (${#files[@]} total):"
  _preview 10 "${files[@]}"

  if ! _confirm "Delete all?"; then
    echo "❌ Cancelled"
    return 0
  fi

  # Delete files
  local count=0
  for ext in "${extensions[@]}"; do
    local deleted
    deleted=$(find . -name "$ext" -delete -print 2>/dev/null | wc -l)
    count=$((count + deleted))
  done

  echo "✅ Deleted $count files"
}
