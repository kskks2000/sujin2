from pathlib import Path


UNREGISTER_SNIPPET = """  <script>
    if ('serviceWorker' in navigator) {
      window.addEventListener('load', function () {
        navigator.serviceWorker.getRegistrations().then(function (registrations) {
          for (const registration of registrations) {
            registration.unregister();
          }
        });
        if ('caches' in window) {
          caches.keys().then(function (keys) {
            for (const key of keys) {
              caches.delete(key);
            }
          });
        }
      });
    }
  </script>
"""

SELF_UNREGISTER_WORKER = """self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.map((key) => caches.delete(key)));
    await self.registration.unregister();
    const clients = await self.clients.matchAll({ type: 'window' });
    for (const client of clients) {
      client.navigate(client.url);
    }
  })());
});
"""


def main() -> None:
  build_dir = Path("/app/build/web")
  if not build_dir.exists():
    build_dir = Path(__file__).resolve().parents[1] / "build" / "web"

  index_file = build_dir / "index.html"
  bootstrap_file = build_dir / "flutter_bootstrap.js"
  worker_file = build_dir / "flutter_service_worker.js"

  index_html = index_file.read_text()
  if UNREGISTER_SNIPPET not in index_html:
    index_html = index_html.replace(
      '  <script src="flutter_bootstrap.js" async></script>\n',
      f"{UNREGISTER_SNIPPET}  <script src=\"flutter_bootstrap.js\" async></script>\n",
    )
  index_file.write_text(index_html)

  bootstrap_text = bootstrap_file.read_text()
  bootstrap_text = bootstrap_text.replace(
    "_flutter.loader.load({\n  serviceWorkerSettings: {\n    serviceWorkerVersion: \"2168639847\" /* Flutter's service worker is deprecated and will be removed in a future Flutter release. */\n  }\n});",
    "_flutter.loader.load();",
  )
  worker_file.write_text(SELF_UNREGISTER_WORKER)
  bootstrap_file.write_text(bootstrap_text)


if __name__ == "__main__":
  main()
