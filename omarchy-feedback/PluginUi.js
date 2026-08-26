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

if (typeof module !== "undefined") {
  module.exports = { isMissingTranslation, tr };
}
