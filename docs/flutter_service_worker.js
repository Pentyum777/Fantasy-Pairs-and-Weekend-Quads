'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "0250fe103a44fd8d5f55d2ca68be70c5",
"assets/AssetManifest.bin.json": "13d9b4a82c07aa4bef5bfb0b8ae02f91",
"assets/AssetManifest.json": "fdc9f90ae70d6304530d7bac6fa774d9",
"assets/assets/afl_fixtures_2025_round_24.xlsx": "7bd23b43169c4f87c0849841d10b59b6",
"assets/assets/afl_fixtures_2026.xlsx": "5e35664b0d8a2509975b112f291b0978",
"assets/assets/afl_players_2025.json": "7ff132878b0ef0220178647dea1cedfa",
"assets/assets/afl_players_2025.xlsx": "c578d298ece2622982c100c89efd7b2f",
"assets/assets/afl_players_2026.json": "012efc92e4ddde0f6fe0c13c8a472ae1",
"assets/assets/afl_players_2026.xlsx": "b5908c09c4b183ffbf34afaec0e18351",
"assets/assets/logos/ADE.png": "f679f7f635a719736bc85619958f4eac",
"assets/assets/logos/BRI.png": "a62077041e9aa07ac9ac03625d267489",
"assets/assets/logos/CARL.png": "f2f4ce1257835580773747933ece8f9c",
"assets/assets/logos/COLL.png": "9edda4f7fa1b7604855e9d4614048329",
"assets/assets/logos/ESS.png": "48245097242b05407facc31ae7d645e8",
"assets/assets/logos/FRE.png": "075a2fe11f6b592e1f0bf8b168d02797",
"assets/assets/logos/GCS.png": "c297c637f25701d3ddbf5ebff4b6c083",
"assets/assets/logos/GEE.png": "0adb22ee3f2c3df5053d9799545fb06e",
"assets/assets/logos/GWS%2520GIANTS.png": "48b1fdf99f96033a8b57b2bc0745e0e1",
"assets/assets/logos/HAW.png": "61babe9b37c530693a8f203f57c052d0",
"assets/assets/logos/MELB.png": "c3bfff8ae1c1f07eb1ba455c5b0e8727",
"assets/assets/logos/NTH.png": "3fd5899156017d35ebef537d8cb3b5d6",
"assets/assets/logos/PTA.png": "1a27054be1e286441dcff3f0e424c591",
"assets/assets/logos/RICH.png": "473d31863ae58cb38f1d049580008b5f",
"assets/assets/logos/STK.png": "479e5715ff2da289a213194826cfae97",
"assets/assets/logos/SYD.png": "d7134f878851e91b456966fe87f02d6e",
"assets/assets/logos/WB.png": "308b4e091417242c00558c473cbf624a",
"assets/assets/logos/WCE.png": "3dbb9fba975a802755c88a292c62a082",
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
"index.html": "ff5cb34dc688fa8e3e1cc12bc1a60d74",
"/": "ff5cb34dc688fa8e3e1cc12bc1a60d74",
"main.dart.js": "c923db35025268be9783340da349d0b6",
"manifest.json": "18b05de58f5aeed2ffa6be1246cc43f1",
"msal.js": "7dd4ad38d883c25e5652b5e7b00bbfe9",
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
