#!/usr/bin/env bash
#
# service-manager.sh — Simple interactive TUI for managing systemd services
#
# Usage: ./service-manager.sh
#

set -u

SERVICES=()
CONFIG_FILE_ARG=""
CONFIG_FILE_USED=""

ENABLED_STATE=()
ACTIVE_STATE=()

SUDO=""

ORIG_STTY=""

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
RESET=$'\033[0m'
REVERSE=$'\033[7m'

setup_terminal() {
    ORIG_STTY=$(stty -g)
    stty -echo -icanon min 1 time 0
    tput civis
    tput smcup
}

cleanup() {
    if [[ -n "$ORIG_STTY" ]]; then
        stty "$ORIG_STTY" 2>/dev/null
    fi
    tput cnorm 2>/dev/null
    tput rmcup 2>/dev/null
}

run_privileged() {
    stty "$ORIG_STTY" 2>/dev/null
    "$@"
    local rc=$?
    stty -echo -icanon min 1 time 0
    return "$rc"
}

trap cleanup EXIT
trap 'exit 130' INT TERM

read_key() {
    local key rest
    IFS= read -rsn1 key 2>/dev/null
    if [[ "$key" == $'\x1b' ]]; then
        IFS= read -rsn2 -t 0.05 rest 2>/dev/null
        key+="$rest"
    fi
    printf '%s' "$key"
}

print_usage() {
    cat <<EOF
Usage: $(basename -- "$0") [-c|--config FILE]

Interactive systemd service manager. Reads the list of services to manage
from a config file.

Config file lookup order (first match wins):
  1. -c FILE / --config FILE
  2. \$SERVICE_MANAGER_CONFIG environment variable
  3. /etc/service-manager/services.conf

Config file format:
  One systemd unit name per line. Blank lines and lines starting with '#'
  are ignored, e.g.:

    # services.conf
    nginx.service
    postgresql.service
    redis.service
EOF
}

parse_args() {

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--config)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: $1 requires a file path argument." >&2
                    exit 1
                fi
                CONFIG_FILE_ARG="$2"
                shift 2
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                echo "Unknown argument: $1" >&2
                print_usage
                exit 1
                ;;
        esac
    done
}

create_starter_config() {
    local path="$1" dir
    dir=$(dirname -- "$path")
    mkdir -p -- "$dir"
    cat > "$path" <<'EOF'
# service-manager services list
#
# One systemd unit name per line. Blank lines and lines starting with '#'
# are ignored. Uncomment/edit the examples below (or replace them) with
# the units you want to manage.
#
# nginx.service
# postgresql.service
# redis.service
EOF
    echo "No configuration file found."
    echo "Created a starter config at: $path"
    echo "Edit it to list the systemd units you want to manage, then run this script again."
    exit 1
}

parse_config_file() {
    local file="$1" line
    SERVICES=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" ]] && continue
        SERVICES+=("$line")
    done < "$file"

    if [[ "${#SERVICES[@]}" -eq 0 ]]; then
        echo "Error: no services defined in $file" >&2
        exit 1
    fi
}

load_config() {

    local config_file="" user_config system_config

    if [[ -n "$CONFIG_FILE_ARG" ]]; then
        config_file="$CONFIG_FILE_ARG"
        if [[ ! -f "$config_file" ]]; then
            echo "Error: config file not found: $config_file" >&2
            exit 1
        fi
    elif [[ -n "${SERVICE_MANAGER_CONFIG:-}" ]]; then
        config_file="$SERVICE_MANAGER_CONFIG"
        if [[ ! -f "$config_file" ]]; then
            echo "Error: config file not found: $config_file (from \$SERVICE_MANAGER_CONFIG)" >&2
            exit 1
        fi
    else
        system_config="/etc/service-manager/services.conf"
        if [[ -f "$system_config" ]]; then
            config_file="$system_config"
        else
            create_starter_config "$system_config"
        fi
    fi

    parse_config_file "$config_file"
    CONFIG_FILE_USED="$config_file"
}

check_permissions() {
    clear
    echo "Config: $CONFIG_FILE_USED (${#SERVICES[@]} service(s))"
    if [[ "$EUID" -ne 0 ]]; then
        SUDO="sudo"
        echo "Note: not running as root."
        echo "Actions that change service state (start/stop/restart/enable/disable)"
        echo "will run via 'sudo' and may prompt for your password."
    else
        SUDO=""
    fi
}

get_enabled_state() {
    local svc="$1" state
    state=$(systemctl is-enabled "$svc" 2>/dev/null)
    [[ -z "$state" ]] && state="unknown"
    printf '%s' "$state"
}

get_active_state() {
    local svc="$1" state
    state=$(systemctl is-active "$svc" 2>/dev/null)
    [[ -z "$state" ]] && state="unknown"
    printf '%s' "$state"
}

refresh_statuses() {
    local i
    for i in "${!SERVICES[@]}"; do
        ENABLED_STATE[i]=$(get_enabled_state "${SERVICES[$i]}")
        ACTIVE_STATE[i]=$(get_active_state "${SERVICES[$i]}")
    done
}

color_for_enabled() {
    case "$1" in
        enabled) printf '%s' "$GREEN" ;;
        disabled) printf '%s' "$RED" ;;
        static|masked|linked|alias|generated|indirect) printf '%s' "$YELLOW" ;;
        *) printf '%s' "$YELLOW" ;;
    esac
}

color_for_active() {
    case "$1" in
        active) printf '%s' "$GREEN" ;;
        inactive|failed) printf '%s' "$RED" ;;
        *) printf '%s' "$YELLOW" ;;
    esac
}

draw_services() {
    local selected="$1"
    tput cup 0 0
    local frame

    frame+="========================================"$'\n'
    frame+="        SYSTEMD SERVICE MANAGER"$'\n'
    frame+="========================================"$'\n'
    frame+=$'\n'
    frame+=$(printf "%-25s %-10s %-10s\n" "Service" "Enabled" "Active")
    frame+=$'\n'
    frame+="------------------------------------------------"$'\n'

    local i service enabled active enabled_colour active_colour prefix suffix
    for i in "${!SERVICES[@]}"; do
        service="${SERVICES[$i]}"
        enabled="${ENABLED_STATE[$i]}"
        active="${ACTIVE_STATE[$i]}"
        enabled_colour=$(color_for_enabled "$enabled")
        active_colour=$(color_for_active "$active")

        if [[ "$i" -eq "$selected" ]]; then
            prefix="${REVERSE}> "
            suffix="${RESET}"
        else
            prefix="  "
            suffix=""
        fi

        frame+=$(printf "%b%-25s %b%-10s%b %b%-10s%b%b\n" \
            "$prefix" "$service" "$enabled_colour" "$enabled" "$RESET" "$active_colour" "$active" "$RESET" "$suffix")
        frame+=$'\n'
    done

    frame+=$'\n'
    frame+="
[↑/k]  Move up
[↓/j]  Move down
[Enter]  View status
[Space]  View status
[s]   Start / stop
[r]   Restart
[e]   Enable
[d]   Disable
[f]   Follow logs
[q]   Quit"
    frame+=$'\033[J'

    printf '%s\n' "$frame"
}

pause() {
    echo
    echo "Press any key to continue..."
    read_key >/dev/null
    clear
}

start_service() {
    local svc="$1"
    clear
    echo "Starting $svc ..."
    run_privileged $SUDO systemctl start -- "$svc"
    pause
}

stop_service() {
    local svc="$1"
    clear
    echo "Stopping $svc ..."
    run_privileged $SUDO systemctl stop -- "$svc"
}

toggle_service_status() {
    local svc="$1"

    if systemctl is-active --quiet -- "$svc"; then
        stop_service "$svc"
    else
        start_service "$svc"
    fi
}

restart_service() {
    local svc="$1"
    clear
    echo "Restarting $svc ..."
    run_privileged $SUDO systemctl restart -- "$svc"
    pause
}

enable_service() {
    local svc="$1"
    clear
    echo "Enabling $svc ..."
    run_privileged $SUDO systemctl enable -- "$svc"
    pause
}

disable_service() {
    local svc="$1"
    clear
    echo "Disabling $svc ..."
    run_privileged $SUDO systemctl disable -- "$svc"
    pause
}

show_service_status() {
    local svc="$1"
    clear
    systemctl --no-pager status -- "$svc"
    pause
}

follow_service() {
    local svc="$1"
    clear

    echo "Following logs for $svc"
    echo "Press Ctrl+C to go back."
    echo

    trap '' INT
    journalctl -u "$svc" --no-pager -f
    clear
    trap 'exit 130' INT TERM
}

handle_navigation() {
    local selected=0
    local key

    refresh_statuses
    draw_services "$selected"

    while true; do
        key=$(read_key)

        case "$key" in
            $'\x1b[A'|k|K)
                (( selected > 0 )) && ((selected--))
                ;;
            $'\x1b[B'|j|J)
                (( selected < ${#SERVICES[@]} - 1 )) && ((selected++))
                ;;
            v|V) show_service_status "${SERVICES[$selected]}" ;;
            "") show_service_status "${SERVICES[$selected]}" ;;
            " ") show_service_status "${SERVICES[$selected]}" ;;
            s|S) toggle_service_status "${SERVICES[$selected]}" ;;
            r|R) restart_service "${SERVICES[$selected]}" ;;
            e|E) enable_service "${SERVICES[$selected]}" ;;
            d|D) disable_service "${SERVICES[$selected]}" ;;
            f|F) follow_service "${SERVICES[$selected]}" ;;
            q|Q)
                break
                ;;
        esac
        refresh_statuses
        draw_services "$selected"
    done
}

main() {
    parse_args "$@"

    if ! command -v systemctl &>/dev/null; then
        echo "Error: systemctl not found. This script requires a systemd-based Linux system." >&2
        exit 1
    fi

    load_config
    check_permissions
    setup_terminal
    handle_navigation
}

main "$@"
