'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "ccfdba33cefd36cb32b8e3adbecacdaa",
"assets/AssetManifest.bin.json": "2ffb9d6e05a20d47be127ac567344944",
"assets/AssetManifest.json": "cf08ddf4cc1a11cb47c955340de3b896",
"assets/assets/afl_fixtures_2025_round_24.xlsx": "60c937b2f2f2603ad741222e7a019a73",
"assets/assets/afl_fixtures_2026.xlsx": "2e2dde45670aef0c3b1b32f1d711bbcf",
"assets/assets/afl_fixtures_2026_pre_season.xlsx": "8d23a9bf3b1886be3403a7111e556616",
"assets/assets/afl_players_2026.json": "f5fd39afa633c0192a37ff552133621b",
"assets/assets/afl_players_2026.xlsx": "b5908c09c4b183ffbf34afaec0e18351",
"assets/assets/logos/ADE.png": "aa5948ef627590cde4577d20693350f6",
"assets/assets/logos/BRI.png": "0afab747f3e9216e06ad28415bb80be7",
"assets/assets/logos/CARL.png": "e26f3aed6c5229e4953da33a2eda1f0e",
"assets/assets/logos/COLL.png": "d27a923b686e6138b5b8ec8373747413",
"assets/assets/logos/ESS.png": "78a913992672f6a0af138d306ce98eda",
"assets/assets/logos/FRE.png": "a48483ec82df22c3062fcc04a76c8043",
"assets/assets/logos/GC.png": "08ac1adbad6b043337701f9589cedce3",
"assets/assets/logos/GEEL.png": "080f81a9f452b075e25b8f128726088d",
"assets/assets/logos/GWS.png": "86a10c0ac46c87bf7c25ff79e6748ff6",
"assets/assets/logos/HAW.png": "a7b6da2ec9c4ade79e558ad3c52b3b64",
"assets/assets/logos/MELB.png": "9f360259f4cf06ce34ddcbb8ba00fd1c",
"assets/assets/logos/NM.png": "71fddf414973c7245dfdec2c58780f67",
"assets/assets/logos/PORT.png": "b56569459326c94903b9277dcf3eb7ca",
"assets/assets/logos/RICH.png": "4da89a6bacc73b73fe772a28e3be6bdc",
"assets/assets/logos/STK.png": "3efc3828dc17812021e99e5107c3190b",
"assets/assets/logos/SYD.png": "0a5c1a3e03198ddd4951aa2422922dd6",
"assets/assets/logos/WB.png": "873715efc04a06c2cdc679a34be132d5",
"assets/assets/logos/WCE.png": "e2a16760de7aa9a479ebe54ed116d23b",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "ded268fa53aba3fd89ae194f99b3eedc",
"assets/NOTICES": "d168dbfdb7d22dbcd7635798952558aa",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "e986ebe42ef785b27164c36a9abc7818",
"assets/shaders/ink_sparkle.frag": "4096b5150bac93c41cbc9b45276bd90f",
"canvaskit/canvaskit.js": "eb8797020acdbdf96a12fb0405582c1b",
"canvaskit/canvaskit.wasm": "73584c1a3367e3eaf757647a8f5c5989",
"canvaskit/chromium/canvaskit.js": "0ae8bbcc58155679458a0f7a00f66873",
"canvaskit/chromium/canvaskit.wasm": "143af6ff368f9cd21c863bfa4274c406",
"canvaskit/skwasm.js": "87063acf45c5e1ab9565dcf06b0c18b8",
"canvaskit/skwasm.wasm": "2fc47c0a0c3c7af8542b601634fe9674",
"canvaskit/skwasm.worker.js": "bfb704a6c714a75da9ef320991e88b03",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "59a12ab9d00ae8f8096fffc417b6e84f",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "978137fff6e4db2f1dd07d0164d70ee9",
"/": "978137fff6e4db2f1dd07d0164d70ee9",
"main.dart.js": "97f373c9c5b9d9e805f0273485df340c",
"manifest.json": "18b05de58f5aeed2ffa6be1246cc43f1",
"msal.js": "048932bbbfef32d16327437ca5db5d6b",
"version.json": "b0d2ea9d293a4ff4175362a67375b4a4"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"assets/AssetManifest.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
