/**
 * iLO Fans Controller - Service Worker
 * Enables offline functionality and caching for PWA
 */

const CACHE_NAME = 'ilo-fans-controller-v2.0.0';
const CACHE_URLS = [
  '/',
  '/index.php',
  '/favicon.ico',
  '/enhancements.js',
  '/enhanced-ui.html',
  // CDN resources
  'https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js',
  'https://cdn.tailwindcss.com',
  'https://fonts.googleapis.com/css2?family=DM+Sans:ital,wght@0,400;0,500;0,700;1,400;1,500;1,700&family=JetBrains+Mono&display=swap'
];

// Install event - cache resources
self.addEventListener('install', (event) => {
  console.log('[Service Worker] Installing...');

  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[Service Worker] Caching app shell');
        return cache.addAll(CACHE_URLS);
      })
      .then(() => self.skipWaiting())
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[Service Worker] Activating...');

  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames.map((cacheName) => {
            if (cacheName !== CACHE_NAME) {
              console.log('[Service Worker] Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      })
      .then(() => self.clients.claim())
  );
});

// Fetch event - serve from cache, fallback to network
self.addEventListener('fetch', (event) => {
  const { request } = event;

  // Skip non-GET requests
  if (request.method !== 'GET') {
    return;
  }

  // Skip API requests (always fetch fresh)
  if (request.url.includes('?api=')) {
    return;
  }

  event.respondWith(
    caches.match(request)
      .then((cachedResponse) => {
        if (cachedResponse) {
          // Return cached version
          console.log('[Service Worker] Serving from cache:', request.url);
          return cachedResponse;
        }

        // Fetch from network
        return fetch(request)
          .then((response) => {
            // Don't cache non-successful responses
            if (!response || response.status !== 200 || response.type !== 'basic') {
              return response;
            }

            // Clone the response
            const responseToCache = response.clone();

            // Add to cache
            caches.open(CACHE_NAME)
              .then((cache) => {
                cache.put(request, responseToCache);
              });

            return response;
          })
          .catch((error) => {
            console.log('[Service Worker] Fetch failed:', error);

            // Return offline page if available
            return caches.match('/offline.html');
          });
      })
  );
});

// Background sync for offline actions
self.addEventListener('sync', (event) => {
  console.log('[Service Worker] Background sync:', event.tag);

  if (event.tag === 'sync-fan-speeds') {
    event.waitUntil(syncFanSpeeds());
  }
});

// Push notifications
self.addEventListener('push', (event) => {
  console.log('[Service Worker] Push received');

  const data = event.data ? event.data.json() : {};
  const title = data.title || 'iLO Fans Controller';
  const options = {
    body: data.body || 'Notification from iLO Fans Controller',
    icon: '/favicon.ico',
    badge: '/favicon.ico',
    vibrate: [200, 100, 200],
    data: data.data || {},
    actions: data.actions || []
  };

  event.waitUntil(
    self.registration.showNotification(title, options)
  );
});

// Notification click handler
self.addEventListener('notificationclick', (event) => {
  console.log('[Service Worker] Notification clicked');

  event.notification.close();

  event.waitUntil(
    clients.openWindow(event.notification.data.url || '/')
  );
});

// Helper functions
async function syncFanSpeeds() {
  try {
    const cache = await caches.open('pending-actions');
    const requests = await cache.keys();

    for (const request of requests) {
      try {
        await fetch(request);
        await cache.delete(request);
        console.log('[Service Worker] Synced:', request.url);
      } catch (error) {
        console.error('[Service Worker] Sync failed:', error);
      }
    }
  } catch (error) {
    console.error('[Service Worker] Sync error:', error);
  }
}

// Message handler for client communication
self.addEventListener('message', (event) => {
  console.log('[Service Worker] Message received:', event.data);

  if (event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }

  if (event.data.type === 'CACHE_URLS') {
    event.waitUntil(
      caches.open(CACHE_NAME)
        .then((cache) => cache.addAll(event.data.urls))
    );
  }

  if (event.data.type === 'CLEAR_CACHE') {
    event.waitUntil(
      caches.delete(CACHE_NAME)
        .then(() => {
          return caches.open(CACHE_NAME);
        })
    );
  }
});

console.log('[Service Worker] Loaded');
