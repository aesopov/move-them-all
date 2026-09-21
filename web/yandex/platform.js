/* Platform initialization must finish before Godot creates localized controls. */
window.mergeYandexReady = new Promise((resolve, reject) => {
  GodotYandexBridge.init('{}', json => {
    const result = JSON.parse(json);
    if (!result.success) { reject(new Error(result.error)); return; }
    window.mergeYandexLanguage = result.data.environment.i18n.lang || 'en';
    document.documentElement.lang = window.mergeYandexLanguage;
    resolve();
  });
});
document.addEventListener('contextmenu', event => event.preventDefault());
