/**
 * Mobile App Enhancements for iLO Fans Controller
 *
 * This file adds mobile-specific features for a native app-like experience:
 * - Touch gestures (swipe, pinch)
 * - Haptic feedback
 * - Native sharing
 * - Install prompt handling
 * - Fullscreen mode
 * - Orientation handling
 * - Pull-to-refresh
 */

(function() {
    'use strict';

    class MobileEnhancements {
        constructor() {
            this.isStandalone = window.matchMedia('(display-mode: standalone)').matches;
            this.installPrompt = null;
            this.touchStartX = 0;
            this.touchStartY = 0;
            this.pullToRefreshElement = null;

            this.init();
        }

        init() {
            console.log('[Mobile] Initializing mobile enhancements');

            // Detect if running as installed app
            if (this.isStandalone) {
                console.log('[Mobile] Running as installed PWA');
                document.body.classList.add('pwa-installed');
            }

            // Setup features
            this.setupInstallPrompt();
            this.setupGestures();
            this.setupPullToRefresh();
            this.setupHapticFeedback();
            this.setupNativeSharing();
            this.setupStatusBar();
            this.setupScreenWakeLock();
            this.handleUrlActions();

            // Add mobile utility methods to global scope
            window.mobile = {
                vibrate: this.vibrate.bind(this),
                share: this.share.bind(this),
                installApp: this.showInstallPrompt.bind(this),
                isInstalled: () => this.isStandalone,
                isIOS: this.isIOS(),
                isAndroid: this.isAndroid()
            };
        }

        // ==================== INSTALL PROMPT ====================

        setupInstallPrompt() {
            // Capture install prompt event
            window.addEventListener('beforeinstallprompt', (e) => {
                e.preventDefault();
                this.installPrompt = e;
                console.log('[Mobile] Install prompt available');

                // Show install banner
                this.showInstallBanner();
            });

            // Detect successful installation
            window.addEventListener('appinstalled', () => {
                console.log('[Mobile] App installed successfully');
                this.installPrompt = null;
                this.hideInstallBanner();

                if (Alpine.store('notifications')) {
                    Alpine.store('notifications').add('App installed successfully!', 'success');
                }
            });
        }

        showInstallBanner() {
            // Create install banner if it doesn't exist
            if (document.getElementById('install-banner')) return;

            const banner = document.createElement('div');
            banner.id = 'install-banner';
            banner.className = 'fixed bottom-20 left-4 right-4 bg-blue-600 text-white p-4 rounded-lg shadow-lg z-50 animate-slide-up';
            banner.innerHTML = `
                <div class="flex items-center justify-between">
                    <div class="flex-1">
                        <div class="font-semibold">Install iLO Fans Controller</div>
                        <div class="text-sm opacity-90">Get quick access from your home screen</div>
                    </div>
                    <button id="install-btn" class="ml-4 bg-white text-blue-600 px-4 py-2 rounded font-semibold">
                        Install
                    </button>
                    <button id="dismiss-install" class="ml-2 p-2 opacity-75 hover:opacity-100">
                        ✕
                    </button>
                </div>
            `;

            document.body.appendChild(banner);

            // Handle install button click
            document.getElementById('install-btn').addEventListener('click', () => {
                this.showInstallPrompt();
            });

            // Handle dismiss
            document.getElementById('dismiss-install').addEventListener('click', () => {
                this.hideInstallBanner();
            });
        }

        hideInstallBanner() {
            const banner = document.getElementById('install-banner');
            if (banner) {
                banner.remove();
            }
        }

        async showInstallPrompt() {
            if (!this.installPrompt) {
                alert('Install not available. On iOS, use Share > Add to Home Screen');
                return;
            }

            this.installPrompt.prompt();
            const result = await this.installPrompt.userChoice;

            if (result.outcome === 'accepted') {
                console.log('[Mobile] User accepted install');
            } else {
                console.log('[Mobile] User dismissed install');
            }

            this.installPrompt = null;
            this.hideInstallBanner();
        }

        // ==================== GESTURES ====================

        setupGestures() {
            let touchStartTime = 0;
            let touchEndTime = 0;

            // Swipe gestures
            document.addEventListener('touchstart', (e) => {
                this.touchStartX = e.changedTouches[0].screenX;
                this.touchStartY = e.changedTouches[0].screenY;
                touchStartTime = Date.now();
            }, { passive: true });

            document.addEventListener('touchend', (e) => {
                const touchEndX = e.changedTouches[0].screenX;
                const touchEndY = e.changedTouches[0].screenY;
                touchEndTime = Date.now();

                const diffX = touchEndX - this.touchStartX;
                const diffY = touchEndY - this.touchStartY;
                const diffTime = touchEndTime - touchStartTime;

                // Detect swipe (fast, directional movement)
                if (Math.abs(diffX) > 50 && diffTime < 300 && Math.abs(diffY) < 50) {
                    if (diffX > 0) {
                        this.onSwipeRight();
                    } else {
                        this.onSwipeLeft();
                    }
                }
            }, { passive: true });

            // Long press for quick actions menu
            let longPressTimer;
            document.addEventListener('touchstart', (e) => {
                longPressTimer = setTimeout(() => {
                    this.onLongPress(e);
                }, 500);
            });

            document.addEventListener('touchend', () => {
                clearTimeout(longPressTimer);
            });

            document.addEventListener('touchmove', () => {
                clearTimeout(longPressTimer);
            });
        }

        onSwipeRight() {
            console.log('[Mobile] Swipe right detected');
            // Could open settings or navigate
        }

        onSwipeLeft() {
            console.log('[Mobile] Swipe left detected');
            // Could close panels or navigate
        }

        onLongPress(e) {
            console.log('[Mobile] Long press detected');
            this.vibrate(50);

            // Show quick actions if available
            if (Alpine.store('quickActions')) {
                const rect = e.target.getBoundingClientRect();
                // Could show context menu
            }
        }

        // ==================== PULL TO REFRESH ====================

        setupPullToRefresh() {
            let startY = 0;
            let currentY = 0;
            let pulling = false;

            const createRefreshIndicator = () => {
                const indicator = document.createElement('div');
                indicator.id = 'pull-refresh-indicator';
                indicator.className = 'fixed top-0 left-0 right-0 h-16 flex items-center justify-center bg-blue-600 text-white transform -translate-y-full transition-transform';
                indicator.innerHTML = '<div class="animate-spin">↻</div> <span class="ml-2">Pull to refresh</span>';
                document.body.insertBefore(indicator, document.body.firstChild);
                return indicator;
            };

            const indicator = createRefreshIndicator();

            document.addEventListener('touchstart', (e) => {
                if (window.scrollY === 0) {
                    startY = e.touches[0].pageY;
                    pulling = true;
                }
            }, { passive: true });

            document.addEventListener('touchmove', (e) => {
                if (!pulling) return;

                currentY = e.touches[0].pageY;
                const diff = currentY - startY;

                if (diff > 0 && diff < 150) {
                    indicator.style.transform = `translateY(${diff - 64}px)`;
                }
            }, { passive: true });

            document.addEventListener('touchend', () => {
                if (!pulling) return;

                const diff = currentY - startY;

                if (diff > 100) {
                    // Trigger refresh
                    indicator.style.transform = 'translateY(0)';
                    this.vibrate(30);

                    setTimeout(() => {
                        window.location.reload();
                    }, 500);
                } else {
                    indicator.style.transform = 'translateY(-100%)';
                }

                pulling = false;
                startY = 0;
                currentY = 0;
            });
        }

        // ==================== HAPTIC FEEDBACK ====================

        setupHapticFeedback() {
            // Add haptic feedback to all buttons
            document.addEventListener('click', (e) => {
                const button = e.target.closest('button');
                if (button) {
                    this.vibrate(10);
                }
            });
        }

        vibrate(duration = 50) {
            if ('vibrate' in navigator) {
                navigator.vibrate(duration);
            }
        }

        // ==================== NATIVE SHARING ====================

        setupNativeSharing() {
            // Add share functionality to Alpine store
            if (Alpine && !Alpine.store('share')) {
                Alpine.store('share', {
                    available: 'share' in navigator,
                    shareConfig: () => this.share()
                });
            }
        }

        async share() {
            if (!('share' in navigator)) {
                alert('Sharing not supported on this device');
                return;
            }

            try {
                // Get current configuration
                const config = await fetch(window.location.href + '?api=export').then(r => r.json());

                await navigator.share({
                    title: 'iLO Fans Configuration',
                    text: 'My iLO server fan configuration',
                    url: window.location.href
                });

                console.log('[Mobile] Shared successfully');
            } catch (err) {
                if (err.name !== 'AbortError') {
                    console.error('[Mobile] Error sharing:', err);
                }
            }
        }

        // ==================== STATUS BAR ====================

        setupStatusBar() {
            // Set theme color for status bar
            let metaThemeColor = document.querySelector('meta[name=theme-color]');
            if (!metaThemeColor) {
                metaThemeColor = document.createElement('meta');
                metaThemeColor.name = 'theme-color';
                document.head.appendChild(metaThemeColor);
            }

            // Update based on health status
            if (Alpine.store('health')) {
                Alpine.effect(() => {
                    const status = Alpine.store('health').status;
                    const colors = {
                        healthy: '#10B981',
                        warning: '#F59E0B',
                        critical: '#EF4444'
                    };
                    metaThemeColor.content = colors[status] || colors.healthy;
                });
            }
        }

        // ==================== SCREEN WAKE LOCK ====================

        async setupScreenWakeLock() {
            if (!('wakeLock' in navigator)) {
                console.log('[Mobile] Wake Lock API not supported');
                return;
            }

            try {
                const wakeLock = await navigator.wakeLock.request('screen');
                console.log('[Mobile] Screen wake lock active');

                wakeLock.addEventListener('release', () => {
                    console.log('[Mobile] Screen wake lock released');
                });
            } catch (err) {
                console.error('[Mobile] Wake lock error:', err);
            }
        }

        // ==================== URL ACTIONS ====================

        handleUrlActions() {
            const params = new URLSearchParams(window.location.search);
            const action = params.get('action');

            if (action && Alpine.store('quickActions')) {
                console.log('[Mobile] Handling URL action:', action);

                setTimeout(() => {
                    switch (action) {
                        case 'mute':
                            Alpine.store('quickActions').mute();
                            break;
                        case 'normal':
                            Alpine.store('quickActions').normal();
                            break;
                        case 'boost':
                            Alpine.store('quickActions').boost();
                            break;
                    }

                    // Clean URL
                    window.history.replaceState({}, document.title, window.location.pathname);
                }, 1000);
            }
        }

        // ==================== DEVICE DETECTION ====================

        isIOS() {
            return /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream;
        }

        isAndroid() {
            return /Android/.test(navigator.userAgent);
        }
    }

    // Initialize on DOM ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            window.mobileEnhancements = new MobileEnhancements();
        });
    } else {
        window.mobileEnhancements = new MobileEnhancements();
    }

    console.log('[Mobile] Module loaded');
})();
