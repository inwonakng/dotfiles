#!/bin/bash
# script for controlling what is rendered in the status bar
WINDOW_WIDTH=$(tmux display-message -p '#{window_width}')

# --- Helper function to get tmux options ---
# This lets us query the Catppuccin theme variables from within the script.
get_tmux_option() {
    local option="$1"
    local default_value="$2"
    local value=$(tmux show-option -gqv "$option")
    if [ -z "$value" ]; then
        echo "$default_value"
    else
        echo "$value"
    fi
}

# --- OS-Specific Stats Functions ---
get_cpu_usage() {
    # The case statement allows for easy expansion to other OSes in the future
    case $(uname -s) in
    Linux)
        # Get idle CPU time from top, then subtract from 100
        local cpu_idle=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/")
        echo "$cpu_idle" | awk '{printf "%.0f%%", 100 - $1}' 2>/dev/null || echo "0%"
        ;;
    Darwin) # This is macOS
        # Get CPU idle percentage from top, then subtract from 100
        # -l 1 runs top for 1 sample.
        local cpu_idle=$(top -l 1 | grep "CPU usage" | awk '{print $7}' | cut -d'%' -f1)
        echo "$cpu_idle" | awk '{printf "%.0f%%", 100 - $1}' 2>/dev/null || echo "0%"
        ;;
    *)
        echo "N/A" # Default for unknown OS
        ;;
    esac
}

get_ram_usage() {
    case $(uname -s) in
    Linux)
        # The 'free' command is standard on Linux.
        free -m | awk '/^Mem:/ {printf("%.0f%%", $3/$2 * 100)}' 2>/dev/null || echo "0%"
        ;;
    Darwin) # macOS
        # macOS does not have 'free'. We use vm_stat to calculate.
        # All values are in terms of 4KB pages.
        local total_mem=$(sysctl -n hw.memsize)
        local pages_free=$(vm_stat | grep 'Pages free' | awk '{print $3}' | tr -d '.')
        local pages_inactive=$(vm_stat | grep 'Pages inactive' | awk '{print $3}' | tr -d '.')
        local page_size=$(sysctl -n hw.pagesize)

        # Available memory is free + inactive pages.
        local mem_available=$(((pages_free + pages_inactive) * page_size))
        local mem_used=$((total_mem - mem_available))

        # Calculate percentage and format.
        echo "$mem_used $total_mem" | awk '{printf "%.0f%%", $1 / $2 * 100}' 2>/dev/null || echo "0%"
        ;;
    *)
        echo "N/A"
        ;;
    esac
}

current_hostname=$(hostname -s)
host=$(printf "#[bg=#{@thm_peach},fg=#{@thm_crust}]#[reverse]#[noreverse]  %s " "$current_hostname")
session="#[bg=#{@thm_lavender},fg=#{@thm_crust}]#[reverse]#[noreverse]   #{session_name} "
pane="#[bg=#{@thm_teal},fg=#{@thm_crust}]#[reverse]#[noreverse]   #{pane_id} "
justpane="#[bg=#{@thm_teal},fg=#{@thm_crust}]#[reverse]#[noreverse]   #{pane_id} "

status_bar=""
if [ "$WINDOW_WIDTH" -gt 120 ]; then

    # only compute if we are going to use it.
    cpu_percentage=$(get_cpu_usage)
    ram_percentage=$(get_ram_usage)

    # set color for CPU usage
    cpu_usage_val=$(echo "$cpu_percentage" | sed 's/%//')
    cpu_fg_color="thm_green" # Default to "low" color
    if (($(echo "$cpu_usage_val > 70" | bc -l))); then
        cpu_fg_color="thm_red"
    elif (($(echo "$cpu_usage_val > 40" | bc -l))); then
        cpu_fg_color="thm_yellow"
    fi

    cpu=$(printf "#[bg=#{@thm_sapphire},fg=#{@thm_crust}]#[reverse]#[noreverse]   #[fg=#{@cpu_fg_color}]%s " "$cpu_percentage")
    ram=$(printf "#[bg=#{@thm_flamingo},fg=#{@thm_crust}]#[reverse]#[noreverse]   %s " "$ram_percentage")

    status_bar+="$host"
    status_bar+="$session"
    status_bar+="$pane"
    status_bar+="$cpu"
    status_bar+="$ram"
else
    status_bar+="$justpane"
fi

echo "$status_bar"
