# Multi-Server Configuration

This guide explains how to manage multiple iLO servers from a single iLO Fans Controller instance.

## Overview

While the current version is designed for single-server management, you can easily manage multiple servers using one of these approaches:

## Approach 1: Multiple Instances (Recommended)

Run separate Docker containers for each server:

```yaml
# docker-compose-multi.yaml
services:
  server-1:
    image: ghcr.io/alex3025/ilo-fans-controller:latest
    container_name: ilo-server-1
    ports:
      - "8001:80"
    environment:
      ILO_HOST: '192.168.1.10'
      ILO_USERNAME: 'admin'
      ILO_PASSWORD: 'password1'
    volumes:
      - ./data/server1:/var/www/html/data

  server-2:
    image: ghcr.io/alex3025/ilo-fans-controller:latest
    container_name: ilo-server-2
    ports:
      - "8002:80"
    environment:
      ILO_HOST: '192.168.1.20'
      ILO_USERNAME: 'admin'
      ILO_PASSWORD: 'password2'
    volumes:
      - ./data/server2:/var/www/html/data

  # Unified dashboard (optional)
  dashboard:
    image: nginx:alpine
    ports:
      - "8000:80"
    volumes:
      - ./dashboard:/usr/share/nginx/html
```

**Pros:**
- Complete isolation
- Independent configurations
- Easy to scale
- No code changes needed

**Cons:**
- Multiple containers
- More resource usage

## Approach 2: Reverse Proxy with Path-Based Routing

Use Nginx to route to different instances:

```nginx
# nginx.conf
server {
    listen 80;

    location /server1/ {
        proxy_pass http://ilo-server-1/;
    }

    location /server2/ {
        proxy_pass http://ilo-server-2/;
    }

    location / {
        root /usr/share/nginx/html;
        index dashboard.html;
    }
}
```

Access at:
- `http://dashboard/` - Unified view
- `http://dashboard/server1/` - Server 1
- `http://dashboard/server2/` - Server 2

## Approach 3: Custom Dashboard

Create a simple HTML dashboard that aggregates data from multiple instances:

```html
<!-- dashboard.html -->
<!DOCTYPE html>
<html>
<head>
    <title>Multi-Server Dashboard</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-900 text-white p-8">
    <h1 class="text-4xl font-bold mb-8">Server Monitoring Dashboard</h1>

    <div id="servers" class="grid grid-cols-1 md:grid-cols-2 gap-6"></div>

    <script>
        const servers = [
            { name: 'ProxMox Server', url: 'http://localhost:8001' },
            { name: 'Storage Server', url: 'http://localhost:8002' },
            { name: 'Backup Server', url: 'http://localhost:8003' }
        ];

        async function fetchServerData(server) {
            try {
                const [health, fans, temps] = await Promise.all([
                    fetch(`${server.url}/index.php?api=health`).then(r => r.json()),
                    fetch(`${server.url}/index.php?api=fans`).then(r => r.json()),
                    fetch(`${server.url}/index.php?api=temperatures`).then(r => r.json())
                ]);

                return { ...server, health, fans, temps, error: null };
            } catch (error) {
                return { ...server, error: error.message };
            }
        }

        async function updateDashboard() {
            const container = document.getElementById('servers');
            const data = await Promise.all(servers.map(fetchServerData));

            container.innerHTML = data.map(server => `
                <div class="bg-gray-800 rounded-lg p-6 border ${
                    server.error ? 'border-red-500' :
                    server.health?.status === 'critical' ? 'border-red-500' :
                    server.health?.status === 'warning' ? 'border-yellow-500' :
                    'border-green-500'
                }">
                    <div class="flex items-center justify-between mb-4">
                        <h2 class="text-2xl font-bold">${server.name}</h2>
                        <a href="${server.url}" target="_blank"
                           class="text-blue-400 hover:text-blue-300">
                            Open →
                        </a>
                    </div>

                    ${server.error ? `
                        <div class="text-red-400">
                            ⚠️ Connection Error: ${server.error}
                        </div>
                    ` : `
                        <div class="space-y-3">
                            <div>
                                <span class="text-gray-400">Status:</span>
                                <span class="font-semibold">${server.health.status}</span>
                            </div>
                            <div>
                                <span class="text-gray-400">Max Temp:</span>
                                <span class="font-semibold">${server.health.temperatures.max}°C</span>
                            </div>
                            <div>
                                <span class="text-gray-400">Fans:</span>
                                <span class="font-semibold">
                                    ${Object.values(server.fans).map(s => s + '%').join(', ')}
                                </span>
                            </div>
                        </div>
                    `}
                </div>
            `).join('');
        }

        // Update every 30 seconds
        updateDashboard();
        setInterval(updateDashboard, 30000);
    </script>
</body>
</html>
```

## Approach 4: Prometheus + Grafana (Enterprise)

For large deployments, use Prometheus to scrape all instances:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'ilo-servers'
    static_configs:
      - targets:
          - 'server1:8001'
          - 'server2:8002'
          - 'server3:8003'
    metrics_path: '/index.php'
    params:
      api: ['metrics']
```

Then visualize everything in Grafana with custom dashboards.

## Comparison

| Approach | Complexity | Scalability | Features |
|----------|------------|-------------|----------|
| Multiple Instances | Low | High | Full |
| Reverse Proxy | Medium | High | Full |
| Custom Dashboard | Medium | Medium | Custom |
| Prometheus/Grafana | High | Very High | Enterprise |

## Recommendations

- **Home Lab (2-3 servers)**: Multiple Instances
- **Small Business (5-10 servers)**: Reverse Proxy + Dashboard
- **Enterprise (10+ servers)**: Prometheus + Grafana

## Future Plans

Native multi-server support is planned for version 3.0, which will include:
- Server switcher in UI
- Unified dashboard
- Aggregate metrics
- Shared presets
- Comparison views

## Examples

See `examples/multi-server-dashboard.html` for a complete dashboard implementation.

## Support

For questions about multi-server setups, open an issue on GitHub.
