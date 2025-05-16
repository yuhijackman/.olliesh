# Function to add an alias to the Oh My Zsh custom aliases file and reload the configuration
add_alias() {
  # Check if exactly 2 arguments are provided
  if [ "$#" -ne 2 ]; then
    echo "Usage: add_alias <alias_name> '<command_to_execute>'" >&2
    echo "Example: add_alias gs 'git status -sb'" >&2
    return 1 # Exit with error
  fi

  local alias_name="$1"
  local command_to_alias="$2"
  # <<< Change: Set the target file to Oh My Zsh's custom aliases file >>>
  local custom_aliases_file="$HOME/.oh-my-zsh/custom/aliases.zsh"
  local alias_entry="alias ${alias_name}='${command_to_alias}'"

  # Create the custom aliases file if it doesn't exist (as a precaution)
  mkdir -p "$(dirname "$custom_aliases_file")" && touch "$custom_aliases_file"

  # Simple check if the alias already exists (optional)
  if grep -q "alias ${alias_name}=" "$custom_aliases_file"; then
    echo "🤔 Alias '${alias_name}' seems to already exist in ${custom_aliases_file}." >&2
    # return 1 # If you want to exit without adding if it exists
  fi

  # Append to the custom aliases file
  echo "\n# Alias added by add_alias function on $(date)" >> "$custom_aliases_file"
  echo "$alias_entry" >> "$custom_aliases_file"

  # <<< Note: Sourcing ~/.zshrc is still the reliable way for immediate reflection >>>
  # Oh My Zsh loads custom files on startup, but to reflect immediately
  # in the current session, reloading the entire configuration is the quickest way.
  source "$HOME/.zshrc"

  # Completion message
  echo "✅ Alias '${alias_name}' added to ${custom_aliases_file} and configuration reloaded."
  echo "     You can use '${alias_name}' right away!"
}

ghq_cd() {
  local repos=$(ghq list --full-path)
  local selected_repo

  if [[ -z "$repos" ]]; then
    echo "No repositories managed by ghq."
    return 1
  fi

  selected_repo=$(echo "$repos" | awk -F '/' '{print $(NF-1)"/"$(NF)}' |
                    fzf --height $(( $(echo "$repos" | wc -l) + 2 )) --reverse --prompt='Jump to: ' --select-1 --exit-0)

  if [[ -n "$selected_repo" ]]; then
    local full_path=$(ghq list --full-path | grep "$(echo "$selected_repo" | sed 's@/@/@g')")
    if [[ -n "$full_path" ]]; then
      cd "${full_path%$'\n'}"
    fi
  fi
}

# --- Pomodoro Timer with Enhancements ---
 Required:
# - timer: https://github.com/caarlos0/timer
# - terminal-notifier: https://github.com/julienXX/terminal-notifier (for macOS notifications)

# Helper function for sending notifications
_send_notification() {
    local message="$1"
    local title="$2"
    local appIcon="$3"
    local sound="$4"
    # Check if terminal-notifier is available
    if command -v terminal-notifier &> /dev/null; then
        terminal-notifier -message "$message" -title "$title" -appIcon "$appIcon" -sound "$sound"
    else
        # Fallback: print to terminal if terminal-notifier is not found
        echo "\nNotification: ${title} - ${message}"
    fi
}

# _display_tree function removed
# Set counting file/logic removed

# Function for the Work timer
# Usage: _pomo_work [minutes]
_pomo_work() {
    # Default work duration is 60 minutes
    local duration_min=${1:-60}

    # Calculate half duration for the stand-up alert
    local half_duration_min=$(( duration_min / 2 ))
    local remaining_duration_min=$(( duration_min - half_duration_min ))

    # Removed set count display
    echo "---🦦 Pomodoro Work: ${duration_min} min 🦦---"

    if timer "${half_duration_min}m"; then
        # First half finished successfully, send stand-up alert
        _send_notification "Time to stand up and move around🧍 A quick stretch is also effective 🤹🏼‍♂️" "Stand Up Alert" "$HOME/Pictures/pumpkin.png" "Glass" # You can change sound
        echo "Time to stand up🧍"

        if timer "${remaining_duration_min}m"; then
            # Second half finished successfully, send work end alert
            _send_notification "Break time🧋 Relax and take a breather ☕" "Work Session Ended!" "$HOME/Pictures/pumpkin.png" "Crystal" # You can change sound
            echo "Work session finished🧋 Take a break🍪"
            return 0 # Indicate success
        else
            # Second half was cancelled
            echo "Work timer (2nd half) cancelled."
            return 1 # Indicate failure
        fi
    else
        # First half was cancelled
        echo "Work timer (1st half) cancelled."
        return 1 # Indicate failure
    fi
}

# Function for the Rest timer
# Usage: _pomo_rest [minutes]
_pomo_rest() {
    # Default rest duration is 10 minutes
    local duration_min=${1:-10}

    echo "--- Pomodoro Break: ${duration_min} min ---"

    # Start the rest timer
    if timer "${duration_min}m"; then
        # Timer finished successfully, send rest end alert
        _send_notification "Time to get back to work 💂‍♀️" "Break Ended!" "$HOME/Pictures/pumpkin.png" "Crystal" # You can change sound
        echo "Break finished. Back to work💂‍♀️"
        return 0 # Indicate success
    else
        # Timer was cancelled
        echo "Break timer cancelled."
        return 1 # Indicate failure
    fi
}

# Wrapper function to run a full Work + Rest cycle
# Usage: pomo [work_minutes] [rest_minutes]
pomo_set() {
    # Display help message if --help is the first argument
    if [[ "$1" == "--help" ]]; then
        echo "Usage: pomo [work_minutes] [rest_minutes]"
        echo ""
        echo "Starts a Pomodoro work/break cycle."
        echo ""
        echo "Arguments:"
        echo "  work_minutes  Optional. Duration of the work session in minutes."
        echo "                Defaults to 60 minutes."
        echo "  rest_minutes  Optional. Duration of the break session in minutes."
        echo "                Defaults to 10 minutes."
        echo ""
        echo "Example:"
        echo "  pomo         # Start 60 min work, 10 min break"
        echo "  pomo 45      # Start 45 min work, 10 min break"
        echo "  pomo 50 5    # Start 50 min work, 5 min break"
        echo "  pomo --help  # Display this help message"
        return 0 # Exit the function after showing help
    fi

    # Default durations
    local work_duration_min=${1:-60}
    local rest_duration_min=${2:-10}

    # Removed set count file/logic

    # Run the Work timer
    # Removed passing set count argument
    if _pomo_work "$work_duration_min"; then
        # Work was completed successfully, now run the Rest timer
        if _pomo_rest "$rest_duration_min"; then
            # Both Work and Rest completed successfully
            echo "\n--- Pomodoro Cycle Completed🥳 ---" # Generic completion message
        else
            # Rest was cancelled
            echo "\n--- Pomodoro Cycle Incomplete (Break cancelled). ---"
        fi
    else
        # Work was cancelled
        echo "\n--- Pomodoro Cycle Incomplete (Work cancelled). ---"
    fi
}
# --- End of Pomodoro Timer ---
