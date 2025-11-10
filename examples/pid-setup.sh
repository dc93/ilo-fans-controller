#!/bin/bash

################################################################################
# iLO PID Fan Control Setup Script
################################################################################
#
# This script configures PID (Proportional-Integral-Derivative) curves for
# dynamic fan control based on temperature, instead of static fan speeds.
#
# WHAT IS PID CONTROL?
# Instead of setting fans to a fixed speed, PID control allows the iLO firmware
# to automatically adjust fan speeds based on current temperatures using
# predefined temperature zones and response curves.
#
# SAFETY WARNING:
# - Always set reasonable minimum fan speeds (never below 12-15%)
# - Test thoroughly under load before leaving unattended
# - Monitor temperatures for the first 24-48 hours
# - Keep manual override available as fallback
#
# REQUIREMENTS:
# - Patched iLO 4 firmware with fan control commands
# - SSH access to iLO interface
# - sshpass utility (install: apt-get install sshpass)
#
################################################################################

# ============================================================================
# CONFIGURATION
# ============================================================================

ILO_HOST="192.168.1.69"
ILO_USERNAME="Administrator"
ILO_PASSWORD="YourPassword"

# Choose a preset configuration profile:
# - "quiet"      : Optimized for low noise (home lab)
# - "balanced"   : Good balance of noise and cooling
# - "performance": Maximum cooling (production servers)
# - "custom"     : Define your own zones (edit CUSTOM_* variables below)
PROFILE="balanced"

# Custom PID zones (only used if PROFILE="custom")
# Each zone defines: lo_temp hi_temp pwm_response
# Format: "low_temp:high_temp:pwm_duty_cycle"
CUSTOM_ZONES=(
    "40:55:64"    # Zone 0: 40-55°C, gentle response (25%)
    "55:70:128"   # Zone 1: 55-70°C, moderate response (50%)
    "70:85:200"   # Zone 2: 70-85°C, aggressive response (78%)
)

# Minimum fan speed (PWM 0-255, where 255=100%)
# 38 PWM = ~15%, 64 PWM = ~25%, 128 PWM = ~50%
CUSTOM_MIN_PWM=40  # ~16% minimum

# ============================================================================
# PRESET PROFILES
# ============================================================================

apply_quiet_profile() {
    echo "Applying QUIET profile (optimized for low noise)..."
    cat << 'EOF'
# Zone 0: Very gentle response for low temps
fan pid 0 lo 35
fan pid 0 hi 50
fan pid 0 p 50

# Zone 1: Moderate response for normal temps
fan pid 1 lo 50
fan pid 1 hi 70
fan pid 1 p 100

# Zone 2: Higher response for elevated temps
fan pid 2 lo 70
fan pid 2 hi 85
fan pid 2 p 150

# Set minimum fan speeds (15% - quiet but safe)
fan p 0 min 38
fan p 1 min 38
fan p 2 min 38
fan p 3 min 38
fan p 4 min 38
fan p 5 min 38
EOF
}

apply_balanced_profile() {
    echo "Applying BALANCED profile (good mix of noise and cooling)..."
    cat << 'EOF'
# Zone 0: Gentle response for low temps
fan pid 0 lo 40
fan pid 0 hi 55
fan pid 0 p 64

# Zone 1: Normal response for typical temps
fan pid 1 lo 55
fan pid 1 hi 70
fan pid 1 p 128

# Zone 2: Strong response for elevated temps
fan pid 2 lo 70
fan pid 2 hi 85
fan pid 2 p 200

# Set minimum fan speeds (20% - balanced)
fan p 0 min 50
fan p 1 min 50
fan p 2 min 50
fan p 3 min 50
fan p 4 min 50
fan p 5 min 50
EOF
}

apply_performance_profile() {
    echo "Applying PERFORMANCE profile (maximum cooling)..."
    cat << 'EOF'
# Zone 0: Quick response even at lower temps
fan pid 0 lo 40
fan pid 0 hi 55
fan pid 0 p 100

# Zone 1: Strong response for normal temps
fan pid 1 lo 55
fan pid 1 hi 65
fan pid 1 p 150

# Zone 2: Maximum response for high temps
fan pid 2 lo 65
fan pid 2 hi 75
fan pid 2 p 220

# Set minimum fan speeds (25% - safer baseline)
fan p 0 min 64
fan p 1 min 64
fan p 2 min 64
fan p 3 min 64
fan p 4 min 64
fan p 5 min 64
EOF
}

apply_custom_profile() {
    echo "Applying CUSTOM profile..."

    local zone_idx=0
    for zone in "${CUSTOM_ZONES[@]}"; do
        IFS=':' read -r lo hi pwm <<< "$zone"
        echo "fan pid $zone_idx lo $lo"
        echo "fan pid $zone_idx hi $hi"
        echo "fan pid $zone_idx p $pwm"
        ((zone_idx++))
    done

    # Apply minimum PWM to all fans (0-5 for typical servers)
    for fan_idx in {0..5}; do
        echo "fan p $fan_idx min $CUSTOM_MIN_PWM"
    done
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

echo "======================================================================"
echo "iLO PID Fan Control Setup"
echo "======================================================================"
echo ""
echo "Configuration:"
echo "  iLO Host: $ILO_HOST"
echo "  Username: $ILO_USERNAME"
echo "  Profile:  $PROFILE"
echo ""

# Check if sshpass is installed
if ! command -v sshpass &> /dev/null; then
    echo "ERROR: sshpass is not installed."
    echo "Install it with: apt-get install sshpass"
    exit 1
fi

# Generate commands based on profile
case "$PROFILE" in
    quiet)
        COMMANDS=$(apply_quiet_profile)
        ;;
    balanced)
        COMMANDS=$(apply_balanced_profile)
        ;;
    performance)
        COMMANDS=$(apply_performance_profile)
        ;;
    custom)
        COMMANDS=$(apply_custom_profile)
        ;;
    *)
        echo "ERROR: Invalid profile '$PROFILE'"
        echo "Valid profiles: quiet, balanced, performance, custom"
        exit 1
        ;;
esac

# Confirm before applying
echo "The following commands will be sent to iLO:"
echo "----------------------------------------------------------------------"
echo "$COMMANDS"
echo "----------------------------------------------------------------------"
echo ""
read -p "Apply this configuration? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted by user."
    exit 0
fi

# Apply configuration via SSH
echo ""
echo "Connecting to iLO and applying PID configuration..."

sshpass -p "$ILO_PASSWORD" ssh -o StrictHostKeyChecking=no "$ILO_USERNAME@$ILO_HOST" << EOF
$COMMANDS
exit
EOF

if [ $? -eq 0 ]; then
    echo ""
    echo "======================================================================"
    echo "✓ PID configuration applied successfully!"
    echo "======================================================================"
    echo ""
    echo "Next steps:"
    echo "  1. Monitor your server temperatures over the next 24-48 hours"
    echo "  2. Listen for unusual fan noise patterns"
    echo "  3. Verify fans respond appropriately under load"
    echo "  4. Adjust configuration if needed and re-run this script"
    echo ""
    echo "To monitor current fan speeds, visit your iLO Fans Controller web UI"
    echo "or use the API: curl http://your-controller/index.php?api=fans"
    echo ""
else
    echo ""
    echo "======================================================================"
    echo "✗ ERROR: Failed to apply PID configuration"
    echo "======================================================================"
    echo ""
    echo "Troubleshooting:"
    echo "  - Verify iLO credentials are correct"
    echo "  - Check iLO is accessible via SSH: ssh $ILO_USERNAME@$ILO_HOST"
    echo "  - Ensure iLO firmware is patched with fan control support"
    echo "  - Check network connectivity to iLO interface"
    exit 1
fi

################################################################################
# REVERTING TO STATIC CONTROL
################################################################################
#
# If you want to revert to static fan control (original behavior), you can
# set specific PWM values directly instead of PID curves:
#
# sshpass -p "$ILO_PASSWORD" ssh "$ILO_USERNAME@$ILO_HOST" << 'EOF'
# # Set all fans to 50% (128 PWM)
# fan p 0 max 128
# fan p 0 min 255
# fan p 1 max 128
# fan p 1 min 255
# fan p 2 max 128
# fan p 2 min 255
# fan p 3 max 128
# fan p 3 min 255
# fan p 4 max 128
# fan p 4 min 255
# fan p 5 max 128
# fan p 5 min 255
# exit
# EOF
#
# Or use the web UI / API to set desired static speeds.
#
################################################################################
