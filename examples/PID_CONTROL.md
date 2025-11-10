# PID-Based Fan Control

This document addresses **Issue #9**: Feature request for PID (Proportional-Integral-Derivative) curve configuration instead of static fan speeds.

## Overview

### Current Behavior (Static Control)
The tool currently sets **static fan speeds**:
- You set fans to a fixed percentage (e.g., 50%)
- Fans stay at that speed regardless of temperature changes
- **Risk**: If temperatures rise unexpectedly, fans won't automatically speed up, potentially causing hardware damage

### Desired Behavior (PID Control)
With PID control:
- You define **temperature thresholds** and **response curves**
- iLO's firmware automatically adjusts fan speeds based on current temperatures
- **Benefit**: Dynamic response to changing thermal conditions while maintaining baseline noise levels

## iLO Commands

The patched iLO 4 firmware provides these PID-related SSH commands:

```bash
# Set PID temperature thresholds for a control segment
fan pid <zone> lo <temp>   # Low temperature threshold (°C)
fan pid <zone> hi <temp>   # High temperature threshold (°C)
fan pid <zone> p <pwm>     # PWM duty cycle range for this segment

# Set minimum fan speed
fan p <fan_index> min <pwm>  # Minimum PWM value (0-255)

# Example: Configure zone 0 for 40-60°C range with moderate fan response
fan pid 0 lo 40
fan pid 0 hi 60
fan pid 0 p 128
fan p 0 min 40
```

### Understanding PWM Values
- **PWM Range**: 0-255 (where 255 = 100%)
- **Example conversions**:
  - 15% = 38 PWM
  - 50% = 128 PWM
  - 100% = 255 PWM

## Implementation Approaches

### Option 1: PID Configuration Script

For users who want PID control now, here's a standalone script:

```bash
#!/bin/bash
# pid-setup.sh - Configure PID fan control curves

ILO_HOST="192.168.1.69"
ILO_USER="Administrator"
ILO_PASS="YourPassword"

# Connect via SSH and configure PID
sshpass -p "$ILO_PASS" ssh -o StrictHostKeyChecking=no "$ILO_USER@$ILO_HOST" << 'EOF'
# Zone 0: Quiet operation (40-55°C)
fan pid 0 lo 40
fan pid 0 hi 55
fan pid 0 p 64

# Zone 1: Normal operation (55-70°C)
fan pid 1 lo 55
fan pid 1 hi 70
fan pid 1 p 128

# Zone 2: Aggressive cooling (70-85°C)
fan pid 2 lo 70
fan pid 2 hi 85
fan pid 2 p 200

# Set minimum fan speeds (safety baseline)
fan p 0 min 40
fan p 1 min 40
fan p 2 min 40
fan p 3 min 40
fan p 4 min 40
fan p 5 min 40

exit
EOF

echo "PID curves configured successfully"
```

Run this script once to set up PID curves. The iLO firmware will maintain these settings.

### Option 2: Hybrid Approach (Recommended)

Combine PID control with manual overrides:

1. **Set up PID curves** for automatic thermal management (using script above)
2. **Adjust minimum fan speeds** via the web UI for noise control
3. **Override temporarily** when needed (e.g., during maintenance)

Example workflow:
```bash
# 1. Configure PID curves (one-time setup)
./pid-setup.sh

# 2. Adjust minimum fan speeds via API when needed
curl -X POST http://your-ilo-controller/index.php \
  -H 'Content-Type: application/json' \
  -d '{"action": "fans", "fans": {"Fan 1": 30, "Fan 2": 30}}'
```

### Option 3: Full Web UI Integration (Future Enhancement)

For a complete solution, the web interface would need:

**UI Changes**:
- Toggle between "Static Mode" and "PID Mode"
- PID configuration panel with:
  - Temperature zone sliders (lo/hi thresholds)
  - PWM response curves (graphical or numeric)
  - Per-fan minimum speed settings

**Backend Changes**:
- New API endpoint: `?api=pid` for reading/setting PID config
- SSH commands to query current PID settings
- Validation for temperature ranges and PWM values

**Example UI mockup**:
```
┌─────────────────────────────────────┐
│ Fan Control Mode: [Static] [PID]   │
├─────────────────────────────────────┤
│ Zone 0 (Quiet)                      │
│ Temp Range: [40°C] ━━━━━ [55°C]    │
│ Fan Response: [25%] (Low)           │
├─────────────────────────────────────┤
│ Zone 1 (Normal)                     │
│ Temp Range: [55°C] ━━━━━ [70°C]    │
│ Fan Response: [50%] (Medium)        │
├─────────────────────────────────────┤
│ Zone 2 (Aggressive)                 │
│ Temp Range: [70°C] ━━━━━ [85°C]    │
│ Fan Response: [80%] (High)          │
└─────────────────────────────────────┘
```

## Safety Considerations

⚠️ **IMPORTANT**: When implementing PID control:

1. **Always set reasonable minimum fan speeds**
   - Never set min PWM below 30 (≈12%) for safety
   - Inadequate airflow can damage hardware

2. **Test your curves thoroughly**
   - Monitor temperatures under load
   - Verify fans respond appropriately
   - Have manual override ready

3. **Understand your hardware**
   - Different servers have different thermal characteristics
   - Check HP's recommended operating ranges
   - Consider ambient temperature

4. **Keep static control available**
   - PID might not work perfectly for all scenarios
   - Manual override should always be possible

## Example Configurations

### Home Lab (Quiet Priority)
```bash
# Optimized for low noise in typical home environment
fan pid 0 lo 35
fan pid 0 hi 50
fan pid 0 p 50    # Very gentle response

fan pid 1 lo 50
fan pid 1 hi 70
fan pid 1 p 100

fan p 0 min 38    # 15% minimum (quiet but safe)
```

### Production Server (Cooling Priority)
```bash
# Optimized for maximum cooling performance
fan pid 0 lo 40
fan pid 0 hi 55
fan pid 0 p 100

fan pid 1 lo 55
fan pid 1 hi 65
fan pid 1 p 150

fan pid 2 lo 65
fan pid 2 hi 75
fan pid 2 p 200

fan p 0 min 64    # 25% minimum (safer baseline)
```

### Summer Heat (Seasonal Adjustment)
```bash
# Higher baseline for hot ambient temperatures
fan pid 0 lo 45
fan pid 0 hi 60
fan pid 0 p 100

fan pid 1 lo 60
fan pid 1 hi 75
fan pid 1 p 128

fan p 0 min 64    # 25% minimum due to ambient heat
```

## API Extension Proposal

To support PID control in the web interface, the API could be extended:

### Get PID Configuration
```bash
GET /index.php?api=pid
```

Response:
```json
{
  "zones": [
    {
      "zone": 0,
      "lo": 40,
      "hi": 55,
      "p": 64
    },
    {
      "zone": 1,
      "lo": 55,
      "hi": 70,
      "p": 128
    }
  ],
  "minimums": {
    "Fan 1": 40,
    "Fan 2": 40,
    "Fan 3": 40
  }
}
```

### Set PID Configuration
```bash
POST /index.php
Content-Type: application/json

{
  "action": "pid",
  "zones": [
    {"zone": 0, "lo": 40, "hi": 55, "p": 64},
    {"zone": 1, "lo": 55, "hi": 70, "p": 128}
  ],
  "minimums": {
    "Fan 1": 40,
    "Fan 2": 40
  }
}
```

## Reading Current Temperatures

To make informed PID decisions, you can read temperatures via iLO's REST API (already used for fan speeds):

```bash
curl -k -u admin:password \
  https://ilo-address/redfish/v1/Chassis/1/Thermal \
  | jq '.Temperatures'
```

This could be displayed alongside fan speeds in the web UI.

## Migration Path

For users wanting to switch from static to PID control:

1. **Document current static settings** (as a fallback)
2. **Calculate equivalent PID curves** based on typical temperatures
3. **Apply PID configuration** using provided scripts
4. **Monitor for 24-48 hours** under normal load
5. **Adjust curves** based on observed behavior
6. **Document final configuration** for future reference

## Contributing

If you implement PID support or have configurations that work well for your setup, please share:
- Open a pull request with your implementation
- Share your PID curves in discussions
- Report any issues or unexpected behavior

## References

- **Issue #9**: https://github.com/alex3025/ilo-fans-controller/issues/9
- **iLO 4 Patch Discussion**: https://www.reddit.com/r/homelab/comments/sx3ldo/hp_ilo4_v277_unlocked_access_to_fan_controls/
- **HP iLO REST API**: Check your iLO's built-in documentation

## Conclusion

PID control is a valuable feature that provides **dynamic thermal management** while maintaining **baseline noise control**.

**Current recommendation**: Use the provided scripts for PID setup, combined with the existing web interface for minimum fan speed adjustments.

**Future enhancement**: Full PID configuration UI would be a welcome contribution from the community!
