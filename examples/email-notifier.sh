#!/bin/bash
#
# Email Notifier for iLO Fans Controller
#
# This script monitors your iLO server and sends email alerts for critical events:
# - High temperature warnings (>70°C)
# - Critical temperature alerts (>80°C)
# - Fan failures
# - System health changes
#
# Requirements:
#   - mailutils or sendmail installed
#   - Properly configured MTA (Postfix, Exim, etc.)
#
# Installation:
#   1. Edit configuration below
#   2. Test: ./email-notifier.sh
#   3. Add to crontab: */5 * * * * /path/to/email-notifier.sh
#

# ===========================
# CONFIGURATION
# ===========================

# Email settings
EMAIL_TO="admin@example.com"
EMAIL_FROM="ilo-monitor@example.com"
EMAIL_SUBJECT_PREFIX="[iLO Alert]"

# SMTP settings (optional - for external SMTP)
USE_EXTERNAL_SMTP=false
SMTP_HOST="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER="your-email@gmail.com"
SMTP_PASS="your-app-password"
SMTP_TLS=true

# iLO API settings
ILO_HOST="192.168.1.100"
ILO_URL="http://localhost:8000/index.php"  # Adjust to your installation

# Alert thresholds
TEMP_WARNING=70
TEMP_CRITICAL=80
COOLDOWN_PERIOD=3600  # Seconds between repeated alerts (1 hour)

# State file to prevent alert spam
STATE_FILE="/tmp/ilo-email-notifier.state"

# ===========================
# FUNCTIONS
# ===========================

send_email_system() {
    local subject="$1"
    local body="$2"

    if command -v mail &> /dev/null; then
        # Using mailutils
        echo "$body" | mail -s "$EMAIL_SUBJECT_PREFIX $subject" -r "$EMAIL_FROM" "$EMAIL_TO"
    elif command -v sendmail &> /dev/null; then
        # Using sendmail
        {
            echo "From: $EMAIL_FROM"
            echo "To: $EMAIL_TO"
            echo "Subject: $EMAIL_SUBJECT_PREFIX $subject"
            echo ""
            echo "$body"
        } | sendmail -t
    else
        echo "ERROR: No mail command found. Install mailutils or sendmail."
        return 1
    fi
}

send_email_smtp() {
    local subject="$1"
    local body="$2"

    local auth=""
    if [ -n "$SMTP_USER" ] && [ -n "$SMTP_PASS" ]; then
        auth="--mail-auth"
        auth="$auth --mail-auth-user $SMTP_USER"
        auth="$auth --mail-auth-pass $SMTP_PASS"
    fi

    local tls=""
    if [ "$SMTP_TLS" = true ]; then
        tls="--ssl"
    fi

    # Using curl for SMTP
    curl -s $tls \
        --url "smtp://$SMTP_HOST:$SMTP_PORT" \
        $auth \
        --mail-from "$EMAIL_FROM" \
        --mail-rcpt "$EMAIL_TO" \
        --upload-file - << EOF
From: $EMAIL_FROM
To: $EMAIL_TO
Subject: $EMAIL_SUBJECT_PREFIX $subject

$body
EOF
}

send_email() {
    local subject="$1"
    local body="$2"

    if [ "$USE_EXTERNAL_SMTP" = true ]; then
        send_email_smtp "$subject" "$body"
    else
        send_email_system "$subject" "$body"
    fi

    if [ $? -eq 0 ]; then
        echo "[$(date)] Email sent: $subject"
        return 0
    else
        echo "[$(date)] ERROR: Failed to send email"
        return 1
    fi
}

check_cooldown() {
    local alert_type="$1"
    local current_time=$(date +%s)

    if [ -f "$STATE_FILE" ]; then
        local last_alert=$(grep "^${alert_type}=" "$STATE_FILE" | cut -d'=' -f2)
        if [ -n "$last_alert" ]; then
            local elapsed=$((current_time - last_alert))
            if [ $elapsed -lt $COOLDOWN_PERIOD ]; then
                return 1  # Still in cooldown
            fi
        fi
    fi

    # Update state file
    mkdir -p "$(dirname "$STATE_FILE")"
    grep -v "^${alert_type}=" "$STATE_FILE" 2>/dev/null > "${STATE_FILE}.tmp" || true
    echo "${alert_type}=${current_time}" >> "${STATE_FILE}.tmp"
    mv "${STATE_FILE}.tmp" "$STATE_FILE"

    return 0  # OK to send
}

format_html_email() {
    local title="$1"
    local message="$2"
    local details="$3"
    local severity="$4"  # info, warning, critical

    local color="#3B82F6"  # blue
    case "$severity" in
        warning) color="#F59E0B" ;;  # orange
        critical) color="#EF4444" ;;  # red
    esac

    cat << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: $color; color: white; padding: 20px; border-radius: 5px 5px 0 0; }
        .header h1 { margin: 0; font-size: 24px; }
        .content { background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; border-top: none; }
        .details { background: white; padding: 15px; margin-top: 15px; border-left: 4px solid $color; font-family: monospace; font-size: 12px; }
        .footer { text-align: center; margin-top: 20px; color: #6b7280; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🖥️ $title</h1>
        </div>
        <div class="content">
            <p><strong>Server:</strong> $ILO_HOST</p>
            <p><strong>Time:</strong> $(date '+%Y-%m-%d %H:%M:%S')</p>
            <p>$message</p>
            <div class="details">
                <strong>Details:</strong><br>
                $details
            </div>
        </div>
        <div class="footer">
            <p>iLO Fans Controller Email Notifier</p>
            <p>To manage alerts, edit /path/to/email-notifier.sh</p>
        </div>
    </div>
</body>
</html>
EOF
}

# ===========================
# MONITORING
# ===========================

# Get current status
HEALTH_DATA=$(curl -s "${ILO_URL}?api=health" 2>/dev/null)
TEMP_DATA=$(curl -s "${ILO_URL}?api=temperatures" 2>/dev/null)

if [ -z "$HEALTH_DATA" ] || [ "$HEALTH_DATA" = "null" ]; then
    echo "[$(date)] ERROR: Unable to fetch data from $ILO_URL"
    exit 1
fi

# Parse health status
HEALTH_STATUS=$(echo "$HEALTH_DATA" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

# Check for critical health
if [ "$HEALTH_STATUS" = "critical" ]; then
    if check_cooldown "health_critical"; then
        WARNINGS=$(echo "$HEALTH_DATA" | grep -o '"warnings":\[[^\]]*\]' | sed 's/"warnings":\[//; s/\]//; s/"//g')

        SUBJECT="CRITICAL: System Health Alert"
        BODY=$(format_html_email \
            "Critical System Health Alert" \
            "Your iLO server has entered a critical state and requires immediate attention." \
            "$WARNINGS" \
            "critical")

        send_email "$SUBJECT" "$BODY"
    fi
fi

# Check for high warnings
if [ "$HEALTH_STATUS" = "warning" ]; then
    if check_cooldown "health_warning"; then
        WARNINGS=$(echo "$HEALTH_DATA" | grep -o '"warnings":\[[^\]]*\]' | sed 's/"warnings":\[//; s/\]//; s/"//g')

        SUBJECT="WARNING: System Health Alert"
        BODY=$(format_html_email \
            "System Health Warning" \
            "Your iLO server has detected potential issues that may require attention." \
            "$WARNINGS" \
            "warning")

        send_email "$SUBJECT" "$BODY"
    fi
fi

# Check individual temperatures
if [ -n "$TEMP_DATA" ]; then
    echo "$TEMP_DATA" | grep -o '"name":"[^"]*","value":[0-9]*' | while IFS=':' read -r _ name _ value; do
        name=$(echo "$name" | tr -d '",')
        value=$(echo "$value" | tr -d ',')

        if [ "$value" -gt "$TEMP_CRITICAL" ]; then
            if check_cooldown "temp_critical_${name}"; then
                SUBJECT="CRITICAL: High Temperature on ${name}"
                BODY=$(format_html_email \
                    "Critical Temperature Alert" \
                    "Temperature sensor <strong>${name}</strong> has reached a critical level: <strong>${value}°C</strong>" \
                    "Threshold: ${TEMP_CRITICAL}°C\nCurrent: ${value}°C\nSensor: ${name}\n\nImmediate action recommended!" \
                    "critical")

                send_email "$SUBJECT" "$BODY"
            fi
        elif [ "$value" -gt "$TEMP_WARNING" ]; then
            if check_cooldown "temp_warning_${name}"; then
                SUBJECT="WARNING: Elevated Temperature on ${name}"
                BODY=$(format_html_email \
                    "Temperature Warning" \
                    "Temperature sensor <strong>${name}</strong> is running warm: <strong>${value}°C</strong>" \
                    "Threshold: ${TEMP_WARNING}°C\nCurrent: ${value}°C\nSensor: ${name}\n\nMonitor the situation." \
                    "warning")

                send_email "$SUBJECT" "$BODY"
            fi
        fi
    done
fi

echo "[$(date)] Monitoring check completed. Status: $HEALTH_STATUS"
