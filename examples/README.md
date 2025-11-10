# Examples

This directory contains example scripts and configurations for extending the iLO Fans Controller functionality.

## Scheduler Script (`scheduler.sh`)

A bash script that automatically applies different fan speed presets based on time of day and day of week.

### Features

- **Time-based scheduling**: Different presets for daytime vs nighttime
- **Weekend support**: Optional different behavior on weekends
- **Extensible**: Easy to customize for temperature-based control, specific workdays, etc.
- **Logging**: Timestamps and status messages for troubleshooting

### Quick Start

1. **Configure the script**:
   ```bash
   nano scheduler.sh
   ```
   Edit the configuration section to set:
   - Your iLO Fans Controller URL
   - Preset configurations (silent, normal, turbo)
   - Time ranges for daytime/nighttime

2. **Make it executable**:
   ```bash
   chmod +x scheduler.sh
   ```

3. **Test it manually**:
   ```bash
   ./scheduler.sh
   ```

4. **Add to crontab** for automatic execution:
   ```bash
   crontab -e
   ```
   Add one of these lines:
   ```
   # Run every hour
   0 * * * * /path/to/ilo-fans-controller/examples/scheduler.sh >> /var/log/ilo-scheduler.log 2>&1

   # Run every 30 minutes
   */30 * * * * /path/to/ilo-fans-controller/examples/scheduler.sh >> /var/log/ilo-scheduler.log 2>&1

   # Run every 15 minutes (more responsive)
   */15 * * * * /path/to/ilo-fans-controller/examples/scheduler.sh >> /var/log/ilo-scheduler.log 2>&1
   ```

### Use Cases

**Home Lab Scenario** (from Issue #28):
- **Daytime (9AM-9PM)**: Normal preset (50% fan speed) for active usage
- **Nighttime (9PM-9AM)**: Silent preset (15% fan speed) for quiet operation
- Automatically adjusts based on time, regardless of seasonal temperature changes

**Office Server**:
- **Business hours (8AM-6PM, Mon-Fri)**: Normal or Turbo preset
- **After hours & weekends**: Silent preset
- Saves noise and potentially energy

**Temperature-Sensitive**:
- Check current fan speeds or temperatures
- Apply turbo mode if temperatures exceed threshold
- Return to scheduled preset when temperatures normalize

### Advanced Customization

The script includes commented examples for:
- Temperature-based overrides
- Workday-specific schedules
- Multiple time windows throughout the day
- Integration with other monitoring tools

### Logs

View logs to verify the scheduler is working:
```bash
tail -f /var/log/ilo-scheduler.log
```

Expected output:
```
[2025-11-10 09:00:01] Applying Normal (Daytime) preset...
[2025-11-10 09:00:02] ✓ Successfully applied Normal (Daytime) preset
[2025-11-10 21:00:01] Applying Silent (Nighttime) preset...
[2025-11-10 21:00:02] ✓ Successfully applied Silent (Nighttime) preset
```

### Requirements

- `curl` command (usually pre-installed on Linux)
- `jq` command (optional, for advanced temperature-based logic)
- Access to your iLO Fans Controller instance
- Cron daemon running (standard on most systems)

### Troubleshooting

**Script doesn't execute**:
- Verify it's executable: `ls -l scheduler.sh`
- Check shebang line is correct: `#!/bin/bash`

**No changes to fans**:
- Verify URL is correct and accessible: `curl http://your-url/index.php?api=fans`
- Check cron is running: `sudo systemctl status cron`
- Review logs for error messages

**Wrong time zone**:
- The script uses the system time
- Verify: `date`
- Adjust if needed: `sudo timedatectl set-timezone Your/Timezone`

## PID-Based Fan Control (`pid-setup.sh` and `PID_CONTROL.md`)

**What is PID control?**

Instead of setting fans to a **static speed** (e.g., always 50%), PID control allows the iLO firmware to **dynamically adjust** fan speeds based on current temperatures using predefined temperature zones.

**Benefits:**
- **Safety**: Fans automatically speed up if temperatures rise unexpectedly
- **Quieter**: Fans run slower when temperatures are low
- **Efficient**: Better balance between cooling and noise

**Quick Setup:**
```bash
# Edit the configuration (choose a profile or customize)
nano pid-setup.sh

# Apply the configuration
./pid-setup.sh
```

**Available Profiles:**
- **Quiet**: Optimized for low noise (home labs)
- **Balanced**: Good mix of cooling and noise (default recommendation)
- **Performance**: Maximum cooling (production servers)
- **Custom**: Define your own temperature zones

**Important Safety Notes:**
- Always set reasonable minimum fan speeds (never below 12-15%)
- Monitor temperatures for 24-48 hours after applying
- Keep manual override available as fallback

For complete documentation including:
- How PID curves work
- Safety considerations
- Example configurations
- API extension proposals
- Migration from static to PID control

See [PID_CONTROL.md](PID_CONTROL.md)

## Contributing

Have a useful example script? Please share it by opening a pull request!

Ideas for future examples:
- Python version of the scheduler
- Home Assistant integration
- Temperature monitoring with automatic adjustments
- Prometheus metrics exporter
- Discord/Slack notifications for temperature alerts
