# Enhanced Features for iLO Fans Controller

This document describes the advanced features available for the iLO Fans Controller.

## Overview

The enhanced features add powerful functionality while maintaining the simplicity of the original tool:

- **Real-time temperature monitoring**
- **System health dashboard**
- **Quick action buttons**
- **Historical data charts**
- **Keyboard shortcuts**
- **Configuration backup/restore**
- **Notifications system**
- **Auto-refresh**
- **PWM value display**

## Installation

### Option 1: Automatic Integration (Recommended)

The enhanced features are automatically included if you use the standard `ilo-fans-controller.php` file. All features work out of the box!

### Option 2: Manual Integration

If you're using a custom setup or want to selectively enable features:

1. **Include the JavaScript enhancements:**
   ```html
   <script defer src="enhancements.js"></script>
   ```

2. **Optionally include Chart.js for historical charts:**
   ```html
   <script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
   ```

3. **The enhanced UI components** are built into the main file, but you can customize them using `enhanced-ui.html` as a reference.

## Features

### 🌡️ Temperature Monitoring

**What it does:**
- Shows real-time temperatures from all sensors
- Color-coded status indicators (green/yellow/red)
- Warning thresholds based on iLO data

**How to use:**
- Temperatures automatically appear above the fan controls
- Each sensor shows current temp and maximum threshold
- Status colors indicate: OK (green), Warning (yellow), Critical (red)

**API Endpoints:**
```bash
# Get all temperatures
curl http://your-server/index.php?api=temperatures

# Get complete thermal data (fans + temperatures)
curl http://your-server/index.php?api=thermal
```

---

### 💚 Health Status Dashboard

**What it does:**
- Overall system health indicator
- Real-time monitoring of fan status
- Temperature warnings and errors
- iLO connection status

**How to use:**
- Health badge appears at the top of the page
- Click on warnings/errors to see details
- Auto-updates every 30 seconds

**Health States:**
- **Healthy** (green): Everything operating normally
- **Warning** (yellow): Temperature approaching threshold
- **Critical** (red): Fan failure or temperature exceeded

**API Endpoint:**
```bash
curl http://your-server/index.php?api=health
```

**Response:**
```json
{
  "status": "healthy",
  "ilo_connection": "ok",
  "last_update": "2025-11-10T15:30:00+00:00",
  "fans": {
    "total": 6,
    "responding": 6,
    "errors": 0
  },
  "temperatures": {
    "count": 12,
    "max": 58
  },
  "warnings": [],
  "errors": []
}
```

---

### ⚡ Quick Actions

**What they do:**
Instant fan speed presets with one click

**Available Actions:**
- **Mute All** (🔇): Set all fans to 15% (quiet mode)
- **Normal** (⚙️): Set all fans to 50% (balanced)
- **Boost All** (⚡): Set all fans to 100% (maximum cooling)
- **Export** (💾): Download configuration backup
- **Import** (📤): Restore configuration from file

**Keyboard Shortcuts:**
- `Alt + M`: Mute all
- `Alt + N`: Normal
- `Alt + B`: Boost all
- `Alt + E`: Export config

---

### 📊 Historical Charts

**What it does:**
- Visual representation of fan speeds over time
- Temperature trends
- Zoom in/out (1h, 6h, 24h, 7d)
- Multiple datasets (one per fan)

**How to use:**
1. Click "Show Historical Data" button
2. Select time range (1h, 6h, 24h, 7d)
3. Chart updates automatically

**Data Retention:**
- History stored in `data/history.json`
- Keeps last 7 days of data
- One entry per page load (approximate 5-min intervals)

**API Endpoint:**
```bash
# Get history for last 24 hours
curl http://your-server/index.php?api=history&range=24h

# Available ranges: 1h, 6h, 24h, 7d
```

---

### ⌨️ Keyboard Shortcuts

**Global Shortcuts:**
- `Ctrl/Cmd + S`: Apply fan speeds
- `Alt + R`: Refresh page

**Quick Actions:**
- `Alt + M`: Mute all (15%)
- `Alt + N`: Normal (50%)
- `Alt + B`: Boost all (100%)
- `Alt + E`: Export configuration

**Presets:**
- `1-9`: Apply preset 1-9

**Notes:**
- Shortcuts don't work when typing in input fields
- Works on all modern browsers

---

### 💾 Configuration Backup & Restore

**Export:**
- Downloads JSON file with all presets and current state
- Includes version information
- Timestamped filename

**Import:**
- Upload previously exported JSON file
- Automatically restores all presets
- Page reloads after successful import

**File Format:**
```json
{
  "version": "2.0.0",
  "export_date": "2025-11-10T15:30:00Z",
  "presets": [
    {
      "name": "Silent Mode",
      "speeds": [15]
    }
  ],
  "data": {
    "fans": {...},
    "temperatures": {...}
  }
}
```

---

### 🔔 Notifications System

**What it does:**
- Non-intrusive toast notifications
- Auto-dismiss after timeout
- Color-coded by type

**Notification Types:**
- **Info** (blue): General information
- **Success** (green): Operation successful
- **Warning** (yellow): Caution required
- **Error** (red): Something went wrong

**Programmatic Usage:**
```javascript
// From browser console or custom scripts
Alpine.store('notifications').success('Fans updated successfully');
Alpine.store('notifications').error('Failed to connect to iLO');
Alpine.store('notifications').warning('Temperature approaching limit');
Alpine.store('notifications').info('Auto-refresh enabled');
```

---

### 🔄 Auto-Refresh

**What it does:**
- Automatically updates fan speeds, temperatures, and health
- Configurable interval
- Can be stopped/started programmatically

**Default Behavior:**
- Refreshes every 60 seconds
- Updates fans, temperatures, and health status

**Control:**
```javascript
// Start auto-refresh (60-second interval)
window.iloEnhancements.startAutoRefresh(60);

// Stop auto-refresh
window.iloEnhancements.stopAutoRefresh();

// Change interval to 30 seconds
window.iloEnhancements.startAutoRefresh(30);
```

---

### 📐 PWM Value Display

**What it does:**
- Shows PWM (Pulse Width Modulation) values alongside percentages
- PWM range: 0-255 (where 255 = 100%)
- Useful for advanced users and PID configuration

**Display:**
```
Fan 1: [=====>    ] 50% (128 PWM)
```

**Conversion:**
- 15% = 38 PWM
- 50% = 128 PWM
- 100% = 255 PWM

---

### 📝 Activity Logging

**What it does:**
- Logs all fan speed changes
- Tracks preset updates
- Records IP addresses
- Timestamps all actions

**Storage:**
- Logs saved in `data/logs.json`
- Keeps last 1000 entries
- Oldest entries automatically removed

**API Endpoint:**
```bash
# Get last 100 log entries
curl http://your-server/index.php?api=logs&limit=100
```

**Log Format:**
```json
[
  {
    "timestamp": "2025-11-10T15:30:00+00:00",
    "action": "set_fan_speeds",
    "details": {
      "fans": {"Fan 1": 50, "Fan 2": 50},
      "updated_count": 2
    },
    "ip": "192.168.1.100"
  }
]
```

---

## REST API Reference

All API endpoints support JSON responses.

### GET Endpoints

| Endpoint | Description | Example |
|----------|-------------|---------|
| `?api=fans` | Get current fan speeds | `{"Fan 1": 45, "Fan 2": 50}` |
| `?api=temperatures` | Get all temperatures | `{"CPU": {"current": 52, ...}}` |
| `?api=thermal` | Get fans + temperatures | Combined data |
| `?api=presets` | Get saved presets | List of presets |
| `?api=health` | Get system health | Health status object |
| `?api=history&range=24h` | Get historical data | Array of entries |
| `?api=logs&limit=100` | Get activity logs | Array of log entries |
| `?api=export` | Export configuration | Downloads JSON file |

### POST Endpoints

| Action | Data | Description |
|--------|------|-------------|
| `fans` | `{"action": "fans", "fans": {...}}` | Set fan speeds |
| `presets` | `{"action": "presets", "presets": [...]}` | Update presets |

---

## Programmatic Access

The enhanced features expose a global `window.iloEnhancements` object with utility functions:

```javascript
// Get current temperatures
const temps = await window.iloEnhancements.getTemperatures();

// Get system health
const health = await window.iloEnhancements.getHealth();

// Get historical data
const history = await window.iloEnhancements.getHistory('24h');

// Get activity logs
const logs = await window.iloEnhancements.getLogs(50);

// Export configuration
window.iloEnhancements.exportConfig();

// Control auto-refresh
window.iloEnhancements.startAutoRefresh(30);  // 30 seconds
window.iloEnhancements.stopAutoRefresh();
```

---

## Alpine.js Stores

Enhanced features add several Alpine.js stores:

### `$store.temperatures`
```javascript
$store.temperatures.temps          // All temperature data
$store.temperatures.getTemp(name)  // Get specific temperature
$store.temperatures.getStatus(name) // Get status (ok/warning/critical)
$store.temperatures.fetch()        // Manually refresh
```

### `$store.health`
```javascript
$store.health.status              // Overall status
$store.health.data                // Complete health data
$store.health.hasWarnings()       // Check for warnings
$store.health.hasErrors()         // Check for errors
$store.health.fetch()             // Manually refresh
```

### `$store.quickActions`
```javascript
$store.quickActions.muteAll()     // Set all to 15%
$store.quickActions.normalAll()   // Set all to 50%
$store.quickActions.boostAll()    // Set all to 100%
```

### `$store.charts`
```javascript
$store.charts.fetchHistory()      // Load historical data
$store.charts.changeRange('24h')  // Change time range
$store.charts.history             // Raw history data
```

### `$store.notifications`
```javascript
$store.notifications.success('Message')  // Show success
$store.notifications.error('Message')    // Show error
$store.notifications.warning('Message')  // Show warning
$store.notifications.info('Message')     // Show info
```

### `$store.backup`
```javascript
$store.backup.exportConfig()      // Export configuration
$store.backup.importConfig(file)  // Import from file
```

---

## Customization

### Disable Auto-Refresh

Add to your HTML:
```javascript
<script>
document.addEventListener('DOMContentLoaded', () => {
    window.iloEnhancements.stopAutoRefresh();
});
</script>
```

### Change Auto-Refresh Interval

```javascript
// Refresh every 30 seconds instead of 60
window.iloEnhancements.startAutoRefresh(30);
```

### Custom Notification Styling

Notifications use Tailwind CSS classes. Modify `enhanced-ui.html` to customize.

### Disable Specific Features

Remove or comment out the corresponding HTML sections in `enhanced-ui.html`.

---

## Troubleshooting

### Charts Not Showing

**Problem:** Historical chart doesn't appear
**Solution:** Include Chart.js:
```html
<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
```

### Temperatures Not Loading

**Problem:** Temperature cards are empty
**Solution:** Check that:
1. Your iLO firmware supports temperature reading
2. The Redfish API endpoint `/redfish/v1/chassis/1/Thermal` is accessible
3. Browser console for any errors

### Keyboard Shortcuts Not Working

**Problem:** Shortcuts don't respond
**Solution:**
1. Make sure you're not in an input field
2. Check browser console for errors
3. Ensure `enhancements.js` is loaded

### History Data Missing

**Problem:** No historical data available
**Solution:**
1. History builds over time with each page load
2. Check that `data/` directory is writable
3. Wait a few minutes and refresh

---

## Performance Considerations

- **History Storage:** Limited to 7 days (~2000 entries)
- **Log Storage:** Limited to 1000 entries
- **Auto-Refresh:** Default 60 seconds (adjustable)
- **File Sizes:** JSON files are compressed and efficient

---

## Security Notes

- All API endpoints respect existing authentication
- Logs include IP addresses for audit trail
- Export/Import uses client-side file operations (secure)
- No data sent to external services

---

## Browser Compatibility

- ✅ Chrome/Edge 90+
- ✅ Firefox 88+
- ✅ Safari 14+
- ✅ Mobile browsers (iOS Safari, Chrome Mobile)

---

## Future Enhancements

Planned features for future releases:

- [ ] WebSocket real-time updates (eliminate polling)
- [ ] Email/webhook notifications for alerts
- [ ] Prometheus metrics exporter
- [ ] Multi-server dashboard
- [ ] Mobile app companion
- [ ] Machine learning optimization
- [ ] Home Assistant integration

---

## Contributing

Have ideas for enhancements? Open an issue or pull request on GitHub!

## Support

For issues or questions:
1. Check this documentation first
2. Review browser console for errors
3. Open an issue on GitHub with details
4. Include browser version and error messages

---

**Version:** 2.0.0
**Last Updated:** 2025-11-10
**License:** Same as main project
