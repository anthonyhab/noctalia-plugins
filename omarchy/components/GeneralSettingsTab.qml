import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  required property var settingsRoot

  spacing: Style.marginL
  Layout.fillWidth: true

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: root.settingsRoot.tr("settings.controls.title", "Plugin controls")
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightMedium
      color: Color.mOnSurface
    }

    NText {
      Layout.fillWidth: true
      text: root.settingsRoot.statusText + " · " + (root.settingsRoot.isActive ? root.settingsRoot.activeStatusText : root.settingsRoot.inactiveStatusText)
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      wrapMode: Text.WordWrap
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NButton {
        Layout.fillWidth: true
        text: root.settingsRoot.refreshText
        enabled: !!root.settingsRoot.pluginMain
        onClicked: root.settingsRoot.pluginMain?.refresh()
      }

      NButton {
        Layout.fillWidth: true
        text: root.settingsRoot.isActive ? root.settingsRoot.deactivateText : root.settingsRoot.activateText
        enabled: !!root.settingsRoot.pluginMain
        onClicked: {
          if (!root.settingsRoot.pluginApi)
            return;
          if (root.settingsRoot.isActive)
            root.settingsRoot.pluginMain?.deactivate();
          else
            root.settingsRoot.pluginMain?.activate();
        }
      }

      NButton {
        Layout.fillWidth: true
        text: root.settingsRoot.applyText
        enabled: !!root.settingsRoot.pluginMain && root.settingsRoot.isAvailable && !root.settingsRoot.isApplying
        onClicked: root.settingsRoot.pluginMain?.applyCurrentTheme()
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NToggle {
    label: root.settingsRoot.tr("fields.show-theme-name.label", "Show theme name in bar widget")
    description: root.settingsRoot.tr("fields.show-theme-name.desc", "If disabled, only the Omarchy icon is shown in the bar.")
    checked: root.settingsRoot.showThemeName
    Layout.fillWidth: true
    onToggled: function (checked) {
      if (root.settingsRoot.isLoading)
        return;
      root.settingsRoot.showThemeName = checked;
      root.settingsRoot.saveSettings();
    }
  }

  NToggle {
    label: root.settingsRoot.tr("fields.show-search-input.label", "Show search input in panel")
    description: root.settingsRoot.tr("fields.show-search-input.desc", "If enabled, a search field will appear in the panel to filter themes.")
    checked: root.settingsRoot.showSearchInput
    Layout.fillWidth: true
    onToggled: function (checked) {
      if (root.settingsRoot.isLoading)
        return;
      root.settingsRoot.showSearchInput = checked;
      root.settingsRoot.saveSettings();
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: root.settingsRoot.tr("settings.time-filtering.title", "Time-based Theme Filtering")
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightMedium
      color: Color.mOnSurface
    }

    NText {
      text: root.settingsRoot.tr("settings.time-filtering.desc", "Automatically filter themes based on time of day using your location settings.")
      wrapMode: Text.WordWrap
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      Layout.fillWidth: true
    }

    NToggle {
      label: root.settingsRoot.tr("fields.time-based-filtering.label", "Enable time-based theme filtering")
      description: root.settingsRoot.tr("fields.time-based-filtering.desc", "Random theme selection will only pick light themes during daytime and dark themes at night.")
      checked: root.settingsRoot.timeBasedThemeFiltering
      Layout.fillWidth: true
      onToggled: function (checked) {
        if (root.settingsRoot.isLoading)
          return;
        root.settingsRoot.timeBasedThemeFiltering = checked;
        root.settingsRoot.saveSettings();
      }
    }

    NComboBox {
      label: root.settingsRoot.tr("fields.filtering-mode.label", "Apply filtering to")
      model: [
        {
          "key": "random-only",
          "name": root.settingsRoot.tr("filtering-mode.random-only", "Random theme only")
        },
        {
          "key": "random-and-cycle",
          "name": root.settingsRoot.tr("filtering-mode.random-and-cycle", "Random and cycle")
        }
      ]
      currentKey: root.settingsRoot.themeFilteringMode
      Layout.fillWidth: true
      enabled: root.settingsRoot.timeBasedThemeFiltering
      onSelected: function (key) {
        if (root.settingsRoot.isLoading)
          return;
        if (root.settingsRoot.themeFilteringMode !== key) {
          root.settingsRoot.themeFilteringMode = key;
          root.settingsRoot.saveSettings();
        }
      }
    }

    NText {
      text: {
        var schedulingMode = root.settingsRoot.colorSchemeSetting("schedulingMode", "off");
        if (schedulingMode !== "location")
          return root.settingsRoot.tr("status.no-location", "Location-based scheduling is not enabled in Noctalia settings");
        var isDay = !root.settingsRoot.colorSchemeSetting("darkMode", false);
        return isDay ? root.settingsRoot.tr("status.daytime", "Currently: Daytime") : root.settingsRoot.tr("status.nighttime", "Currently: Nighttime");
      }
      color: {
        var schedulingMode = root.settingsRoot.colorSchemeSetting("schedulingMode", "off");
        if (schedulingMode !== "location")
          return Color.mError;
        return Color.mOnSurfaceVariant;
      }
      pointSize: Style.fontSizeS
      Layout.fillWidth: true
      visible: root.settingsRoot.timeBasedThemeFiltering
      wrapMode: Text.WordWrap
    }
  }
}
