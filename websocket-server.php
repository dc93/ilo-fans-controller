#!/usr/bin/env php
<?php
/**
 * WebSocket Server for Real-time Updates
 *
 * This script provides real-time push updates to connected clients,
 * eliminating the need for polling and reducing server load.
 *
 * Usage:
 *   php websocket-server.php
 *
 * Or run as a service:
 *   sudo cp websocket-server.service /etc/systemd/system/
 *   sudo systemctl enable websocket-server
 *   sudo systemctl start websocket-server
 */

// Configuration
require_once __DIR__ . '/config.inc.php';

define('WEBSOCKET_PORT', getenv('WEBSOCKET_PORT') ?: 8080);
define('UPDATE_INTERVAL', 5); // seconds between updates
define('LOG_FILE', '/var/log/ilo-websocket.log');

// Simple WebSocket implementation
class WebSocketServer {
    private $clients = [];
    private $socket;

    public function __construct($port) {
        $this->socket = socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
        socket_set_option($this->socket, SOL_SOCKET, SO_REUSEADDR, 1);
        socket_bind($this->socket, '0.0.0.0', $port);
        socket_listen($this->socket);
        socket_set_nonblock($this->socket);

        $this->log("WebSocket server started on port $port");
    }

    public function run() {
        $lastUpdate = 0;

        while (true) {
            // Accept new connections
            if ($client = @socket_accept($this->socket)) {
                socket_set_nonblock($client);
                $this->clients[] = $client;
                $this->log("New client connected. Total clients: " . count($this->clients));
            }

            // Read from existing clients (handle handshake)
            foreach ($this->clients as $i => $client) {
                $data = @socket_read($client, 2048);
                if ($data === false || $data === '') {
                    socket_close($client);
                    unset($this->clients[$i]);
                    $this->log("Client disconnected. Total clients: " . count($this->clients));
                    continue;
                }

                // WebSocket handshake
                if (strpos($data, 'Sec-WebSocket-Key:') !== false) {
                    $this->performHandshake($client, $data);
                }
            }

            // Send updates to all clients
            if (time() - $lastUpdate >= UPDATE_INTERVAL && count($this->clients) > 0) {
                $update = $this->getUpdate();
                $this->broadcast($update);
                $lastUpdate = time();
            }

            usleep(100000); // 100ms sleep to prevent CPU spinning
        }
    }

    private function performHandshake($client, $data) {
        preg_match('/Sec-WebSocket-Key: (.+)\r\n/', $data, $matches);
        if (empty($matches[1])) return false;

        $key = $matches[1];
        $acceptKey = base64_encode(sha1($key . '258EAFA5-E914-47DA-95CA-C5AB0DC85B11', true));

        $response = "HTTP/1.1 101 Switching Protocols\r\n";
        $response .= "Upgrade: websocket\r\n";
        $response .= "Connection: Upgrade\r\n";
        $response .= "Sec-WebSocket-Accept: $acceptKey\r\n\r\n";

        socket_write($client, $response);
        $this->log("WebSocket handshake completed");
    }

    private function getUpdate() {
        global $ILO_HOST, $ILO_USERNAME, $ILO_PASSWORD;

        // Get fan speeds
        $fans = $this->getFanSpeeds();

        // Get temperatures
        $temps = $this->getTemperatures();

        // Get health status
        $health = $this->getHealthStatus();

        return [
            'type' => 'update',
            'timestamp' => time(),
            'data' => [
                'fans' => $fans,
                'temperatures' => $temps,
                'health' => $health
            ]
        ];
    }

    private function getFanSpeeds() {
        global $ILO_HOST, $ILO_USERNAME, $ILO_PASSWORD;

        $curl_handle = curl_init("https://$ILO_HOST/redfish/v1/Chassis/1/Power");
        curl_setopt($curl_handle, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
        curl_setopt($curl_handle, CURLOPT_USERPWD, "$ILO_USERNAME:$ILO_PASSWORD");
        curl_setopt($curl_handle, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($curl_handle, CURLOPT_SSL_VERIFYHOST, false);
        curl_setopt($curl_handle, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($curl_handle, CURLOPT_TIMEOUT, 5);

        $response = curl_exec($curl_handle);
        curl_close($curl_handle);

        if (!$response) return [];

        $data = json_decode($response, true);
        $fans = [];

        if (isset($data['Fans'])) {
            foreach ($data['Fans'] as $fan) {
                if (isset($fan['FanName']) && isset($fan['Reading'])) {
                    $fans[$fan['FanName']] = (int)$fan['Reading'];
                }
            }
        }

        return $fans;
    }

    private function getTemperatures() {
        global $ILO_HOST, $ILO_USERNAME, $ILO_PASSWORD;

        $curl_handle = curl_init("https://$ILO_HOST/redfish/v1/Chassis/1/Thermal");
        curl_setopt($curl_handle, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
        curl_setopt($curl_handle, CURLOPT_USERPWD, "$ILO_USERNAME:$ILO_PASSWORD");
        curl_setopt($curl_handle, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($curl_handle, CURLOPT_SSL_VERIFYHOST, false);
        curl_setopt($curl_handle, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($curl_handle, CURLOPT_TIMEOUT, 5);

        $response = curl_exec($curl_handle);
        curl_close($curl_handle);

        if (!$response) return [];

        $data = json_decode($response, true);
        $temps = [];

        if (isset($data['Temperatures'])) {
            foreach ($data['Temperatures'] as $temp) {
                if (isset($temp['Name']) && isset($temp['ReadingCelsius'])) {
                    $temps[] = [
                        'name' => $temp['Name'],
                        'value' => (int)$temp['ReadingCelsius'],
                        'status' => $temp['Status']['Health'] ?? 'Unknown'
                    ];
                }
            }
        }

        return $temps;
    }

    private function getHealthStatus() {
        $temps = $this->getTemperatures();
        $status = 'healthy';
        $warnings = [];

        foreach ($temps as $temp) {
            if ($temp['value'] > 80) {
                $status = 'critical';
                $warnings[] = "{$temp['name']}: {$temp['value']}°C (CRITICAL)";
            } elseif ($temp['value'] > 70) {
                if ($status !== 'critical') $status = 'warning';
                $warnings[] = "{$temp['name']}: {$temp['value']}°C (HIGH)";
            }
        }

        return [
            'status' => $status,
            'warnings' => $warnings
        ];
    }

    private function broadcast($message) {
        $frame = $this->encodeFrame(json_encode($message));

        foreach ($this->clients as $i => $client) {
            $result = @socket_write($client, $frame);
            if ($result === false) {
                socket_close($client);
                unset($this->clients[$i]);
                $this->log("Client disconnected during broadcast");
            }
        }
    }

    private function encodeFrame($message) {
        $length = strlen($message);
        $frame = chr(129); // Text frame, FIN bit set

        if ($length <= 125) {
            $frame .= chr($length);
        } elseif ($length <= 65535) {
            $frame .= chr(126) . pack('n', $length);
        } else {
            $frame .= chr(127) . pack('J', $length);
        }

        return $frame . $message;
    }

    private function log($message) {
        $timestamp = date('Y-m-d H:i:s');
        $logMessage = "[$timestamp] $message\n";
        echo $logMessage;
        @file_put_contents(LOG_FILE, $logMessage, FILE_APPEND);
    }
}

// Start server
try {
    $server = new WebSocketServer(WEBSOCKET_PORT);
    $server->run();
} catch (Exception $e) {
    error_log("WebSocket server error: " . $e->getMessage());
    exit(1);
}
