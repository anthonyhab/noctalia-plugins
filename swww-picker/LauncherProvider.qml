import QtQuick
import qs.Commons

Item {
  id: root

  property var pluginApi: null
  property var launcher: null
  property string name: pluginApi?.tr("title")
  property bool handleSearch: false
  property string supportedLayouts: "list"
  property bool supportsAutoPaste: false
  property bool trackUsage: true

  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property var wallpapers: pluginMain?.wallpaperList || []

  function commands() {
    return [{
      "name": ">wp",
      "description": pluginApi?.tr("title"),
      "icon": "photo",
      "isTablerIcon": true,
      "isImage": false,
      "onActivate": function() {
        launcher?.setSearchText(">wp ");
      }
    }];
  }

  function handleCommand(searchText) {
    return searchText.startsWith(">wp");
  }

  function tokenizePath(path) {
    const normalized = (path || "").toLowerCase();
    return normalized
      .split(/[\\/._\-\s]+/)
      .filter(token => token.length > 0);
  }

  function scoreWallpaper(path, query) {
    if (!query || query.length === 0)
      return 0;

    const filename = path.split("/").pop() || "";
    const fileLower = filename.toLowerCase();
    if (fileLower.startsWith(query))
      return 100;
    if (fileLower.includes(query))
      return 75;

    const tags = tokenizePath(path);
    for (let i = 0; i < tags.length; i++) {
      if (tags[i].startsWith(query))
        return 60;
      if (tags[i].includes(query))
        return 40;
    }

    return -1;
  }

  function getResults(searchText) {
    if (!searchText.startsWith(">wp"))
      return [];

    const query = searchText.slice(3).trim().toLowerCase();
    const results = [];

    for (let i = 0; i < wallpapers.length; i++) {
      const path = wallpapers[i];
      const score = scoreWallpaper(path, query);
      if (score < 0)
        continue;

      const filename = path.split("/").pop() || path;
      results.push({
        "usageKey": path,
        "name": filename,
        "description": path,
        "icon": "photo",
        "isTablerIcon": true,
        "isImage": false,
        "_score": score,
        "provider": root,
        "onActivate": function() {
          pluginMain?.setWallpaper(path);
          launcher?.close();
        }
      });
    }

    results.sort((a, b) => b._score - a._score || a.name.localeCompare(b.name));
    return results;
  }
}
