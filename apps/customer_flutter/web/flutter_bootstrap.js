{{flutter_js}}
{{flutter_build_config}}

(async function bootstrapCustomerFlutter() {
  const legacyWorkerFilename = "flutter_service_worker.js";
  const reloadKey = "customer_flutter_legacy_service_worker_removed";

  if ("serviceWorker" in navigator) {
    try {
      const registrations = await navigator.serviceWorker.getRegistrations();
      let removedLegacyWorker = false;

      for (const registration of registrations) {
        const worker =
          registration.active || registration.waiting || registration.installing;
        if (!worker || !worker.scriptURL) continue;

        const scriptPath = new URL(worker.scriptURL, window.location.href).pathname;
        if (!scriptPath.endsWith(`/${legacyWorkerFilename}`)) continue;

        removedLegacyWorker =
          (await registration.unregister()) || removedLegacyWorker;
      }

      if (removedLegacyWorker && navigator.serviceWorker.controller) {
        if (window.sessionStorage.getItem(reloadKey) !== "1") {
          window.sessionStorage.setItem(reloadKey, "1");
          window.location.reload();
          return;
        }
      } else {
        window.sessionStorage.removeItem(reloadKey);
      }
    } catch (error) {
      console.warn("Unable to remove the legacy Flutter service worker.", error);
    }
  }

  _flutter.loader.load();
})();
