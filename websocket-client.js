/**
 * WebSocket Client for Real-time Updates
 *
 * This replaces the polling mechanism with push-based updates.
 * Include this file after enhancements.js to enable real-time updates.
 */

(function() {
    'use strict';

    // Configuration
    const WEBSOCKET_HOST = window.location.hostname;
    const WEBSOCKET_PORT = 8080;
    const RECONNECT_INTERVAL = 5000; // 5 seconds

    class WebSocketClient {
        constructor() {
            this.ws = null;
            this.reconnectTimer = null;
            this.connected = false;
            this.init();
        }

        init() {
            this.connect();
        }

        connect() {
            console.log('[WebSocket] Connecting to ws://' + WEBSOCKET_HOST + ':' + WEBSOCKET_PORT);

            try {
                this.ws = new WebSocket('ws://' + WEBSOCKET_HOST + ':' + WEBSOCKET_PORT);

                this.ws.onopen = () => {
                    console.log('[WebSocket] Connected');
                    this.connected = true;

                    // Clear reconnect timer
                    if (this.reconnectTimer) {
                        clearTimeout(this.reconnectTimer);
                        this.reconnectTimer = null;
                    }

                    // Disable polling since we have WebSocket
                    if (window.iloEnhancements) {
                        window.iloEnhancements.disablePolling();
                    }

                    // Show notification
                    if (Alpine.store('notifications')) {
                        Alpine.store('notifications').add('WebSocket connected - Real-time updates enabled', 'success');
                    }
                };

                this.ws.onmessage = (event) => {
                    try {
                        const message = JSON.parse(event.data);
                        this.handleMessage(message);
                    } catch (e) {
                        console.error('[WebSocket] Error parsing message:', e);
                    }
                };

                this.ws.onerror = (error) => {
                    console.error('[WebSocket] Error:', error);
                };

                this.ws.onclose = () => {
                    console.log('[WebSocket] Disconnected');
                    this.connected = false;

                    // Re-enable polling as fallback
                    if (window.iloEnhancements) {
                        window.iloEnhancements.enablePolling();
                    }

                    // Attempt to reconnect
                    this.reconnectTimer = setTimeout(() => {
                        console.log('[WebSocket] Attempting to reconnect...');
                        this.connect();
                    }, RECONNECT_INTERVAL);
                };
            } catch (e) {
                console.error('[WebSocket] Connection error:', e);
                // Fallback to polling
                if (window.iloEnhancements) {
                    window.iloEnhancements.enablePolling();
                }
            }
        }

        handleMessage(message) {
            if (message.type === 'update' && message.data) {
                // Update fans
                if (message.data.fans && Alpine.store('fans')) {
                    Object.entries(message.data.fans).forEach(([name, speed]) => {
                        Alpine.store('fans').speeds[name] = speed;
                    });
                }

                // Update temperatures
                if (message.data.temperatures && Alpine.store('temperatures')) {
                    Alpine.store('temperatures').list = message.data.temperatures;
                    Alpine.store('temperatures').lastUpdate = new Date().toLocaleTimeString();
                }

                // Update health status
                if (message.data.health && Alpine.store('health')) {
                    Alpine.store('health').status = message.data.health.status;
                    Alpine.store('health').warnings = message.data.health.warnings;
                    Alpine.store('health').lastCheck = new Date().toLocaleTimeString();
                }

                // Trigger Alpine reactivity
                Alpine.effect(() => {
                    // This ensures Alpine updates all bound elements
                });
            }
        }

        send(data) {
            if (this.connected && this.ws.readyState === WebSocket.OPEN) {
                this.ws.send(JSON.stringify(data));
            }
        }

        disconnect() {
            if (this.ws) {
                this.ws.close();
            }
            if (this.reconnectTimer) {
                clearTimeout(this.reconnectTimer);
            }
        }
    }

    // Extend iloEnhancements with WebSocket support
    if (window.iloEnhancements) {
        window.iloEnhancements.websocket = new WebSocketClient();

        // Add polling control methods
        window.iloEnhancements.pollingEnabled = true;

        window.iloEnhancements.disablePolling = function() {
            this.pollingEnabled = false;
            console.log('[iLO] Polling disabled (using WebSocket)');
        };

        window.iloEnhancements.enablePolling = function() {
            this.pollingEnabled = true;
            console.log('[iLO] Polling enabled (WebSocket unavailable)');
        };
    }

    // Initialize WebSocket on page load
    console.log('[WebSocket] Client initialized');

    // Cleanup on page unload
    window.addEventListener('beforeunload', () => {
        if (window.iloEnhancements && window.iloEnhancements.websocket) {
            window.iloEnhancements.websocket.disconnect();
        }
    });

    // Export for external use
    window.WebSocketClient = WebSocketClient;
})();
