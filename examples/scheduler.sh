#!/bin/bash

################################################################################
# iLO Fans Controller - Scheduler Example Script
################################################################################
#
# This script automatically applies different fan speed presets based on
# time of day and day of week. It's designed to be run via cron.
#
# USE CASE:
# - Daytime (9AM-9PM): Use "Normal Mode" preset for active server usage
# - Nighttime (9PM-9AM): Use "Silent Mode" preset for quiet operation
# - Weekends: Optional different schedule
#
# SETUP:
# 1. Edit the configuration section below to match your environment
# 2. Make the script executable: chmod +x scheduler.sh
# 3. Add to crontab to run every hour (or more frequently):
#    0 * * * * /path/to/scheduler.sh
#
################################################################################

# ============================================================================
# CONFIGURATION
# ============================================================================

# URL to your iLO Fans Controller instance
ILO_CONTROLLER_URL="http://localhost:8000/index.php"

# Silent mode preset (applied during nighttime)
# You can use a preset name or directly specify fan speeds as a number (e.g., 15)
SILENT_PRESET='{"action": "fans", "fans": 15}'

# Normal mode preset (applied during daytime)
NORMAL_PRESET='{"action": "fans", "fans": 50}'

# Turbo mode preset (optional, for hot days or heavy workloads)
TURBO_PRESET='{"action": "fans", "fans": 100}'

# Time ranges (24-hour format)
DAYTIME_START_HOUR=9   # 9 AM
DAYTIME_END_HOUR=21    # 9 PM

# Weekend behavior: "same" or "always_silent"
WEEKEND_MODE="same"

# ============================================================================
# SCHEDULER LOGIC
# ============================================================================

# Get current hour (0-23) and day of week (1-7, where 1=Monday, 7=Sunday)
CURRENT_HOUR=$(date +%H)
CURRENT_DAY=$(date +%u)

# Remove leading zeros to avoid octal interpretation
CURRENT_HOUR=$((10#$CURRENT_HOUR))

# Determine if it's a weekend (Saturday=6, Sunday=7)
IS_WEEKEND=0
if [ "$CURRENT_DAY" -eq 6 ] || [ "$CURRENT_DAY" -eq 7 ]; then
    IS_WEEKEND=1
fi

# Function to apply a preset
apply_preset() {
    local preset=$1
    local preset_name=$2

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Applying $preset_name preset..."

    response=$(curl -s -X POST "$ILO_CONTROLLER_URL" \
        -H "Content-Type: application/json" \
        -d "$preset" \
        -w "\n%{http_code}")

    http_code=$(echo "$response" | tail -n1)

    if [ "$http_code" = "200" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Successfully applied $preset_name preset"
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ Failed to apply $preset_name preset (HTTP $http_code)"
        return 1
    fi
}

# Determine which preset to apply
if [ $IS_WEEKEND -eq 1 ] && [ "$WEEKEND_MODE" = "always_silent" ]; then
    # Weekend: always use silent mode
    apply_preset "$SILENT_PRESET" "Silent (Weekend)"
elif [ $CURRENT_HOUR -ge $DAYTIME_START_HOUR ] && [ $CURRENT_HOUR -lt $DAYTIME_END_HOUR ]; then
    # Daytime hours
    apply_preset "$NORMAL_PRESET" "Normal (Daytime)"
else
    # Nighttime hours
    apply_preset "$SILENT_PRESET" "Silent (Nighttime)"
fi

################################################################################
# ADVANCED USAGE EXAMPLES
################################################################################
#
# Example 1: Temperature-based scheduling
# You can extend this script to check temperatures and apply turbo mode:
#
# TEMP=$(curl -s "$ILO_CONTROLLER_URL?api=fans" | jq '[.[] | tonumber] | max')
# if [ "$TEMP" -gt 80 ]; then
#     apply_preset "$TURBO_PRESET" "Turbo (High Temperature)"
# fi
#
# Example 2: Workday-specific schedules
# Apply different schedules based on specific days:
#
# if [ "$CURRENT_DAY" -eq 1 ]; then  # Monday
#     # Heavy backup operations on Monday nights
#     if [ $CURRENT_HOUR -ge 22 ]; then
#         apply_preset "$TURBO_PRESET" "Turbo (Monday Backup)"
#     fi
# fi
#
# Example 3: Multiple time windows
# Create more granular time-based schedules:
#
# if [ $CURRENT_HOUR -ge 1 ] && [ $CURRENT_HOUR -lt 7 ]; then
#     apply_preset "$SILENT_PRESET" "Silent (Deep Night)"
# elif [ $CURRENT_HOUR -ge 7 ] && [ $CURRENT_HOUR -lt 9 ]; then
#     apply_preset "$NORMAL_PRESET" "Normal (Morning)"
# elif [ $CURRENT_HOUR -ge 9 ] && [ $CURRENT_HOUR -lt 18 ]; then
#     apply_preset "$TURBO_PRESET" "Turbo (Work Hours)"
# elif [ $CURRENT_HOUR -ge 18 ] && [ $CURRENT_HOUR -lt 22 ]; then
#     apply_preset "$NORMAL_PRESET" "Normal (Evening)"
# else
#     apply_preset "$SILENT_PRESET" "Silent (Night)"
# fi
#
################################################################################
