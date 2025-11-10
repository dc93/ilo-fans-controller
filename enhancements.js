/**
 * iLO Fans Controller - Enhanced Features
 *
 * This file contains advanced features for the iLO Fans Controller:
 * - Real-time temperature monitoring
 * - Historical charts
 * - Keyboard shortcuts
 * - Advanced notifications
 * - Export/Import functionality
 *
 * Include this file in your HTML to enable enhanced features:
 * <script src="enhancements.js"></script>
 */

document.addEventListener('alpine:init', () => {
	// Temperatures store
	Alpine.store('temperatures', {
		temps: {},
		lastUpdate: null,

		async fetch() {
			try {
				const res = await fetch('?api=temperatures');
				if (res.ok) {
					this.temps = await res.json();
					this.lastUpdate = new Date();
				}
			} catch (e) {
				console.error('Failed to fetch temperatures:', e);
			}
		},

		getTemp(name) {
			return this.temps[name]?.current || null;
		},

		getStatus(name) {
			const temp = this.temps[name];
			if (!temp || !temp.current) return 'unknown';

			if (temp.upper_threshold && temp.current >= temp.upper_threshold) return 'critical';
			if (temp.upper_threshold && temp.current >= temp.upper_threshold * 0.9) return 'warning';
			return 'ok';
		},

		getStatusColor(name) {
			const status = this.getStatus(name);
			return {
				'critical': 'text-red-500',
				'warning': 'text-yellow-500',
				'ok': 'text-green-500',
				'unknown': 'text-gray-500'
			}[status];
		},

		init() {
			this.fetch();
			// Auto-refresh every 30 seconds
			setInterval(() => this.fetch(), 30000);
		}
	});

	// Health monitoring store
	Alpine.store('health', {
		status: 'unknown',
		data: {},
		lastUpdate: null,

		async fetch() {
			try {
				const res = await fetch('?api=health');
				if (res.ok) {
					this.data = await res.json();
					this.status = this.data.status;
					this.lastUpdate = new Date();
				}
			} catch (e) {
				console.error('Failed to fetch health:', e);
			}
		},

		get statusColor() {
			return {
				'healthy': 'bg-green-500',
				'warning': 'bg-yellow-500',
				'critical': 'bg-red-500',
				'unknown': 'bg-gray-500'
			}[this.status] || 'bg-gray-500';
		},

		get statusText() {
			return this.status.charAt(0).toUpperCase() + this.status.slice(1);
		},

		hasWarnings() {
			return this.data.warnings && this.data.warnings.length > 0;
		},

		hasErrors() {
			return this.data.errors && this.data.errors.length > 0;
		},

		init() {
			this.fetch();
			// Auto-refresh every 30 seconds
			setInterval(() => this.fetch(), 30000);
		}
	});

	// Quick actions store
	Alpine.store('quickActions', {
		async muteAll() {
			return await Alpine.store('app').setAllSpeeds(15);
		},

		async boostAll() {
			return await Alpine.store('app').setAllSpeeds(100);
		},

		async normalAll() {
			return await Alpine.store('app').setAllSpeeds(50);
		}
	});

	// History/Charts store
	Alpine.store('charts', {
		history: [],
		range: '24h',
		chartInstance: null,

		async fetchHistory() {
			try {
				const res = await fetch(`?api=history&range=${this.range}`);
				if (res.ok) {
					this.history = await res.json();
					this.updateChart();
				}
			} catch (e) {
				console.error('Failed to fetch history:', e);
			}
		},

		updateChart() {
			if (!window.Chart) {
				console.warn('Chart.js not loaded');
				return;
			}

			const ctx = document.getElementById('historyChart');
			if (!ctx) return;

			const labels = this.history.map(entry => {
				const date = new Date(entry.datetime);
				return date.toLocaleTimeString();
			});

			const datasets = [];

			// Fan speed datasets
			if (this.history.length > 0) {
				const fanNames = Object.keys(this.history[0].fans || {});
				fanNames.forEach((fanName, idx) => {
					datasets.push({
						label: fanName,
						data: this.history.map(entry => entry.fans[fanName]),
						borderColor: `hsl(${idx * 60}, 70%, 50%)`,
						backgroundColor: `hsl(${idx * 60}, 70%, 50%, 0.1)`,
						tension: 0.4
					});
				});
			}

			if (this.chartInstance) {
				this.chartInstance.destroy();
			}

			this.chartInstance = new Chart(ctx, {
				type: 'line',
				data: { labels, datasets },
				options: {
					responsive: true,
					plugins: {
						legend: { position: 'top' },
						title: {
							display: true,
							text: `Fan Speeds (${this.range})`
						}
					},
					scales: {
						y: {
							beginAtZero: true,
							max: 100,
							title: { display: true, text: 'Speed %' }
						}
					}
				}
			});
		},

		changeRange(newRange) {
			this.range = newRange;
			this.fetchHistory();
		}
	});

	// Notifications store
	Alpine.store('notifications', {
		items: [],
		nextId: 1,

		add(message, type = 'info', duration = 5000) {
			const notification = {
				id: this.nextId++,
				message,
				type, // info, success, warning, error
				timestamp: new Date()
			};

			this.items.push(notification);

			if (duration > 0) {
				setTimeout(() => this.remove(notification.id), duration);
			}

			return notification.id;
		},

		remove(id) {
			const index = this.items.findIndex(n => n.id === id);
			if (index > -1) {
				this.items.splice(index, 1);
			}
		},

		success(message) {
			return this.add(message, 'success');
		},

		error(message) {
			return this.add(message, 'error', 10000);
		},

		warning(message) {
			return this.add(message, 'warning', 7000);
		},

		info(message) {
			return this.add(message, 'info');
		}
	});

	// Export/Import functionality
	Alpine.store('backup', {
		async exportConfig() {
			try {
				const res = await fetch('?api=export');
				if (res.ok) {
					const blob = await res.blob();
					const url = window.URL.createObjectURL(blob);
					const a = document.createElement('a');
					a.href = url;
					a.download = `ilo-config-${new Date().toISOString().split('T')[0]}.json`;
					document.body.appendChild(a);
					a.click();
					document.body.removeChild(a);
					window.URL.revokeObjectURL(url);

					Alpine.store('notifications').success('Configuration exported successfully');
				}
			} catch (e) {
				console.error('Failed to export config:', e);
				Alpine.store('notifications').error('Failed to export configuration');
			}
		},

		async importConfig(file) {
			try {
				const text = await file.text();
				const config = JSON.parse(text);

				if (config.presets) {
					// Import presets
					const res = await fetch(window.location.href, {
						method: 'POST',
						headers: { 'Content-Type': 'application/json' },
						body: JSON.stringify({
							action: 'presets',
							presets: config.presets
						})
					});

					if (res.ok) {
						Alpine.store('presets').presets = config.presets;
						Alpine.store('notifications').success('Configuration imported successfully');
						setTimeout(() => window.location.reload(), 1500);
					}
				}
			} catch (e) {
				console.error('Failed to import config:', e);
				Alpine.store('notifications').error('Failed to import configuration');
			}
		}
	});
});

// Extend the existing app store with quick actions
document.addEventListener('DOMContentLoaded', () => {
	// Wait for Alpine to initialize
	setTimeout(() => {
		const appStore = Alpine.store('app');
		if (appStore) {
			// Add setAllSpeeds helper method
			appStore.setAllSpeeds = async function(speed) {
				this.isLoading = true;
				const fans = Alpine.store('fans').fans;

				// Set all fans to the same speed
				Object.keys(fans).forEach(fan => {
					fans[fan] = speed;
				});

				// Apply the speeds
				await this.applySpeeds();
			};

			// Add PWM calculation helper
			appStore.speedToPWM = function(speed) {
				return Math.ceil(speed / 100 * 255);
			};

			appStore.PWMToSpeed = function(pwm) {
				return Math.round(pwm / 255 * 100);
			};
		}

		// Initialize enhanced stores
		const temps = Alpine.store('temperatures');
		if (temps) temps.init();

		const health = Alpine.store('health');
		if (health) health.init();

	}, 100);
});

// Keyboard shortcuts
document.addEventListener('keydown', (e) => {
	// Only trigger if not in an input field
	if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;

	const key = e.key.toLowerCase();
	const ctrl = e.ctrlKey || e.metaKey;
	const alt = e.altKey;

	// Ctrl/Cmd + S: Apply speeds
	if (ctrl && key === 's') {
		e.preventDefault();
		const app = Alpine.store('app');
		if (app && !app.isLoading) {
			app.applySpeeds();
		}
	}

	// Alt + M: Mute all (15%)
	if (alt && key === 'm') {
		e.preventDefault();
		Alpine.store('quickActions').muteAll();
	}

	// Alt + B: Boost all (100%)
	if (alt && key === 'b') {
		e.preventDefault();
		Alpine.store('quickActions').boostAll();
	}

	// Alt + N: Normal all (50%)
	if (alt && key === 'n') {
		e.preventDefault();
		Alpine.store('quickActions').normalAll();
	}

	// Alt + E: Export config
	if (alt && key === 'e') {
		e.preventDefault();
		Alpine.store('backup').exportConfig();
	}

	// Alt + R: Refresh/Reload page
	if (alt && key === 'r') {
		e.preventDefault();
		window.location.reload();
	}

	// Number keys 1-9: Apply preset
	if (!ctrl && !alt && key >= '1' && key <= '9') {
		const presetIndex = parseInt(key) - 1;
		const presets = Alpine.store('presets');
		if (presets && presets.presets[presetIndex]) {
			presets.applyPreset(presetIndex);
		}
	}
});

// Auto-refresh functionality
let autoRefreshInterval = null;

function startAutoRefresh(intervalSeconds = 60) {
	if (autoRefreshInterval) {
		clearInterval(autoRefreshInterval);
	}

	autoRefreshInterval = setInterval(async () => {
		const fans = Alpine.store('fans');
		const temps = Alpine.store('temperatures');
		const health = Alpine.store('health');

		if (fans) {
			try {
				const res = await fetch('?api=fans');
				if (res.ok) {
					fans.fans = await res.json();
				}
			} catch (e) {
				console.error('Auto-refresh failed:', e);
			}
		}

		if (temps) await temps.fetch();
		if (health) await health.fetch();
	}, intervalSeconds * 1000);
}

function stopAutoRefresh() {
	if (autoRefreshInterval) {
		clearInterval(autoRefreshInterval);
		autoRefreshInterval = null;
	}
}

// Start auto-refresh by default (every 60 seconds)
startAutoRefresh(60);

// Utility functions
window.iloEnhancements = {
	startAutoRefresh,
	stopAutoRefresh,

	// Temperature monitoring
	async getTemperatures() {
		const res = await fetch('?api=temperatures');
		return res.ok ? await res.json() : {};
	},

	// Health check
	async getHealth() {
		const res = await fetch('?api=health');
		return res.ok ? await res.json() : {};
	},

	// History data
	async getHistory(range = '24h') {
		const res = await fetch(`?api=history&range=${range}`);
		return res.ok ? await res.json() : [];
	},

	// Logs
	async getLogs(limit = 100) {
		const res = await fetch(`?api=logs&limit=${limit}`);
		return res.ok ? await res.json() : [];
	},

	// Export configuration
	exportConfig() {
		Alpine.store('backup').exportConfig();
	}
};

console.log('iLO Fans Controller Enhanced Features Loaded');
console.log('Keyboard shortcuts:');
console.log('  Ctrl/Cmd + S: Apply speeds');
console.log('  Alt + M: Mute all (15%)');
console.log('  Alt + B: Boost all (100%)');
console.log('  Alt + N: Normal all (50%)');
console.log('  Alt + E: Export config');
console.log('  Alt + R: Refresh page');
console.log('  1-9: Apply preset 1-9');
