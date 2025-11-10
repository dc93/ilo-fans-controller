# Advanced Features Guide (v2.5+)

This document covers advanced features for power users and enterprise deployments.

## Table of Contents

1. [Real-time WebSocket Updates](#real-time-websocket-updates)
2. [Email Notifications](#email-notifications)
3. [Mobile App Experience](#mobile-app-experience)
4. [Machine Learning Optimization](#machine-learning-optimization)
5. [Troubleshooting](#troubleshooting)

---

## Real-time WebSocket Updates

Replace polling with real-time push updates for instant data refresh and reduced server load.

### Features

- **Real-time Updates**: Push-based updates every 5 seconds (configurable)
- **Auto-reconnect**: Automatic reconnection with exponential backoff
- **Fallback**: Graceful degradation to polling if WebSocket unavailable
- **Low Latency**: Sub-second update delivery
- **Efficient**: Reduces API calls by 90% compared to polling

### Installation

**Step 1: Start WebSocket Server**

```bash
# Make executable
chmod +x websocket-server.php

# Test manually
php websocket-server.php

# Or install as systemd service
sudo cp websocket-server.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable websocket-server
sudo systemctl start websocket-server
sudo systemctl status websocket-server
```

**Step 2: Add Client Script**

Edit your `index.php` and add before `</body>`:

```html
<!-- WebSocket real-time updates -->
<script src="websocket-client.js"></script>
```

**Step 3: Configure Firewall**

```bash
# Allow WebSocket port (default: 8080)
sudo ufw allow 8080/tcp
```

### Configuration

Edit `websocket-server.php` to customize:

```php
define('WEBSOCKET_PORT', 8080);      // Port to listen on
define('UPDATE_INTERVAL', 5);        // Seconds between updates
define('LOG_FILE', '/var/log/ilo-websocket.log');
```

Or use environment variables:

```bash
# Docker
docker run -e WEBSOCKET_PORT=8080 ...

# Systemd
echo "Environment=WEBSOCKET_PORT=8080" >> /etc/systemd/system/websocket-server.service
```

### Monitoring

```bash
# Check service status
systemctl status websocket-server

# View logs
journalctl -u websocket-server -f

# Or tail log file
tail -f /var/log/ilo-websocket.log

# Check active connections
netstat -an | grep 8080 | grep ESTABLISHED | wc -l
```

### Docker Support

```yaml
# docker-compose.yaml
services:
  ilo-fans-controller:
    # ... existing config ...

  websocket-server:
    image: ghcr.io/alex3025/ilo-fans-controller:latest
    command: php websocket-server.php
    ports:
      - "8080:8080"
    environment:
      - ILO_HOST=${ILO_HOST}
      - ILO_USERNAME=${ILO_USERNAME}
      - ILO_PASSWORD=${ILO_PASSWORD}
      - WEBSOCKET_PORT=8080
    restart: always
```

### Troubleshooting

**Connection refused:**
- Check if WebSocket server is running: `systemctl status websocket-server`
- Verify port is accessible: `telnet localhost 8080`
- Check firewall: `sudo ufw status`

**High CPU usage:**
- Increase `UPDATE_INTERVAL` in config
- Limit number of concurrent connections
- Check for connection leak

**Browser doesn't connect:**
- Check browser console for errors
- Verify WebSocket URL is correct
- Try different browser (Chrome/Firefox)

---

## Email Notifications

Get critical alerts via email with HTML formatting and smart cooldown.

### Features

- **HTML Emails**: Beautiful, styled email alerts
- **Multiple Platforms**: Support for system mail, external SMTP (Gmail, etc.)
- **Smart Cooldown**: Prevents alert spam (default: 1 hour)
- **Severity Levels**: Different colors for info/warning/critical
- **Detailed Reports**: Includes temperature values, thresholds, timestamps

### Installation

**Step 1: Install Mail Utilities**

```bash
# Ubuntu/Debian
sudo apt-get install mailutils

# Or for Postfix
sudo apt-get install postfix mailutils

# RHEL/CentOS
sudo yum install mailx
```

**Step 2: Configure Script**

```bash
# Copy script
cp examples/email-notifier.sh /usr/local/bin/
chmod +x /usr/local/bin/email-notifier.sh

# Edit configuration
nano /usr/local/bin/email-notifier.sh
```

**Step 3: Configure Email Settings**

```bash
# Basic settings
EMAIL_TO="admin@example.com"
EMAIL_FROM="ilo-monitor@example.com"
ILO_URL="http://localhost:8000/index.php"

# For Gmail/external SMTP
USE_EXTERNAL_SMTP=true
SMTP_HOST="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER="your-email@gmail.com"
SMTP_PASS="your-app-password"  # Use App Password, not account password!
SMTP_TLS=true
```

**Step 4: Test**

```bash
# Test email delivery
/usr/local/bin/email-notifier.sh

# Check logs
tail -f /tmp/ilo-email-notifier.state
```

**Step 5: Schedule**

```bash
# Add to crontab (check every 5 minutes)
crontab -e

# Add this line:
*/5 * * * * /usr/local/bin/email-notifier.sh >> /var/log/ilo-email.log 2>&1
```

### Gmail Setup

1. **Enable 2-Factor Authentication** in your Google Account
2. **Generate App Password**:
   - Go to https://myaccount.google.com/apppasswords
   - Select "Mail" and "Other (Custom name)"
   - Copy the 16-character password
3. **Update script** with App Password (NOT your account password)

### Alert Types

| Alert Type | Threshold | Cooldown | Description |
|------------|-----------|----------|-------------|
| Health Critical | Status = critical | 1 hour | System in critical state |
| Health Warning | Status = warning | 1 hour | System has warnings |
| Temp Critical | Temp > 80°C | 1 hour per sensor | Critical temperature |
| Temp Warning | Temp > 70°C | 1 hour per sensor | High temperature |

### Customizing Alerts

Edit thresholds in `email-notifier.sh`:

```bash
TEMP_WARNING=70          # Warning threshold (°C)
TEMP_CRITICAL=80         # Critical threshold (°C)
COOLDOWN_PERIOD=3600     # Time between alerts (seconds)
```

### Email Templates

The script uses HTML templates with color-coding:

- 🔵 **Blue** - Informational
- 🟠 **Orange** - Warning
- 🔴 **Red** - Critical

Customize by editing the `format_html_email()` function in the script.

---

## Mobile App Experience

Native app-like experience with PWA, gestures, haptics, and offline support.

### Features

- ✅ **Install to Home Screen**: Works like a native app
- ✅ **Offline Support**: Full functionality without internet
- ✅ **Touch Gestures**: Swipe, long-press, pull-to-refresh
- ✅ **Haptic Feedback**: Vibration on button press
- ✅ **Native Sharing**: Share configs via iOS/Android share sheet
- ✅ **Status Bar Theming**: Color changes based on system health
- ✅ **Screen Wake Lock**: Prevents screen timeout during monitoring
- ✅ **URL Actions**: Deep links for quick actions (e.g., `/?action=mute`)

### Installation

**Option 1: Include in HTML**

Add to `index.php` before `</body>`:

```html
<!-- Mobile enhancements -->
<script src="mobile-enhancements.js"></script>
```

**Option 2: Docker**

Already included in the Docker image!

### Installing as App

**iOS (Safari):**
1. Open the controller in Safari
2. Tap Share button (📤)
3. Tap "Add to Home Screen"
4. Tap "Add"

**Android (Chrome):**
1. Open the controller in Chrome
2. Tap menu (⋮)
3. Tap "Install app" or "Add to Home screen"
4. Tap "Install"

**Desktop (Chrome/Edge):**
1. Look for install icon (➕) in address bar
2. Click "Install"
3. App opens in standalone window

### Gestures

| Gesture | Action |
|---------|--------|
| **Swipe Right** | Navigate forward (customizable) |
| **Swipe Left** | Navigate back (customizable) |
| **Long Press** | Show context menu (with haptic feedback) |
| **Pull Down** | Refresh page |

### Deep Links

Create home screen shortcuts with direct actions:

```
https://your-server/?action=mute    → Mute all fans
https://your-server/?action=normal  → Normal mode
https://your-server/?action=boost   → Boost all fans
```

### Customizing

Edit `mobile-enhancements.js` to customize behavior:

```javascript
// Change install banner appearance
showInstallBanner() {
    // Customize banner HTML
}

// Change gesture actions
onSwipeRight() {
    // Your custom action
}

// Change haptic intensity
vibrate(100);  // milliseconds
```

### Browser Support

| Feature | Chrome | Safari | Firefox | Edge |
|---------|--------|--------|---------|------|
| PWA Install | ✅ | ✅ | ✅ | ✅ |
| Offline | ✅ | ✅ | ✅ | ✅ |
| Gestures | ✅ | ✅ | ✅ | ✅ |
| Haptics | ✅ | ✅ | ❌ | ✅ |
| Share API | ✅ | ✅ | ❌ | ✅ |
| Wake Lock | ✅ | ❌ | ❌ | ✅ |

---

## Machine Learning Optimization

Use ML to analyze patterns and optimize fan profiles automatically.

### Features

- **Pattern Analysis**: Discover temperature and usage patterns
- **Smart Profiles**: Auto-generate quiet/balanced/performance profiles
- **Predictive**: Predict temperature trends 1 hour ahead
- **Anomaly Detection**: Detect unusual temperature spikes
- **Recommendations**: Get actionable optimization tips

### Installation

**Step 1: Install Dependencies**

```bash
# Python 3 and pip
sudo apt-get install python3 python3-pip

# ML libraries
pip3 install numpy pandas scikit-learn matplotlib requests
```

**Step 2: Configure**

```bash
# Set API URL
export ILO_API_URL="http://localhost:8000/index.php"

# Make executable
chmod +x ml-optimizer.py
```

### Usage

**Analyze Patterns:**

```bash
# Analyze 7 days of data
./ml-optimizer.py --analyze

# Analyze specific period
./ml-optimizer.py --analyze --days 30

# Save results to JSON
./ml-optimizer.py --analyze --output results.json
```

**Generate Optimized Profiles:**

```bash
# Find optimal fan speed profiles
./ml-optimizer.py --optimize

# Generates: quiet, balanced, performance profiles
```

**Predict Temperatures:**

```bash
# Predict next hour trends
./ml-optimizer.py --predict

# Output:
# CPU Inlet: 55°C → 57°C (trend: increasing)
# Exhaust: 62°C → 61°C (trend: stable)
```

**Train Custom Model:**

```bash
# Train ML model for predictions
./ml-optimizer.py --train

# Model saved to: data/ml_model.json
```

**All-in-One:**

```bash
# Run all analyses
./ml-optimizer.py --analyze --optimize --predict --train --output full_report.json
```

### Automated Optimization

Run daily to continuously improve:

```bash
# Add to crontab
crontab -e

# Run at 3 AM daily
0 3 * * * /path/to/ml-optimizer.py --analyze --optimize >> /var/log/ml-optimizer.log 2>&1
```

### Understanding Output

**Pattern Analysis:**
```
Temperature Statistics:
  CPU_Inlet: mean=55.2°C, min=45°C, max=68°C, std=5.3°C
  Exhaust: mean=62.1°C, min=52°C, max=75°C, std=6.1°C

Recommendations:
  ⚡ CPU_Inlet averages 55°C - you may be over-cooling
  💡 Fan 1 speed varies little (±3%) - consider PID control
```

**Optimized Profiles:**
```
QUIET Profile (avg temp: 52°C):
  Fan 1: 25%, Fan 2: 30%, Fan 3: 25%
  Based on 1,234 samples

BALANCED Profile (avg temp: 62°C):
  Fan 1: 45%, Fan 2: 50%, Fan 3: 45%
  Based on 2,456 samples

PERFORMANCE Profile (avg temp: 72°C):
  Fan 1: 75%, Fan 2: 80%, Fan 3: 75%
  Based on 789 samples
```

**Temperature Predictions:**
```
CPU_Inlet:
  Current: 55.2°C
  Predicted (+1h): 57.1°C
  Trend: increasing (+0.32°C/sample)
```

### Applying Profiles

Use the generated profiles to create presets:

1. Run `./ml-optimizer.py --optimize`
2. Note the fan speeds for each profile
3. In web UI, create presets with those speeds
4. Or use API:

```bash
# Apply "quiet" profile
curl -X POST http://localhost:8000/index.php \
  -H 'Content-Type: application/json' \
  -d '{"action":"fans","fans":{"Fan 1":25,"Fan 2":30,"Fan 3":25}}'
```

### Advanced Configuration

Edit `ml-optimizer.py` for custom behavior:

```python
# Change API endpoint
ILO_API_URL = 'http://your-server:8000/index.php'

# Change data file location
DATA_FILE = '/custom/path/history.json'

# Adjust optimization parameters
kmeans = KMeans(n_clusters=5)  # More profiles
```

### Visualization

Generate charts (requires matplotlib):

```python
# Add to script
import matplotlib.pyplot as plt

# Plot temperature trends
plt.plot(df['timestamp'], df['temp_CPU_Inlet'])
plt.title('CPU Temperature Over Time')
plt.savefig('temperature_trend.png')
```

---

## Troubleshooting

### WebSocket Issues

**Q: WebSocket won't connect**
- Check service: `systemctl status websocket-server`
- Check logs: `journalctl -u websocket-server`
- Test port: `telnet localhost 8080`
- Check firewall: `sudo ufw allow 8080`

**Q: High CPU usage**
- Increase update interval
- Reduce number of connected clients
- Check for memory leaks

### Email Issues

**Q: Emails not sending**
- Test mail command: `echo "test" | mail -s "test" user@example.com`
- Check mail logs: `tail -f /var/log/mail.log`
- Verify SMTP credentials (use App Password for Gmail)

**Q: Too many emails**
- Increase cooldown period
- Adjust alert thresholds
- Check state file: `/tmp/ilo-email-notifier.state`

### Mobile Issues

**Q: Install button not showing**
- Use HTTPS (required for PWA)
- Check manifest.json is accessible
- Clear browser cache
- Try different browser

**Q: Offline mode not working**
- Check service worker registration
- Clear service worker: Developer Tools → Application → Service Workers
- Verify HTTPS connection

### ML Issues

**Q: Not enough data**
- Wait for more historical data (minimum 24 hours)
- Reduce `--days` parameter
- Check data file exists: `ls -l data/history.json`

**Q: Poor predictions**
- Need more training data (7+ days recommended)
- Workload too variable
- Check for data quality issues

---

## Support

For questions or issues with advanced features:

1. Check [GitHub Issues](https://github.com/alex3025/ilo-fans-controller/issues)
2. Review logs: `/var/log/ilo-*.log`
3. Enable debug mode in scripts
4. Open a new issue with logs and configuration

---

## Version History

- **v2.5** - Added WebSocket, email, mobile, ML features
- **v2.0** - Enhanced features package
- **v1.0** - Initial release

[← Back to main README](README.md) | [Enhanced Features →](ENHANCED_FEATURES.md)
