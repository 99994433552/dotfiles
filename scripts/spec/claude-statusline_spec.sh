# shellcheck shell=bash
# Specs for scripts/claude-statusline.sh — the Claude Code status line renderer.
# Run with: shellspec --shell bash --default-path scripts/spec --helperdir scripts/spec

Describe 'claude-statusline'
  Include scripts/claude-statusline.sh

  BeforeEach 'export NO_COLOR=1'

  Describe '_sl_shorten_path'
    It 'renders the home directory as a bare tilde'
      When call _sl_shorten_path "$HOME"
      The output should equal '~'
    End

    It 'abbreviates the home prefix'
      When call _sl_shorten_path "$HOME/.dotfiles"
      The output should equal '~/.dotfiles'
    End

    It 'keeps up to three components below home'
      When call _sl_shorten_path "$HOME/a/b/c"
      The output should equal '~/a/b/c'
    End

    It 'elides the middle of a deep home path'
      When call _sl_shorten_path "$HOME/a/b/c/d"
      The output should equal '~/…/c/d'
    End

    It 'keeps a short absolute path intact'
      When call _sl_shorten_path '/usr/local/lib'
      The output should equal '/usr/local/lib'
    End

    It 'elides the middle of a deep absolute path'
      When call _sl_shorten_path '/a/b/c/d/e'
      The output should equal '/…/d/e'
    End

    It 'survives an empty input'
      When call _sl_shorten_path ''
      The output should equal ''
    End
  End

  Describe '_sl_bar'
    It 'is empty at zero percent'
      When call _sl_bar 0 8
      The output should equal '░░░░░░░░'
    End

    It 'is full at a hundred percent'
      When call _sl_bar 100 8
      The output should equal '████████'
    End

    It 'is half full at fifty percent'
      When call _sl_bar 50 8
      The output should equal '████░░░░'
    End

    It 'clamps values above a hundred'
      When call _sl_bar 250 8
      The output should equal '████████'
    End

    It 'clamps negative values'
      When call _sl_bar -30 8
      The output should equal '░░░░░░░░'
    End
  End

  Describe '_sl_model_short'
    It 'drops a trailing parenthetical'
      When call _sl_model_short 'Opus 5 (1M context)'
      The output should equal 'Opus 5'
    End

    It 'leaves a plain name alone'
      When call _sl_model_short 'Sonnet 5'
      The output should equal 'Sonnet 5'
    End

    It 'survives an empty input'
      When call _sl_model_short ''
      The output should equal ''
    End
  End

  Describe '_sl_mode_label'
    # Nerd Font glyphs are spelled as UTF-8 byte escapes on purpose: the
    # Private Use Area codepoints do not survive every editor and transport,
    # and bash 3.2 has no $'\uXXXX' support.
    unlock() { printf '\xef\x82\x9c'; }   # U+F09C nf-fa-unlock
    lock() { printf '\xef\x80\xa3'; }     # U+F023 nf-fa-lock

    It 'labels auto mode with an open lock'
      When call _sl_mode_label auto
      The output should equal "$(unlock) auto"
    End

    It 'labels plan mode with a closed lock'
      When call _sl_mode_label plan
      The output should equal "$(lock) plan"
    End

    It 'shortens acceptEdits'
      When call _sl_mode_label acceptEdits
      The output should equal "$(unlock) edits"
    End

    It 'shortens bypassPermissions'
      When call _sl_mode_label bypassPermissions
      The output should equal "$(unlock) bypass"
    End

    It 'emits nothing for the default mode'
      When call _sl_mode_label default
      The output should equal ''
    End

    It 'emits nothing for an unknown mode'
      When call _sl_mode_label ''
      The output should equal ''
    End
  End

  Describe '_sl_git_segment'
    # Each repo gets its own mktemp directory rather than a fixed name under
    # SHELLSPEC_TMPDIR, which is reused across runs. core.hooksPath is pinned
    # away from the developer's global hooks so their output cannot leak into
    # the captured stderr.
    setup_repo() {
      dir=$(mktemp -d)
      {
        git -C "$dir" init --quiet --initial-branch=main
        git -C "$dir" -c core.hooksPath=/dev/null -c user.email=t@t -c user.name=t \
          commit --quiet --allow-empty -m init
        if [ "${1:-}" = 'dirty' ]; then
          printf 'x' >"$dir/tracked.txt"
          git -C "$dir" add tracked.txt
        fi
      } >/dev/null 2>&1
      printf '%s' "$dir"
    }

    It 'is empty outside a repository'
      When call _sl_git_segment /tmp
      The output should equal ''
    End

    It 'is empty for a directory that does not exist'
      When call _sl_git_segment /nonexistent-path-for-spec
      The output should equal ''
    End

    It 'reports the branch of a clean repository'
      repo=$(setup_repo)
      When call _sl_git_segment "$repo"
      The output should include 'main'
      The output should include "$(printf '\xee\x82\xa0')"
      The output should not include '●'
    End

    It 'marks a repository with staged changes'
      repo=$(setup_repo dirty)
      When call _sl_git_segment "$repo"
      The output should include 'main'
      The output should include '●'
    End

    It 'marks a repository with unstaged changes'
      repo=$(setup_repo dirty)
      git -C "$repo" -c core.hooksPath=/dev/null -c user.email=t@t -c user.name=t \
        commit --quiet -m staged >/dev/null 2>&1
      printf 'changed' >"$repo/tracked.txt"
      When call _sl_git_segment "$repo"
      The output should include '●'
    End
  End

  Describe '_sl_humanize'
    Parameters
      0        '0'
      612      '612'
      999      '999'
      1500     '1.5k'
      9949     '9.9k'
      9950     '10k'
      144542   '145k'
      999999   '1M'
      1000000  '1M'
      4630753  '4.6M'
      61000000 '61M'
    End

    It "renders $1 as $2"
      When call _sl_humanize "$1"
      The output should equal "$2"
    End
  End

  Describe '_sl_reset_short'
    Parameters
      '-1'   ''
      0      '0m'
      59     '0m'
      60     '1m'
      2700   '45m'
      3599   '59m'
      3600   '1h'
      9000   '2h'
      86399  '23h'
      86400  '1d'
      299999 '3d'
    End

    It "renders $1 seconds as '$2'"
      When call _sl_reset_short "$1"
      The output should equal "$2"
    End
  End

  Describe '_sl_limit_segment'
    It 'renders label, percentage and time to reset'
      When call _sl_limit_segment '5h' 31 9000
      The output should equal '5h 31% (2h)'
    End

    It 'omits the parenthetical when the reset time is unknown'
      When call _sl_limit_segment '7d' 59 -1
      The output should equal '7d 59%'
    End

    It 'emits nothing without a percentage'
      When call _sl_limit_segment '5h' -1 -1
      The output should equal ''
    End

    It 'emits nothing for a non-numeric percentage'
      When call _sl_limit_segment '5h' 'null' 9000
      The output should equal ''
    End
  End

  Describe '_sl_render'
    fixture_full() {
      cat <<'JSON'
{
  "workspace": { "current_dir": "/tmp", "project_dir": "/tmp" },
  "model": { "id": "claude-opus-5", "display_name": "Opus 5 (1M context)" },
  "permission_mode": "auto",
  "effort": { "level": "high" },
  "context_window": {
    "used_percentage": 17,
    "total_input_tokens": 168391,
    "context_window_size": 1000000
  }
}
JSON
    }

    # resets_at is generated relative to now so the expected "(2h)" and "(3d)"
    # cannot drift. five_hour carries the Unix epoch the payload actually uses;
    # seven_day carries the ISO form the jq pass also accepts, so both are
    # covered.
    fixture_limits() {
      local five seven
      five=$(jq -rn 'now + 9000 | floor')
      seven=$(jq -rn 'now + 300000 | todate')
      jq -n --argjson five "$five" --arg seven "$seven" '{
        workspace: { current_dir: "/tmp" },
        model: { display_name: "Opus 5" },
        context_window: {
          used_percentage: 17,
          total_input_tokens: 168391,
          context_window_size: 1000000
        },
        rate_limits: {
          five_hour: { used_percentage: 31, resets_at: $five },
          seven_day: { used_percentage: 59, resets_at: $seven }
        }
      }'
    }

    fixture_minimal() {
      printf '%s' '{"workspace":{"current_dir":"/tmp"},"model":{"display_name":"Sonnet 5"}}'
    }

    It 'emits a single line'
      When call _sl_render "$(fixture_full)"
      The lines of output should equal 1
    End

    It 'shows location, mode and model'
      When call _sl_render "$(fixture_full)"
      The output should include '/tmp'
      The output should include "$(printf '\xef\x81\xbb')"
      The output should include 'auto'
      The output should include 'Opus 5'
      The output should include 'high'
      The output should not include '1M context'
    End

    It 'shows the context window as used over total'
      When call _sl_render "$(fixture_full)"
      The output should include '168k/1M'
      The output should include "$(printf '\xe2\x96\x88')"
    End

    It 'places the context window ahead of the model'
      When call _sl_render "$(fixture_full)"
      The output should match pattern '*168k/1M*Opus 5*'
    End

    It 'omits the rate limits when the session does not report them'
      When call _sl_render "$(fixture_full)"
      The output should not include '5h'
      The output should not include '7d'
    End

    It 'shows both rate limits with their time to reset'
      When call _sl_render "$(fixture_limits)"
      The output should include '5h 31% (2h)'
      The output should include '7d 59% (3d)'
    End

    It 'places the rate limits between the context window and the model'
      When call _sl_render "$(fixture_limits)"
      The output should match pattern '*168k/1M*5h 31%*7d 59%*Opus 5*'
    End

    It 'still emits a single line with rate limits'
      When call _sl_render "$(fixture_limits)"
      The lines of output should equal 1
    End

    It 'omits the context segment when the session does not report it'
      When call _sl_render "$(fixture_minimal)"
      The output should include 'Sonnet 5'
      The output should not include '/1M'
      The output should not include "$(printf '\xe2\x96\x88')"
    End

    It 'survives malformed json without failing'
      When call _sl_render 'not json at all'
      The status should equal 0
    End
  End
End
