import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var screen: pluginApi?.panelOpenScreen || null

  readonly property bool allowAttach: Settings.data.ui.panelsAttachedToBar
  readonly property string barPosition: Settings.data.bar.position

  // Panel positioning (passed to PluginPanelSlot)
  // When not attached, default to top-centered to prevent resizing from jumping vertically
  property bool panelAnchorHorizontalCenter: true
  property bool panelAnchorVerticalCenter: allowAttach ? (barPosition === "left" || barPosition === "right") : false
  property bool panelAnchorTop: allowAttach ? (barPosition === "top") : true
  property bool panelAnchorBottom: allowAttach && (barPosition === "bottom")
  property bool panelAnchorLeft: allowAttach && (barPosition === "left")
  property bool panelAnchorRight: allowAttach && (barPosition === "right")

  readonly property int contentPreferredWidth: Math.round(340 * Style.uiScaleRatio)
  readonly property int contentPreferredHeight: mainColumn.implicitHeight + (Style.marginL * 2)
  readonly property real maxListHeight: 300 * Style.uiScaleRatio

  readonly property var pluginMain: pluginApi?.mainInstance

  function trOrDefault(key, fallback) {
    if (pluginApi && pluginApi.tr) {
      const value = pluginApi.tr(key);
      const isPlaceholder = value && value.startsWith("!!") && value.endsWith("!!");
      if (value && !value.startsWith("##") && !isPlaceholder)
        return value;
    }
    return fallback;
  }

  readonly property string titleText: trOrDefault("title", "Omarchy")
  readonly property string settingsHintText: trOrDefault("panel.settings-hint", "Configure Omarchy paths from Settings → Plugins → Omarchy.")
  readonly property string noThemesText: trOrDefault("errors.no-themes", "No themes found")

  readonly property bool isActive: pluginApi?.pluginSettings?.active || false
  readonly property bool showSearchInput: pluginApi?.pluginSettings?.showSearchInput !== false

  onVisibleChanged: {
    if (visible) {
      searchQuery = "";
      if (searchInput) {
        searchInput.text = "";
        if (showSearchInput) {
          searchInput.forceActiveFocus();
        }
      }
    }
  }

  property string themeFilter: "all"
  property string searchQuery: ""

  readonly property string themeFilterLabel: themeFilter === "dark"
                                          ? trOrDefault("filters.dark", "Dark")
                                          : (themeFilter === "light"
                                             ? trOrDefault("filters.light", "Light")
                                             : trOrDefault("filters.all", "All"))

  readonly property var filteredThemes: {
    const themes = pluginMain?.availableThemes || [];
    let filtered = themes;

    if (themeFilter !== "all") {
      filtered = filtered.filter(theme => {
        const mode = typeof theme === "object" ? theme.mode : "";
        return mode === themeFilter;
      });
    }

    if (searchQuery.trim() !== "") {
      const query = searchQuery.toLowerCase().trim();
      filtered = filtered.filter(theme => {
        const name = (typeof theme === "string" ? theme : theme.name).toLowerCase();
        return name.includes(query);
      });
    }

    return filtered;
  }

  function preferredThemeFilter() {
    const hour = new Date().getHours();
    return (hour >= 18 || hour < 6) ? "dark" : "light";
  }

  function cycleThemeFilter() {
    searchQuery = "";
    if (searchInput) searchInput.text = "";

    if (themeFilter === "all") {
      themeFilter = preferredThemeFilter();
    } else {
      themeFilter = themeFilter === "light" ? "dark" : "light";
    }
  }

  ColumnLayout {
    id: mainColumn
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Style.marginL
    spacing: Style.marginM

    // Header card
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: headerRow.implicitHeight + (Style.marginM * 2)

      RowLayout {
        id: headerRow
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NIcon {
          Layout.alignment: Qt.AlignVCenter
          icon: "palette"
          pointSize: Style.fontSizeXXL
          color: Color.mPrimary
        }

        NText {
          Layout.alignment: Qt.AlignVCenter
          Layout.fillWidth: true
          text: titleText
          font.weight: Style.fontWeightBold
          pointSize: Style.fontSizeL
          color: Color.mOnSurface
        }

        Rectangle {
          id: themeFilterButton
          Layout.alignment: Qt.AlignVCenter
          Layout.preferredHeight: Style.toOdd(Style.baseWidgetSize * 0.8)
          Layout.preferredWidth: filterLabel.implicitWidth + (Style.marginM * 2)
          radius: Style.radiusM
          color: filterHover.containsMouse ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.08) : Color.mSurface
          border.width: Style.borderS
          border.color: filterHover.containsMouse ? Color.mPrimary : Color.mOutline

          NText {
            id: filterLabel
            anchors.centerIn: parent
            text: themeFilterLabel
            pointSize: Style.fontSizeS
            font.weight: Style.fontWeightMedium
            color: Color.mOnSurface
          }

          MouseArea {
            id: filterHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cycleThemeFilter()
          }
        }

        NIconButton {
          Layout.alignment: Qt.AlignVCenter
          icon: "close"
          baseSize: Style.baseWidgetSize * 0.8
          tooltipText: trOrDefault("tooltips.close", "Close")
          onClicked: pluginApi?.closePanel(root.screen)
        }
      }
    }

    // Search bar
    NBox {
      visible: showSearchInput
      Layout.fillWidth: true
      Layout.preferredHeight: Math.round(34 * Style.uiScaleRatio)
      color: Color.mSurfaceVariant

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.marginM
        anchors.rightMargin: Style.marginS
        spacing: Style.marginS

        NIcon {
          icon: "search"
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          Layout.alignment: Qt.AlignVCenter
        }

        TextField {
          id: searchInput
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.alignment: Qt.AlignVCenter
          text: searchQuery
          color: Color.mOnSurface
          font.family: Settings.data.ui.fontDefault
          font.pointSize: Style.fontSizeS * (Settings.data.ui.fontDefaultScale * Style.uiScaleRatio)
          font.weight: Style.fontWeightMedium
          verticalAlignment: TextInput.AlignVCenter
          selectByMouse: true
          selectionColor: Color.mPrimary
          selectedTextColor: Color.mOnPrimary
          background: null
          leftPadding: 0
          rightPadding: 0
          topPadding: 0
          bottomPadding: 0

          onTextChanged: {
            if (searchQuery !== text)
              searchQuery = text
          }

          NText {
            text: trOrDefault("panel.search-placeholder", "Search themes...")
            visible: searchInput.text === "" && !searchInput.activeFocus
            color: Color.mOnSurfaceVariant
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            pointSize: Style.fontSizeS
          }

          Component.onCompleted: forceActiveFocus()
        }

        NIconButton {
          icon: "circle-x"
          visible: searchQuery !== ""
          baseSize: Style.baseWidgetSize * 0.65
          Layout.alignment: Qt.AlignVCenter
          onClicked: {
            searchQuery = "";
            searchInput.text = "";
            searchInput.forceActiveFocus();
          }
        }
      }
    }

    // Theme list
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.min(themeListLayout.implicitHeight + (Style.marginM * 2), maxListHeight)

      NScrollView {
        id: themeScrollView
        anchors.fill: parent
        anchors.margins: Style.marginM
        horizontalPolicy: ScrollBar.AlwaysOff
        verticalPolicy: ScrollBar.AsNeeded
        clip: true

        ColumnLayout {
          id: themeListLayout
          width: parent.width
          spacing: Style.marginS

          Repeater {
            model: filteredThemes

            delegate: Rectangle {
              id: entry
              required property var modelData
              required property int index

              readonly property var theme: modelData
              readonly property string themeName: typeof theme === 'string' ? theme : theme.name
              readonly property var themeColors: typeof theme === 'object' ? theme.colors : []
              readonly property bool isCurrentTheme: themeName === pluginMain?.themeName
              readonly property bool hovered: hoverArea.containsMouse

              Layout.fillWidth: true
              implicitHeight: rowLayout.implicitHeight + (Style.marginS * 2)
              radius: Style.radiusM
              color: isCurrentTheme ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.08) : (hovered ? Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.05) : Color.mSurface)
              border.width: Style.borderS
              border.color: isCurrentTheme ? Color.mPrimary : (hovered ? Color.mPrimary : Color.mOutline)

              RowLayout {
                id: rowLayout
                anchors.fill: parent
                anchors.margins: Style.marginS
                spacing: Style.marginM

                NText {
                  Layout.fillWidth: true
                  color: Color.mOnSurface
                  text: entry.themeName
                  pointSize: Style.fontSizeM
                  font.weight: isCurrentTheme ? Style.fontWeightBold : Style.fontWeightMedium
                  verticalAlignment: Text.AlignVCenter
                  elide: Text.ElideRight
                }

                Row {
                  spacing: Style.marginXS / 2
                  visible: entry.themeColors.length > 0

                  Repeater {
                    model: entry.themeColors

                    Rectangle {
                      width: Style.fontSizeM * 0.9
                      height: Style.fontSizeM * 0.9
                      radius: width / 2
                      color: modelData
                      border.color: Qt.darker(modelData, 1.2)
                      border.width: Style.borderS
                    }
                  }
                }
              }

              MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                  pluginMain?.setTheme(entry.themeName);
                  if (pluginApi) {
                    pluginApi.closePanel(root.screen);
                  }
                }
              }
            }
          }

          NText {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.baseWidgetSize * 2
            visible: !filteredThemes || filteredThemes.length === 0
            text: noThemesText
            pointSize: Style.fontSizeM
            color: Color.mOnSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
          }
        }
      }
    }

  }
}
