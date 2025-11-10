#!/bin/bash

################################################################################
# iLO Fans Controller - Webhook Notifier
################################################################################
#
# This script monitors your iLO fan controller and sends notifications to:
# - Discord
# - Slack
# - Microsoft Teams
# - Generic webhooks
#
# It checks health status and sends alerts for:
# - High temperatures
# - Fan failures
# - System errors
#
# SETUP:
# 1. Configure webhooks below
# 2. Set thresholds
# 3. Add to cron:
#    */5 * * * * /path/to/webhook-notifier.sh
#
################################################################################

# ============================================================================
# CONFIGURATION
# ============================================================================

# iLO Fans Controller URL
ILO_CONTROLLER_URL="http://localhost:8000/index.php"

# Discord Webhook URL (https://discord.com/api/webhooks/...)
DISCORD_WEBHOOK=""

# Slack Webhook URL (https://hooks.slack.com/services/...)
SLACK_WEBHOOK=""

# Microsoft Teams Webhook URL
TEAMS_WEBHOOK=""

# Generic webhook (receives JSON POST)
GENERIC_WEBHOOK=""

# Thresholds
MAX_TEMP_WARNING=70    # °C - Send warning
MAX_TEMP_CRITICAL=80   # °C - Send critical alert
MIN_FAN_SPEED=10       # % - Alert if fan below this

# Notification settings
CHECK_INTERVAL=300     # seconds between checks (5 minutes)
COOLDOWN_FILE="/tmp/ilo-notifier-cooldown"
COOLDOWN_TIME=1800     # seconds before re-alerting (30 minutes)

# ============================================================================
# FUNCTIONS
# ============================================================================

send_discord() {
    local title=$1
    local message=$2
    local color=$3  # decimal color: green=3066993, yellow=16776960, red=15158332

    if [ -z "$DISCORD_WEBHOOK" ]; then
        return
    fi

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

    curl -H "Content-Type: application/json" -X POST -d "{
        \"embeds\": [{
            \"title\": \"$title\",
            \"description\": \"$message\",
            \"color\": $color,
            \"timestamp\": \"$timestamp\",
            \"footer\": {
                \"text\": \"iLO Fans Controller\"
            }
        }]
    }" "$DISCORD_WEBHOOK" 2>/dev/null
}

send_slack() {
    local title=$1
    local message=$2
    local level=$3  # good, warning, danger

    if [ -z "$SLACK_WEBHOOK" ]; then
        return
    fi

    curl -H "Content-Type: application/json" -X POST -d "{
        \"attachments\": [{
            \"color\": \"$level\",
            \"title\": \"$title\",
            \"text\": \"$message\",
            \"footer\": \"iLO Fans Controller\",
            \"ts\": $(date +%s)
        }]
    }" "$SLACK_WEBHOOK" 2>/dev/null
}

send_teams() {
    local title=$1
    local message=$2

    if [ -z "$TEAMS_WEBHOOK" ]; then
        return
    fi

    curl -H "Content-Type: application/json" -X POST -d "{
        \"@type\": \"MessageCard\",
        \"@context\": \"https://schema.org/extensions\",
        \"summary\": \"$title\",
        \"themeColor\": \"FF0000\",
        \"title\": \"$title\",
        \"text\": \"$message\"
    }" "$TEAMS_WEBHOOK" 2>/dev/null
}

send_generic() {
    local title=$1
    local message=$2
    local level=$3

    if [ -z "$GENERIC_WEBHOOK" ]; then
        return
    fi

    curl -H "Content-Type: application/json" -X POST -d "{
        \"title\": \"$title\",
        \"message\": \"$message\",
        \"level\": \"$level\",
        \"timestamp\": $(date +%s),
        \"source\": \"ilo-fans-controller\"
    }" "$GENERIC_WEBHOOK" 2>/dev/null
}

send_notification() {
    local title=$1
    local message=$2
    local level=$3  # info, warning, critical

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $level: $title - $message"

    # Determine colors
    local discord_color=3066993  # green
    local slack_color="good"

    case $level in
        warning)
            discord_color=16776960  # yellow
            slack_color="warning"
            ;;
        critical)
            discord_color=15158332  # red
            slack_color="danger"
            ;;
    esac

    # Send to all configured webhooks
    send_discord "$title" "$message" $discord_color
    send_slack "$title" "$message" $slack_color
    send_teams "$title" "$message"
    send_generic "$title" "$message" $level

    # Update cooldown
    echo $(date +%s) > "$COOLDOWN_FILE"
}

check_cooldown() {
    if [ ! -f "$COOLDOWN_FILE" ]; then
        return 0  # No cooldown, can send
    fi

    local last_alert=$(cat "$COOLDOWN_FILE")
    local now=$(date +%s)
    local elapsed=$((now - last_alert))

    if [ $elapsed -gt $COOLDOWN_TIME ]; then
        return 0  # Cooldown expired
    fi

    return 1  # Still in cooldown
}

# ============================================================================
# MAIN LOGIC
# ============================================================================

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting health check..."

# Fetch health data
health_json=$(curl -s "$ILO_CONTROLLER_URL?api=health")

if [ $? -ne 0 ] || [ -z "$health_json" ]; then
    if check_cooldown; then
        send_notification \
            "⚠️ iLO Controller Unreachable" \
            "Failed to connect to iLO Fans Controller at $ILO_CONTROLLER_URL" \
            "critical"
    fi
    exit 1
fi

# Parse JSON (requires jq)
if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is required but not installed"
    echo "Install with: sudo apt-get install jq"
    exit 1
fi

# Extract data
status=$(echo "$health_json" | jq -r '.status')
ilo_connection=$(echo "$health_json" | jq -r '.ilo_connection')
errors=$(echo "$health_json" | jq -r '.errors[]?' 2>/dev/null)
warnings=$(echo "$health_json" | jq -r '.warnings[]?' 2>/dev/null)

# Get temperatures
temps_json=$(curl -s "$ILO_CONTROLLER_URL?api=temperatures")
max_temp=0

if [ $? -eq 0 ] && [ ! -z "$temps_json" ]; then
    max_temp=$(echo "$temps_json" | jq '[.[].current] | max')
fi

# Get fan speeds
fans_json=$(curl -s "$ILO_CONTROLLER_URL?api=fans")
min_fan_speed=100

if [ $? -eq 0 ] && [ ! -z "$fans_json" ]; then
    min_fan_speed=$(echo "$fans_json" | jq '[.[]] | min')
fi

echo "Status: $status"
echo "Max Temperature: ${max_temp}°C"
echo "Min Fan Speed: ${min_fan_speed}%"

# ============================================================================
# ALERT LOGIC
# ============================================================================

alert_sent=false

# Check critical temperature
if [ $(echo "$max_temp >= $MAX_TEMP_CRITICAL" | bc) -eq 1 ]; then
    if check_cooldown; then
        send_notification \
            "🔥 CRITICAL: High Temperature" \
            "Maximum temperature reached ${max_temp}°C (threshold: ${MAX_TEMP_CRITICAL}°C)\nImmediate action required!" \
            "critical"
        alert_sent=true
    fi
fi

# Check warning temperature
if [ "$alert_sent" = false ] && [ $(echo "$max_temp >= $MAX_TEMP_WARNING" | bc) -eq 1 ]; then
    if check_cooldown; then
        send_notification \
            "⚠️ WARNING: High Temperature" \
            "Temperature is ${max_temp}°C (warning threshold: ${MAX_TEMP_WARNING}°C)\nConsider increasing fan speeds." \
            "warning"
        alert_sent=true
    fi
fi

# Check fan speed
if [ "$alert_sent" = false ] && [ $(echo "$min_fan_speed < $MIN_FAN_SPEED" | bc) -eq 1 ]; then
    if check_cooldown; then
        send_notification \
            "🌀 WARNING: Low Fan Speed" \
            "Minimum fan speed is ${min_fan_speed}% (threshold: ${MIN_FAN_SPEED}%)\nFans may be too slow for adequate cooling." \
            "warning"
        alert_sent=true
    fi
fi

# Check for errors
if [ "$alert_sent" = false ] && [ ! -z "$errors" ]; then
    if check_cooldown; then
        error_list=$(echo "$errors" | tr '\n' ' | ')
        send_notification \
            "❌ System Errors Detected" \
            "Errors: $error_list" \
            "critical"
        alert_sent=true
    fi
fi

# Check iLO connection
if [ "$alert_sent" = false ] && [ "$ilo_connection" != "ok" ]; then
    if check_cooldown; then
        send_notification \
            "🔌 iLO Connection Error" \
            "Cannot communicate with iLO interface\nCheck network connectivity and credentials." \
            "critical"
        alert_sent=true
    fi
fi

# Send all-clear if previously in cooldown and now healthy
if [ "$alert_sent" = false ] && [ "$status" = "healthy" ] && [ -f "$COOLDOWN_FILE" ]; then
    # Check if we recently sent an alert
    last_alert=$(cat "$COOLDOWN_FILE")
    now=$(date +%s)
    elapsed=$((now - last_alert))

    # If cooldown just expired and status is healthy, send all-clear
    if [ $elapsed -gt $((COOLDOWN_TIME - 60)) ] && [ $elapsed -lt $((COOLDOWN_TIME + 60)) ]; then
        send_notification \
            "✅ System Healthy" \
            "All systems are now operating normally.\nTemperature: ${max_temp}°C | Min Fan Speed: ${min_fan_speed}%" \
            "info"
        rm -f "$COOLDOWN_FILE"
    fi
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Check complete"

################################################################################
# INSTALLATION INSTRUCTIONS
################################################################################
#
# 1. Install jq (JSON parser):
#    sudo apt-get install jq bc
#
# 2. Configure webhooks (Discord, Slack, Teams, or Generic)
#
# 3. Test the script:
#    ./webhook-notifier.sh
#
# 4. Add to crontab for automatic monitoring:
#    crontab -e
#
#    Add this line (runs every 5 minutes):
#    */5 * * * * /path/to/webhook-notifier.sh >> /var/log/ilo-webhook-notifier.log 2>&1
#
# 5. Monitor the logs:
#    tail -f /var/log/ilo-webhook-notifier.log
#
################################################################################
