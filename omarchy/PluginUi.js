function isMissingTranslation(value) {
  if (!value || typeof value !== "string")
    return true;

  if (value.length < 4)
    return false;

  const prefix = value.slice(0, 2);
  const suffix = value.slice(value.length - 2);
  return (prefix === "##" && suffix === "##") || (prefix === "!!" && suffix === "!!");
}

function tr(pluginApi, key, fallback) {
  if (!pluginApi || !pluginApi.tr)
    return fallback;

  const value = pluginApi.tr(key);
  return isMissingTranslation(value) ? fallback : value;
}

function activeTooltip(pluginApi, themeDisplayName) {
  const template = tr(pluginApi, "tooltips.active", "Theme: {theme}\nLeft: Panel | Right: Settings | Middle: Random");
  return template.replace("{theme}", themeDisplayName || "");
}

function omarchyTooltip(pluginApi, isBusy, isActive, isAvailable, themeDisplayName) {
  if (isBusy)
    return tr(pluginApi, "status.applying", "Applying...");
  if (!isActive)
    return tr(pluginApi, "tooltips.inactive", "Omarchy is inactive\nLeft: Activate | Right: Settings");
  if (!isAvailable)
    return tr(pluginApi, "tooltips.not-available", "Omarchy not available\nInstall Omarchy or make the `omarchy` command available, then configure themes");

  return activeTooltip(pluginApi, themeDisplayName);
}

function primaryAction(isActive, isAvailable) {
  if (!isActive && isAvailable)
    return "activate";
  return "panel";
}

function contextMenuModel(pluginApi, isActive) {
  if (!isActive) {
    return [
      {
        "label": tr(pluginApi, "actions.activate", "Activate"),
        "action": "activate",
        "icon": "player-play"
      },
      {
        "label": tr(pluginApi, "tooltips.widget-settings", "Widget settings"),
        "action": "settings",
        "icon": "settings"
      }
    ];
  }

  return [
    {
      "label": tr(pluginApi, "tooltips.random-theme", "Random theme"),
      "action": "random",
      "icon": "dice-3"
    },
    {
      "label": tr(pluginApi, "tooltips.widget-settings", "Widget settings"),
      "action": "settings",
      "icon": "settings"
    }
  ];
}

if (typeof module !== "undefined") {
  module.exports = {
    isMissingTranslation,
    tr,
    activeTooltip,
    omarchyTooltip,
    primaryAction,
    contextMenuModel
  };
}
