<h1 align="center">iLO Fans Controller</h1>

<p align="center">
  <img width="800" src="screenshot.png" alt="Webpage Screenshot">
  <br>
  <i>Easily manage your HP's server fans speeds, anywhere!</i>
</p>

---

<h3 align="center"> 🎉 Thank you so much for the <code>1.000+</code> container pulls! 🎉 </h3>

> ℹ **NOTE:** The v1.0.0 is a **complete rewrite** of the tool, so any feedback is appreciated!<br>
> If you find any bug or have any suggestion, please [open an issue](https://github.com/alex3025/ilo-fans-controller/issues). Thanks! 😄

## FAQ

### How does it work? 🛠

This tool is a **single PHP script** that uses the `php-curl` extension to **get the current server fan speeds from the iLO REST api** and the `php-ssh2` extension to **set the fan speeds using the [patched iLO SSH interface](#can-i-use-this-tool-with-my-hp-server-%EF%B8%8F).** You can also **create custom presets** to set a specific fan configuration with a single click, all with a **simple and clean web interface** made using [Alpine.js](https://alpinejs.dev/) and [TailwindCSS](https://tailwindcss.com/).

### Can I use this tool with my HP server? 🖥️

This tool requires a **patched iLO firmware** that expose to the iLO SSH interface some commands to manipulate the fans speeds. You can find more information about this patch on [this Reddit post](https://www.reddit.com/r/homelab/comments/sx3ldo/hp_ilo4_v277_unlocked_access_to_fan_controls/).

As of now, the patch (and so this tool) only works for **Gen8 & Gen9 servers with iLO 4.**

> Gen10 servers with iLO 5 are not supported at the moment.

### I prefer the _original version™_, can I still use it?

Sure, although I spent a lot of time rewriting the tool from scratch so I would recommend using this version instead.

Anyway, you can download the _original version™_ from the [GitHub releases](https://github.com/alex3025/ilo-fans-controller/releases/tag/0.0.1) page.

### Why PHP? And why a single file? 📄

**Answer #1:**
In my opinion, PHP is perfect for this type of tasks where you need to do some server-side things and something easy to deploy (you just need a web server with PHP installed).

**Answer #2:**
I wanted to make this tool as easy as possible to install and use, so I decided to put everything in a single file.

### Why did you make this? 🤔

See my [original comment on r/homelab](https://www.reddit.com/r/homelab/comments/rcel73/comment/hnu3iyp/?utm_source=share&utm_medium=web2x&context=3) to know the story behind this tool!

### How can I offer you a coffee? ☕

If you found this tool useful, consider offering me a coffee using [PayPal](https://paypal.me/alex3025) or via [GitHub Sponsors](https://github.com/sponsors/alex3025) to support my work! Thank you so much! 🙏

---

## Use with Docker / Docker Compose

If you already have a Docker environment, you can be up and running in minutes using the following command (obviously you need to change the value):

```sh
docker run -d --name ilo-fans-controller --restart always \
    -p 8000:80 \
    -e ILO_HOST='your-ilo-address' \
    -e ILO_USERNAME='your-ilo-username' \
    -e ILO_PASSWORD='your-ilo-password' \
    ghcr.io/alex3025/ilo-fans-controller:latest
```

Or if you prefer, you can use `docker compose`, as the [docker-compose.yaml](https://github.com/alex3025/ilo-fans-controller/blob/main/docker-compose.yaml) file is provided as well.

> 💡 **TIP:** For advanced use cases like automated scheduling or PID-based fan control, check out the [Advanced Usage & Examples](#advanced-usage--examples) section below!

---

> ⚠ **IMPORTANT!** ⚠
>
> Again, this tool works thanks to a **[patched iLO firmware](#can-i-use-this-tool-with-my-hp-server-%EF%B8%8F)** that expose to the iLO SSH interface some commands to manipulate the fans speeds.
>
> **This patch is required to use this tool!**

## Manual installation

### The following guide was run on

* An **HP DL380e G8** server
* **Patched iLO 4** Advanced **v2.77** (07 December 2020)
* A Proxmox container (LXC) running **Ubuntu 22.04**
* **Apache 2** & **PHP 8.1**

### Preparing the environment

1. Update the system:

    ```sh
    sudo apt-get update && sudo apt-get upgrade
    ```

2. Install the required packages (`apache2`, `php8.1`, `php8.1-curl` and `php8.1-ssh2`):

    ```sh
    sudo apt-get install apache2 php8.1 php8.1-curl php8.1-ssh2
    ```

### Downloading the tool

1. Download and extract the latest source code using `wget` and `tar`:

    ```sh
    wget -qL https://github.com/alex3025/ilo-fans-controller/archive/refs/tags/1.0.0.tar.gz -O - | tar -xz
    ```

2. Enter the directory:

    ```sh
    cd ilo-fans-controller-1.0.0
    ```

### Configuring and installing the tool

1. Open the `config.inc.php` file you favourite text editor and change the variables according to your configuration.

    > ℹ **NOTE:** Remember that `$ILO_HOST` is the IP address of your iLO interface, not of the server itself.

    > ℹ **NOTE:** It's recommended to create a new iLO user with the minimum privileges required to access the SSH interface and the REST api (Remote Console Access).

    Here is an example:

    ```php
    <?php

    /*
    ILO ACCESS CREDENTIALS
    --------------
    These are used to connect to the iLO
    interface and manage the fan speeds.
    */

    $ILO_HOST = '192.168.1.69';
    $ILO_USERNAME = 'Administrator';
    $ILO_PASSWORD = 'AdministratorPassword1234';

    /*
    SSH KEY AUTHENTICATION (OPTIONAL)
    --------------
    If you prefer SSH key authentication instead of password,
    specify the paths to your public and private key files.
    Leave empty to use password authentication (default).
    */

    $ILO_SSH_PUBLIC_KEY = '';   // Ex. /path/to/id_rsa.pub
    $ILO_SSH_PRIVATE_KEY = '';  // Ex. /path/to/id_rsa
    $ILO_SSH_KEY_PASSPHRASE = '';  // Leave empty if key has no passphrase

    ?>
    ```

    > 🔐 **SSH Key Authentication:** For improved security, you can use SSH keys instead of passwords. Simply specify the paths to your public and private key files in the configuration. The password will only be used as a fallback if key authentication is not configured or fails.

2. When you're done, create a new subdirectory in your web server root directory (usually `/var/www/html/`) and copy the `config.inc.php`, `ilo-fans-controller.php` and `favicon.ico` to it:

    ```sh
    sudo mkdir /var/www/html/ilo-fans-controller
    sudo cp config.inc.php ilo-fans-controller.php favicon.ico /var/www/html/ilo-fans-controller/
    ```

    Then rename `ilo-fans-controller.php` to `index.php` (to make it work without specifying the filename in the URL):

    ```sh
    sudo mv /var/www/html/ilo-fans-controller/ilo-fans-controller.php /var/www/html/ilo-fans-controller/index.php
    ```

3. That's it! Now you can reach the tool at `http://<your-server-ip>/ilo-fans-controller/` (or `http://<your-server-ip>/ilo-fans-controller/index.php` for API requests).

> ℹ **NOTE:** If the web server where you installed this tool **will be reachable from outside your network**, remember to **setup some sort of authentication** (like Basic Auth) to prevent _unauthorized fan management at 2AM_.

---

## Troubleshooting

The first thing to do when you encounter a problem is to **check the logs**.

> If you are using Apache, PHP errors are logged in the `/var/log/apache2/error.log` file.

If you think you found a bug, please [open an issue](https://github.com/alex3025/ilo-fans-controller/issues) and I'll take a look.

Below you can find some common problems and their solutions.

### The presets are not saved

If you see the following error in the logs when you create a new preset:

```log
PHP Warning:  file_put_contents(presets.json): Failed to open stream: Permission denied in .../index.php on line X
```

This is probably because the `presets.json` file is not writable by the web server user.<br>
To fix this, run the following command to change the file owner to `www-data` (the default Apache user):

```sh
sudo chown www-data:www-data /var/www/html/ilo-fans-controller/presets.json
```

---

## ✨ Enhanced Features (v2.0+)

The tool now includes powerful advanced features built right in:

### 🚀 Advanced Features (v2.5+)

**NEW** in v2.5 - Cutting-edge features for power users:

- ⚡ **Real-time WebSocket Updates** - Push-based updates, 90% less server load
- 📧 **Email Notifications** - HTML alerts via SMTP or system mail
- 📱 **Native Mobile App** - Gestures, haptics, offline support, install to home screen
- 🤖 **ML Optimization** - AI-powered fan profile optimization and predictions

[→ See ADVANCED_FEATURES.md for full documentation](ADVANCED_FEATURES.md)

### Core Features
- 🌡️ **Real-time Temperature Monitoring** - See sensor temps alongside fan speeds
- 💚 **System Health Dashboard** - Overall status with warnings and errors
- ⚡ **Quick Action Buttons** - Mute/Normal/Boost all fans with one click
- 📊 **Historical Charts** - Visualize fan speeds over time (1h to 7d)
- ⌨️ **Keyboard Shortcuts** - Control everything from your keyboard
- 💾 **Backup & Restore** - Export/import your configuration
- 🔔 **Smart Notifications** - Toast messages for all actions
- 🔄 **Auto-Refresh** - Real-time updates every 60 seconds
- 📐 **PWM Value Display** - See exact PWM values (0-255)
- 📝 **Activity Logging** - Track all changes with timestamps

### Integration & Monitoring
- 📱 **Progressive Web App (PWA)** - Install on desktop/mobile, works offline
- 📈 **Prometheus Metrics** - Enterprise monitoring with `/metrics` endpoint
- 🔔 **Webhook Alerts** - Discord, Slack, Teams notifications for critical events
- 🏠 **Home Assistant** - Complete integration with sensors and automations
- 🖥️ **Multi-Server Support** - Manage multiple iLO servers (see [MULTI_SERVER.md](MULTI_SERVER.md))

### Tools & Utilities
- ⚙️ **Automated Install Script** - One-command setup with `install.sh`
- 📖 **Interactive API Docs** - Test all endpoints in your browser
- 🕒 **Scheduler Examples** - Time-based automation for day/night profiles
- 🎛️ **PID Control Setup** - Temperature-curve based dynamic fan control

**All features work out of the box!** Just use the standard installation.

For detailed documentation, see:
- [ADVANCED_FEATURES.md](ADVANCED_FEATURES.md) - **NEW** WebSocket, Email, Mobile, ML features
- [ENHANCED_FEATURES.md](ENHANCED_FEATURES.md) - Complete feature guide
- [API_DOCS.html](API_DOCS.html) - Interactive API documentation
- [MULTI_SERVER.md](MULTI_SERVER.md) - Multi-server management
- [CHANGELOG.md](CHANGELOG.md) - Version history

### Quick Start: Advanced Features

**Enable Real-time WebSocket:**
```bash
# Start WebSocket server
php websocket-server.php

# Or install as service
sudo cp websocket-server.service /etc/systemd/system/
sudo systemctl enable --now websocket-server
```

**Setup Email Alerts:**
```bash
# Configure and test
cp examples/email-notifier.sh /usr/local/bin/
nano /usr/local/bin/email-notifier.sh  # Edit EMAIL_TO, ILO_URL
chmod +x /usr/local/bin/email-notifier.sh
/usr/local/bin/email-notifier.sh  # Test

# Schedule (every 5 minutes)
echo "*/5 * * * * /usr/local/bin/email-notifier.sh" | crontab -
```

**Install as Mobile App:**
- **iOS**: Safari → Share → Add to Home Screen
- **Android**: Chrome → Menu → Install app
- **Desktop**: Look for install icon (➕) in address bar

**Optimize with ML:**
```bash
# Install Python dependencies
pip3 install numpy pandas scikit-learn requests

# Run analysis
./ml-optimizer.py --analyze --optimize --predict
```

### Quick Feature Overview

**Keyboard Shortcuts:**
- `Ctrl/Cmd + S` - Apply speeds
- `Alt + M` - Mute all (15%)
- `Alt + N` - Normal (50%)
- `Alt + B` - Boost all (100%)
- `Alt + E` - Export config
- `1-9` - Apply preset 1-9

**API Endpoints:**
```bash
# Get temperatures
curl http://your-server/index.php?api=temperatures

# Get system health
curl http://your-server/index.php?api=health

# Get historical data (24 hours)
curl http://your-server/index.php?api=history&range=24h

# Get activity logs
curl http://your-server/index.php?api=logs&limit=100

# Export configuration
curl http://your-server/index.php?api=export > backup.json

# Prometheus metrics (for monitoring)
curl http://your-server/index.php?api=metrics
```

**Installation & Setup:**
```bash
# Quick install with automated script
wget https://raw.githubusercontent.com/alex3025/ilo-fans-controller/main/install.sh
chmod +x install.sh
sudo ./install.sh

# Or use Docker with data persistence
docker run -d --name ilo-fans-controller --restart always \
    -p 8000:80 \
    -e ILO_HOST='your-ilo-address' \
    -e ILO_USERNAME='your-ilo-username' \
    -e ILO_PASSWORD='your-ilo-password' \
    -v ilo-data:/var/www/html/data \
    ghcr.io/alex3025/ilo-fans-controller:latest
```

---

## 🔗 Integrations

### Home Assistant

Complete Home Assistant integration with sensors, controls, and automations.

**Setup:**
1. Copy configuration from `examples/home-assistant.yaml`
2. Add to your Home Assistant `configuration.yaml`
3. Restart Home Assistant

**Features:**
- Temperature and fan speed sensors
- Fan control commands (Mute/Normal/Boost)
- Automated temperature-based fan control
- Silent mode scheduling (night/day)
- Critical health alerts to mobile devices

See [examples/home-assistant.yaml](examples/home-assistant.yaml) for complete configuration.

### Prometheus + Grafana

Enterprise-grade monitoring with metrics and dashboards.

**Quick Start:**
```bash
# Use the included docker-compose.yaml
docker-compose up -d

# Access Grafana at http://localhost:3000
# Prometheus at http://localhost:9090
```

The `/metrics` endpoint provides:
- Fan speeds as Prometheus gauges
- Temperature readings from all sensors
- System health status
- Last update timestamp

See [prometheus.yml](prometheus.yml) for scrape configuration.

### Webhook Notifications

Get instant alerts for critical events via Discord, Slack, or Microsoft Teams.

**Setup:**
```bash
# Copy and configure the notifier
cp examples/webhook-notifier.sh /usr/local/bin/
chmod +x /usr/local/bin/webhook-notifier.sh

# Edit configuration
nano /usr/local/bin/webhook-notifier.sh

# Add to crontab (check every 5 minutes)
echo "*/5 * * * * /usr/local/bin/webhook-notifier.sh" | crontab -
```

**Alerts for:**
- High temperature warnings (>70°C)
- Critical temperature alerts (>80°C)
- Fan failures
- System health changes

See [examples/webhook-notifier.sh](examples/webhook-notifier.sh) for configuration.

### Multi-Server Management

Manage multiple iLO servers from a unified interface.

**Approaches:**
1. **Multiple Docker instances** (recommended for 2-3 servers)
2. **Reverse proxy with path routing** (for 5-10 servers)
3. **Custom unified dashboard** (for custom requirements)
4. **Prometheus + Grafana** (enterprise, 10+ servers)

See [MULTI_SERVER.md](MULTI_SERVER.md) for detailed setup guides and examples.

---

## Advanced Usage & Examples

The [`examples/`](examples/) directory contains scripts and documentation for advanced use cases:

### 📅 Automated Scheduling ([`scheduler.sh`](examples/scheduler.sh))

Automatically apply different fan speed presets based on time of day and day of week. Perfect for:
- **Home labs**: Silent mode at night (9PM-9AM), normal mode during the day
- **Office servers**: Quiet on weekends and after hours
- **Seasonal adjustments**: Adapt to summer heat or winter cooling

**Quick start:**
```bash
# Edit configuration
nano examples/scheduler.sh

# Test it
./examples/scheduler.sh

# Add to crontab for automatic execution every hour
echo "0 * * * * $(pwd)/examples/scheduler.sh >> /var/log/ilo-scheduler.log 2>&1" | crontab -
```

See [examples/README.md](examples/README.md) for detailed setup instructions.

### 🎛️ PID-Based Fan Control ([`PID_CONTROL.md`](examples/PID_CONTROL.md))

Instead of static fan speeds, configure **dynamic temperature-based curves** where iLO automatically adjusts fans based on current temperatures:

- **Safer**: Fans automatically speed up if temperatures rise
- **Smarter**: Reduces noise when temperatures are low
- **Customizable**: Define your own temperature zones and response curves

**Quick start:**
```bash
# Edit configuration
nano examples/pid-setup.sh

# Apply balanced profile (good for most use cases)
./examples/pid-setup.sh
```

See [examples/PID_CONTROL.md](examples/PID_CONTROL.md) for detailed documentation and safety considerations.

### 🔐 SSH Key Authentication

For improved security, you can use SSH key-based authentication instead of passwords in configuration files:

**For Docker:**
```bash
docker run -d --name ilo-fans-controller --restart always \
    -p 8000:80 \
    -e ILO_HOST='your-ilo-address' \
    -e ILO_USERNAME='your-ilo-username' \
    -e ILO_PASSWORD='fallback-password' \
    -e ILO_SSH_PUBLIC_KEY='/path/to/id_rsa.pub' \
    -e ILO_SSH_PRIVATE_KEY='/path/to/id_rsa' \
    -v /path/to/ssh-keys:/keys:ro \
    ghcr.io/alex3025/ilo-fans-controller:latest
```

**For manual installation**, edit `config.inc.php` and set the SSH key paths (see configuration example above).

---

## API Documentation (WIP)

The tool exposes a simple API that can be used to:

* Get the current fan speeds from iLO
* Set the fan speeds

_There is also a way to manage the presets (get existing and add new ones) but it's not documented yet._<br>
_If you wish to do that, you can check inside the source code how that works_

> The following examples use cURL to show how to use the API, but you can use any other tool you want.

### Get the fan speeds (GET)

To use this API you need to add `?api=fans` at the end of the URL.<br>
**Example: `http://<server ip>/ilo-fans-controller/index.php?api=fans`**

<details>
<summary>JSON structure (response)</summary>

```json
{
    "Fan 1": 85,
    "Fan 2": 48,
    "Fan 3": 69,
    "Fan 4": 18,
    "Fan 5": 44,
    "Fan 6": 96
}
```

</details>

<details>
<summary>cURL example:</summary>

```sh
curl http://<server ip>/ilo-fans-controller/index.php?api=fans
```

</details>

### Set the fan speeds (POST)

<details>
<summary>JSON structure example</summary>

```json
{
    "action": "fans",
    // You can use either an object or a single number value (that will be applied to all fans):
    // Example: `fans: { ... }` or `fans: 50`
    "fans": {
        "Fan 1": 40,
        "Fan 2": 23,
        "Fan 5": 70
        // ...
    }
}
```

</details>

<details>
<summary>cURL example</summary>

```sh
curl -X POST http://<server ip>/ilo-fans-controller/index.php -H 'Content-Type: application/json' -d '{"action": "fans", "fans": 50}'
```

This command will set all fans to 50%.<br>
_I personally use this command to slow down the fans automatically when my server boots._
</details>
