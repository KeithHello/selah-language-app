// Keep Flutter's generated loader, but let Selah own service-worker
// registration.  Omitting `serviceWorkerSettings` prevents the deprecated
// Flutter worker from racing the versioned Selah worker in index.html.
{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  }
});
