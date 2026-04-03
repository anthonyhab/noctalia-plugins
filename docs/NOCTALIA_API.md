# Noctalia Shell API Reference

Comprehensive reference for `qs.Widgets`, `qs.Commons`, and `qs.Services.UI` generated from `/tmp/noctalia-shell`.

## Import Patterns

```qml
import qs.Widgets
import qs.Commons
import qs.Services.UI
```

## qs.Widgets

Documented widgets: **55** (`N*.qml` including `AudioSpectrum/`).

### `NIconButton`

Source: `/tmp/noctalia-shell/Widgets/NIconButton.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`baseSize`|`real`|`Style.baseWidgetSize`|baseSize property.|
|`applyUiScale`|`bool`|`true`|applyUiScale property.|
|`icon`|`string`|`—`|icon property.|
|`tooltipText`|`var`|`—`|tooltipText property.|
|`tooltipDirection`|`string`|`"auto"`|tooltipDirection property.|
|`allowClickWhenDisabled`|`bool`|`false`|allowClickWhenDisabled property.|
|`handleWheel`|`bool`|`false`|handleWheel property.|
|`hovering`|`bool`|`false`|hovering property.|
|`colorBg`|`color`|`Color.smartAlpha(Color.mSurfaceVariant)`|colorBg property.|
|`colorFg`|`color`|`Color.mPrimary`|colorFg property.|
|`colorBgHover`|`color`|`Color.mHover`|colorBgHover property.|
|`colorFgHover`|`color`|`Color.mOnHover`|colorFgHover property.|
|`colorBorder`|`color`|`Color.mOutline`|colorBorder property.|
|`colorBorderHover`|`color`|`Color.mOutline`|colorBorderHover property.|
|`customRadius`|`real`|`-1`|-1 means use default (iRadiusL), otherwise use this value|
|`border`|`alias`|`visualButton.border`|Expose border properties for backwards compatibility (aliases to visualButton)|
|`radius`|`alias`|`visualButton.radius`|radius property.|
|`color`|`alias`|`visualButton.color`|color property.|
|`buttonSize`|`real`|`applyUiScale ? Style.toOdd(baseSize * Style.uiScaleRatio) : Style.toOdd(baseSize)`|Calculate button size based on settings|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`entered`|`(—)`|Emitted on entered.|
|`exited`|`(—)`|Emitted on exited.|
|`clicked`|`(—)`|Emitted on clicked.|
|`rightClicked`|`(—)`|Emitted on rightClicked.|
|`middleClicked`|`(—)`|Emitted on middleClicked.|
|`wheel`|`(int angleDelta)`|Emitted on wheel.|

#### Example
```qml
NIconButton { icon: "settings" }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NIconButtonHot`

Source: `/tmp/noctalia-shell/Widgets/NIconButtonHot.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`baseSize`|`real`|`Style.baseWidgetSize`|Public properties|
|`applyUiScale`|`bool`|`true`|applyUiScale property.|
|`icon`|`string`|`—`|icon property.|
|`tooltipText`|`var`|`—`|tooltipText property.|
|`tooltipDirection`|`string`|`"auto"`|tooltipDirection property.|
|`allowClickWhenDisabled`|`bool`|`false`|allowClickWhenDisabled property.|
|`hot`|`bool`|`false`|hot property.|
|`hovering`|`bool`|`false`|Internal properties|
|`pressed`|`bool`|`false`|pressed property.|
|`colorBg`|`color`|`Color.smartAlpha(Color.mSurfaceVariant)`|Color properties|
|`colorFg`|`color`|`Color.mPrimary`|colorFg property.|
|`colorBgHover`|`color`|`Color.mHover`|colorBgHover property.|
|`colorFgHover`|`color`|`Color.mOnHover`|colorFgHover property.|
|`colorBorder`|`color`|`Color.mOutline`|colorBorder property.|
|`colorBorderHover`|`color`|`Color.mOutline`|colorBorderHover property.|
|`colorBgHot`|`color`|`Color.mPrimary`|Hot state colors|
|`colorFgHot`|`color`|`Color.mOnPrimary`|colorFgHot property.|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`entered`|`(—)`|Signals|
|`exited`|`(—)`|Emitted on exited.|
|`clicked`|`(—)`|Emitted on clicked.|
|`rightClicked`|`(—)`|Emitted on rightClicked.|
|`middleClicked`|`(—)`|Emitted on middleClicked.|

#### Example
```qml
NIconButtonHot { icon: "settings" }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NButton`

Source: `/tmp/noctalia-shell/Widgets/NButton.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`text`|`string`|`""`|Public properties|
|`icon`|`string`|`""`|icon property.|
|`tooltipText`|`var`|`—`|tooltipText property.|
|`backgroundColor`|`color`|`Color.mPrimary`|backgroundColor property.|
|`textColor`|`color`|`Color.mOnPrimary`|textColor property.|
|`hoverColor`|`color`|`Color.mHover`|hoverColor property.|
|`textHoverColor`|`color`|`Color.mOnHover`|textHoverColor property.|
|`fontSize`|`real`|`Style.fontSizeM`|fontSize property.|
|`fontWeight`|`int`|`Style.fontWeightSemiBold`|fontWeight property.|
|`iconSize`|`real`|`Style.fontSizeL`|iconSize property.|
|`outlined`|`bool`|`false`|outlined property.|
|`horizontalAlignment`|`int`|`Qt.AlignHCenter`|horizontalAlignment property.|
|`buttonRadius`|`real`|`Style.iRadiusS`|buttonRadius property.|
|`hovered`|`bool`|`false`|Internal properties|
|`contentColor`|`color`|`{`|contentColor property (readonly).|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`clicked`|`(—)`|Signals|
|`rightClicked`|`(—)`|Emitted on rightClicked.|
|`middleClicked`|`(—)`|Emitted on middleClicked.|
|`entered`|`(—)`|Emitted on entered.|
|`exited`|`(—)`|Emitted on exited.|

#### Example
```qml
NButton { text: I18n.tr("common.ok") }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NBox`

Source: `/tmp/noctalia-shell/Widgets/NBox.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`color`|`color`|`Color.mSurfaceVariant`|color property.|
|`forceOpaque`|`bool`|`false`|forceOpaque property.|
|`radius`|`alias`|`bg.radius`|radius property.|
|`border`|`alias`|`bg.border`|border property.|

#### Signals
_None._

#### Example
```qml
NBox { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NTextInput`

Source: `/tmp/noctalia-shell/Widgets/NTextInput.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`label`|`string`|`""`|label property.|
|`description`|`string`|`""`|description property.|
|`inputIconName`|`string`|`""`|inputIconName property.|
|`readOnly`|`bool`|`false`|readOnly property.|
|`labelColor`|`color`|`Color.mOnSurface`|labelColor property.|
|`descriptionColor`|`color`|`Color.mOnSurfaceVariant`|descriptionColor property.|
|`fontFamily`|`string`|`Settings.data.ui.fontDefault`|fontFamily property.|
|`fontSize`|`real`|`Style.fontSizeS`|fontSize property.|
|`fontWeight`|`int`|`Style.fontWeightRegular`|fontWeight property.|
|`defaultValue`|`var`|`undefined`|defaultValue property.|
|`settingsPath`|`string`|`""`|settingsPath property.|
|`radius`|`real`|`Style.iRadiusM`|radius property.|
|`minimumInputWidth`|`real`|`80 * Style.uiScaleRatio`|minimumInputWidth property.|
|`showClearButton`|`bool`|`true`|showClearButton property.|
|`text`|`alias`|`input.text`|text property.|
|`placeholderText`|`alias`|`input.placeholderText`|placeholderText property.|
|`inputMethodHints`|`alias`|`input.inputMethodHints`|inputMethodHints property.|
|`horizontalAlignment`|`alias`|`input.horizontalAlignment`|horizontalAlignment property.|
|`inputItem`|`alias`|`input`|inputItem property.|
|`isValueChanged`|`bool`|`(defaultValue !== undefined) && (text !== defaultValue)`|isValueChanged property (readonly).|
|`indicatorTooltip`|`string`|`defaultValue !== undefined ? I18n.tr("panels.indicator.default-value", {`|indicatorTooltip property (readonly).|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`editingFinished`|`(—)`|Emitted on editingFinished.|
|`accepted`|`(—)`|Emitted on accepted.|

#### Example
```qml
NTextInput { text: I18n.tr("common.ok") }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NComboBox`

Source: `/tmp/noctalia-shell/Widgets/NComboBox.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`minimumWidth`|`real`|`200`|minimumWidth property.|
|`popupHeight`|`real`|`180`|popupHeight property.|
|`label`|`string`|`""`|label property.|
|`description`|`string`|`""`|description property.|
|`tooltip`|`string`|`""`|tooltip property.|
|`model`|`var`|`—`|model property.|
|`currentKey`|`string`|`""`|currentKey property.|
|`placeholder`|`string`|`""`|placeholder property.|
|`defaultValue`|`var`|`undefined`|defaultValue property.|
|`settingsPath`|`string`|`""`|settingsPath property.|
|`baseSize`|`real`|`1.0`|baseSize property.|
|`preferredHeight`|`real`|`Math.round(Style.baseWidgetSize * 1.1 * root.baseSize)`|preferredHeight property (readonly).|
|`comboBox`|`var`|`combo`|comboBox property (readonly).|
|`isValueChanged`|`bool`|`(defaultValue !== undefined) && (currentKey != defaultValue)`|Less strict comparison with != (instead of !==) so it can properly compare int vs string (ex for FPS: 30 and "30")|
|`indicatorTooltip`|`string`|`{`|indicatorTooltip property (readonly).|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`selected`|`(string key)`|Emitted on selected.|

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`itemCount`|`(—)`|Method itemCount.|
|`getItem`|`(index)`|Method getItem.|
|`findIndexByKey`|`(key)`|Method findIndexByKey.|

#### Example
```qml
NComboBox { label: I18n.tr("common.settings") }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NToggle`

Source: `/tmp/noctalia-shell/Widgets/NToggle.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`label`|`string`|`""`|label property.|
|`description`|`string`|`""`|description property.|
|`icon`|`string`|`""`|icon property.|
|`checked`|`bool`|`false`|checked property.|
|`hovering`|`bool`|`false`|hovering property.|
|`baseSize`|`int`|`Math.round(Style.baseWidgetSize * 0.8 * Style.uiScaleRatio)`|baseSize property.|
|`defaultValue`|`var`|`undefined`|defaultValue property.|
|`settingsPath`|`string`|`""`|settingsPath property.|
|`isValueChanged`|`bool`|`(defaultValue !== undefined) && (checked !== defaultValue)`|isValueChanged property (readonly).|
|`indicatorTooltip`|`string`|`defaultValue !== undefined ? I18n.tr("panels.indicator.default-value", {`|indicatorTooltip property (readonly).|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`toggled`|`(bool checked)`|Emitted on toggled.|
|`entered`|`(—)`|Emitted on entered.|
|`exited`|`(—)`|Emitted on exited.|

#### Example
```qml
NToggle { label: I18n.tr("common.settings") }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NCheckbox`

Source: `/tmp/noctalia-shell/Widgets/NCheckbox.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`label`|`string`|`""`|Public API|
|`description`|`string`|`""`|description property.|
|`checked`|`bool`|`false`|checked property.|
|`hovering`|`bool`|`false`|hovering property.|
|`activeColor`|`color`|`Color.mPrimary`|activeColor property.|
|`activeOnColor`|`color`|`Color.mOnPrimary`|activeOnColor property.|
|`baseSize`|`int`|`root.defaultSize`|baseSize property.|
|`labelSize`|`real`|`Style.fontSizeL`|labelSize property.|
|`defaultSize`|`int`|`Style.baseWidgetSize * 0.7`|defaultSize property (readonly).|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`toggled`|`(bool checked)`|Emitted on toggled.|
|`entered`|`(—)`|Emitted on entered.|
|`exited`|`(—)`|Emitted on exited.|

#### Example
```qml
NCheckbox { label: I18n.tr("common.settings") }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NSlider`

Source: `/tmp/noctalia-shell/Widgets/NSlider.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`sliderActive`|`bool`|`activeFocus \|\| pressed`|sliderActive property (readonly).|
|`fillColor`|`color`|`Color.mPrimary`|fillColor property.|
|`cutoutColor`|`var`|`Color.mSurface`|cutoutColor property.|
|`snapAlways`|`bool`|`true`|snapAlways property.|
|`heightRatio`|`real`|`0.7`|heightRatio property.|
|`tooltipText`|`var`|`—`|tooltipText property.|
|`tooltipDirection`|`string`|`"auto"`|tooltipDirection property.|
|`hovering`|`bool`|`false`|hovering property.|
|`effectiveFillColor`|`color`|`enabled ? fillColor : Color.mOutline`|effectiveFillColor property (readonly).|
|`knobDiameter`|`real`|`Math.round((Style.baseWidgetSize * heightRatio * Style.uiScaleRatio) / 2) * 2`|knobDiameter property (readonly).|
|`trackHeight`|`real`|`Math.round((knobDiameter * 0.4 * Style.uiScaleRatio) / 2) * 2`|trackHeight property (readonly).|
|`trackRadius`|`real`|`Math.min(Style.iRadiusL, trackHeight / 2)`|trackRadius property (readonly).|
|`cutoutExtra`|`real`|`Math.round((Style.baseWidgetSize * 0.1 * Style.uiScaleRatio) / 2) * 2`|cutoutExtra property (readonly).|

#### Signals
_None._

#### Example
```qml
NSlider { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NSpinBox`

Source: `/tmp/noctalia-shell/Widgets/NSpinBox.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`value`|`int`|`0`|Public properties|
|`from`|`int`|`0`|from property.|
|`to`|`int`|`100`|to property.|
|`stepSize`|`int`|`1`|stepSize property.|
|`suffix`|`string`|`""`|suffix property.|
|`prefix`|`string`|`""`|prefix property.|
|`label`|`string`|`""`|label property.|
|`description`|`string`|`""`|description property.|
|`hovering`|`bool`|`false`|hovering property.|
|`baseSize`|`int`|`Style.baseWidgetSize`|baseSize property.|
|`defaultValue`|`var`|`undefined`|defaultValue property.|
|`settingsPath`|`string`|`""`|settingsPath property.|
|`minimum`|`alias`|`root.from`|Convenience properties for common naming|
|`maximum`|`alias`|`root.to`|maximum property.|
|`initialRepeatDelay`|`int`|`400`|Properties for repeating|
|`repeatInterval`|`int`|`80`|How often to step up after fist pause (ms)|
|`rampFactor`|`int`|`4`|How many ticks to wait before increasing the step multiplier|
|`maxStepMultiplier`|`int`|`10`|The max step (e.g., 10 * stepSize)|
|`_holdTicks`|`int`|`0`|Internal counter for hold duration|
|`_repeatDirection`|`int`|`0`|-1 for decrease, 1 for increase|
|`isValueChanged`|`bool`|`(defaultValue !== undefined) && (value !== defaultValue)`|isValueChanged property (readonly).|
|`indicatorTooltip`|`string`|`defaultValue !== undefined ? I18n.tr("panels.indicator.default-value", {`|indicatorTooltip property (readonly).|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`entered`|`(—)`|Emitted on entered.|
|`exited`|`(—)`|Emitted on exited.|

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`changeValue`|`(direction, step)`|Method changeValue.|
|`stopRepeat`|`(—)`|Method stopRepeat.|

#### Example
```qml
NSpinBox { label: I18n.tr("common.settings") }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NPopupContextMenu`

Source: `/tmp/noctalia-shell/Widgets/NPopupContextMenu.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`model`|`alias`|`repeater.model`|model property.|
|`itemHeight`|`real`|`28`|Match TrayMenu|
|`itemPadding`|`real`|`Style.marginM`|itemPadding property.|
|`verticalPolicy`|`int`|`ScrollBar.AsNeeded`|verticalPolicy property.|
|`horizontalPolicy`|`int`|`ScrollBar.AsNeeded`|horizontalPolicy property.|
|`anchorItem`|`var`|`null`|anchorItem property.|
|`screen`|`ShellScreen`|`null`|screen property.|
|`minWidth`|`real`|`120`|minWidth property.|
|`calculatedWidth`|`real`|`180`|calculatedWidth property.|
|`targetOffsetX`|`real`|`0`|Explicit offset for centering on target item (computed from targetItem in openAtItem)|
|`targetOffsetY`|`real`|`0`|targetOffsetY property.|
|`targetWidth`|`real`|`0`|targetWidth property.|
|`targetHeight`|`real`|`0`|targetHeight property.|
|`barPosition`|`string`|`Settings.getBarPositionForScreen(screen?.name)`|barPosition property (readonly).|
|`barHeight`|`real`|`Style.getBarHeightForScreen(screen?.name)`|barHeight property (readonly).|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`triggered`|`(string action, var item)`|Emitted on triggered.|

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`calculateWidth`|`(—)`|Method calculateWidth.|
|`openAtItem`|`(item, itemScreen, centerOnItem)`|Helper function to open context menu anchored to an item Position is calculated automatically based on bar position and screen boundaries Optional centerOnItem: if provided, menu will be horizontally centered on this item instead of anchorItem|
|`close`|`(—)`|Method close.|
|`closeMenu`|`(—)`|Method closeMenu.|

#### Example
```qml
NPopupContextMenu { model: [] }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NDivider`

Source: `/tmp/noctalia-shell/Widgets/NDivider.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`vertical`|`bool`|`false`|vertical property.|

#### Signals
_None._

#### Example
```qml
NDivider { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NScrollView`

Source: `/tmp/noctalia-shell/Widgets/NScrollView.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`handleColor`|`color`|`Qt.alpha(Color.mHover, 0.8)`|handleColor property.|
|`handleHoverColor`|`color`|`handleColor`|handleHoverColor property.|
|`handlePressedColor`|`color`|`handleColor`|handlePressedColor property.|
|`trackColor`|`color`|`"transparent"`|trackColor property.|
|`handleWidth`|`real`|`Math.round(6 * Style.uiScaleRatio)`|handleWidth property.|
|`handleRadius`|`real`|`Style.iRadiusM`|handleRadius property.|
|`verticalPolicy`|`int`|`ScrollBar.AsNeeded`|verticalPolicy property.|
|`horizontalPolicy`|`int`|`ScrollBar.AsNeeded`|horizontalPolicy property.|
|`preventHorizontalScroll`|`bool`|`horizontalPolicy === ScrollBar.AlwaysOff`|preventHorizontalScroll property.|
|`boundsBehavior`|`int`|`Flickable.StopAtBounds`|boundsBehavior property.|
|`verticalScrollable`|`bool`|`(contentItem.contentHeight > contentItem.height) \|\| (verticalPolicy == ScrollBar.AlwaysOn)`|verticalScrollable property (readonly).|
|`horizontalScrollable`|`bool`|`(contentItem.contentWidth > contentItem.width) \|\| (horizontalPolicy == ScrollBar.AlwaysOn)`|horizontalScrollable property (readonly).|
|`showGradientMasks`|`bool`|`true`|showGradientMasks property.|
|`gradientColor`|`color`|`Color.mSurfaceVariant`|gradientColor property.|
|`gradientHeight`|`int`|`16`|gradientHeight property.|
|`reserveScrollbarSpace`|`bool`|`true`|reserveScrollbarSpace property.|
|`userRightPadding`|`real`|`0`|userRightPadding property.|
|`showScrollbarWhenScrollable`|`bool`|`Settings.data.ui.scrollbarAlwaysVisible`|Keep scrollbars visible whenever overflow exists (without forcing visibility when not scrollable)|
|`wheelScrollMultiplier`|`real`|`2.0`|Scroll speed multiplier for mouse wheel (1.0 = default, higher = faster)|
|`smoothWheelAnimationDuration`|`int`|`Style.animationNormal`|smoothWheelAnimationDuration property.|
|`_wheelTargetY`|`real`|`0`|_wheelTargetY property.|
|`_internalFlickable`|`Flickable`|`null`|Reference to the internal Flickable for wheel handling|

#### Signals
_None._

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`clampScrollY`|`(value)`|Method clampScrollY.|
|`applyWheelScroll`|`(delta)`|Method applyWheelScroll.|
|`createGradients`|`(—)`|Dynamically create gradient overlays to avoid interfering with ScrollView content management|
|`configureFlickable`|`(—)`|Function to configure the underlying Flickable|

#### Example
```qml
NScrollView { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NFilePicker`

Source: `/tmp/noctalia-shell/Widgets/NFilePicker.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`title`|`string`|`I18n.tr("widget.file-picker.title")`|Properties|
|`initialPath`|`string`|`Quickshell.env("HOME") \|\| "/home"`|initialPath property.|
|`selectionMode`|`string`|`"files"`|"files" or "folders"|
|`nameFilters`|`var`|`["*"]`|nameFilters property.|
|`showDirs`|`bool`|`true`|showDirs property.|
|`showHiddenFiles`|`bool`|`false`|showHiddenFiles property.|
|`allowMultiSelection`|`bool`|`false`|allowMultiSelection property.|
|`selectedPaths`|`var`|`[]`|selectedPaths property.|
|`currentPath`|`string`|`initialPath`|currentPath property.|
|`shouldResetSelection`|`bool`|`false`|shouldResetSelection property.|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`accepted`|`(var paths)`|Signals|
|`cancelled`|`(—)`|Emitted on cancelled.|

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`openFilePicker`|`(—)`|Method openFilePicker.|
|`getFileIcon`|`(fileName)`|Method getFileIcon.|
|`formatFileSize`|`(bytes)`|Method formatFileSize.|
|`confirmSelection`|`(—)`|Method confirmSelection.|
|`updateFilteredModel`|`(—)`|Method updateFilteredModel.|

#### Example
```qml
NFilePicker { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NLabel`

Source: `/tmp/noctalia-shell/Widgets/NLabel.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`label`|`string`|`""`|label property.|
|`description`|`string`|`""`|description property.|
|`icon`|`string`|`""`|icon property.|
|`labelColor`|`color`|`Color.mOnSurface`|labelColor property.|
|`descriptionColor`|`color`|`Color.mOnSurfaceVariant`|descriptionColor property.|
|`iconColor`|`color`|`Color.mOnSurface`|iconColor property.|
|`showIndicator`|`bool`|`false`|showIndicator property.|
|`indicatorTooltip`|`string`|`""`|indicatorTooltip property.|
|`labelSize`|`real`|`Style.fontSizeL`|labelSize property.|

#### Signals
_None._

#### Example
```qml
NLabel { label: I18n.tr("common.settings") }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NBattery`

Source: `/tmp/noctalia-shell/Widgets/NBattery.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`percentage`|`real`|`—`|Data (must be provided by parent)|
|`charging`|`bool`|`—`|charging property (required).|
|`pluggedIn`|`bool`|`—`|pluggedIn property (required).|
|`ready`|`bool`|`—`|ready property (required).|
|`low`|`bool`|`—`|low property (required).|
|`critical`|`bool`|`—`|critical property (required).|
|`baseSize`|`real`|`Style.fontSizeM`|Sizing - baseSize controls overall scaleFactor for bar/panel usage|
|`baseColor`|`color`|`Color.mOnSurface`|Styling - no hardcoded colors, only theme colors|
|`lowColor`|`color`|`Color.mError`|lowColor property.|
|`chargingColor`|`color`|`Color.mPrimary`|chargingColor property.|
|`textColor`|`color`|`Color.mSurface`|textColor property.|
|`showPercentageText`|`bool`|`true`|Display options|
|`vertical`|`bool`|`false`|vertical property.|
|`showStateIcon`|`bool`|`false`|Alternating state icon display (toggles between percentage and icon when charging)|
|`scaleFactor`|`real`|`baseSize / Style.fontSizeM`|Internal sizing calculations based on baseSize|
|`bodyWidth`|`real`|`{`|bodyWidth property (readonly).|
|`bodyHeight`|`real`|`Style.toOdd(14 * scaleFactor)`|bodyHeight property (readonly).|
|`terminalWidth`|`real`|`Math.round(2.5 * scaleFactor)`|terminalWidth property (readonly).|
|`terminalHeight`|`real`|`Math.round(7 * scaleFactor)`|terminalHeight property (readonly).|
|`cornerRadius`|`real`|`Math.round(3 * scaleFactor)`|cornerRadius property (readonly).|
|`totalWidth`|`real`|`vertical ? bodyHeight : bodyWidth + terminalWidth`|Total size is just body + terminal (no external icon)|
|`totalHeight`|`real`|`vertical ? bodyWidth + terminalWidth : bodyHeight`|totalHeight property (readonly).|
|`activeColor`|`color`|`{`|Determine active color based on state|
|`emptyColor`|`color`|`Qt.alpha(baseColor, 0.66)`|Background color for empty portion (semi-transparent)|
|`stateIcon`|`string`|`{`|State icon logic|
|`animatedPercentage`|`real`|`percentage`|Animated percentage for smooth transitions|

#### Signals
_None._

#### Example
```qml
NBattery { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NBusyIndicator`

Source: `/tmp/noctalia-shell/Widgets/NBusyIndicator.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`running`|`bool`|`true`|running property.|
|`color`|`color`|`Color.mPrimary`|color property.|
|`size`|`int`|`Style.baseWidgetSize`|size property.|
|`strokeWidth`|`int`|`Style.borderL`|strokeWidth property.|
|`duration`|`int`|`Style.animationSlow * 2`|duration property.|

#### Signals
_None._

#### Example
```qml
NBusyIndicator { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NCircleStat`

Source: `/tmp/noctalia-shell/Widgets/NCircleStat.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`ratio`|`real`|`0`|0..1 range|
|`icon`|`string`|`""`|icon property.|
|`suffix`|`string`|`"%"`|suffix property.|
|`contentScale`|`real`|`1.0`|contentScale property.|
|`fillColor`|`color`|`Color.mPrimary`|fillColor property.|
|`tooltipText`|`var`|`—`|tooltipText property.|
|`tooltipDirection`|`string`|`"top"`|tooltipDirection property.|
|`_gaugeSize`|`real`|`60 * contentScale`|Arc geometry constants|
|`_lineWidth`|`real`|`6 * contentScale`|_lineWidth property (readonly).|
|`_arcRadius`|`real`|`_gaugeSize / 2 - 5 * contentScale`|_arcRadius property (readonly).|
|`_arcBottomY`|`real`|`_gaugeSize / 2 + _arcRadius * 0.5 + _lineWidth / 2`|Arc goes from 150° to 390° (30°), gap at bottom Bottom of arc is at y = center + radius * sin(30°) = center + radius * 0.5 Plus half line width for stroke|
|`_contentHeight`|`real`|`_arcBottomY + 4 * contentScale`|Height needs to include the icon which sits inside the arc gap Icon is ~12px tall, positioned 4px below text center, need ~4px more padding|
|`animatedRatio`|`real`|`ratio`|Animated ratio for smooth transitions - reduces repaint frequency|

#### Signals
_None._

#### Example
```qml
NCircleStat { icon: "settings" }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NClock`

Source: `/tmp/noctalia-shell/Widgets/NClock.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`now`|`var`|`Time.now`|now property.|
|`clockStyle`|`string`|`"analog"`|Style: "analog" or "digital"|
|`showProgress`|`bool`|`true`|Show seconds progress ring (digital only)|
|`backgroundColor`|`color`|`Color.mPrimary`|Color properties|
|`clockColor`|`color`|`Color.mOnPrimary`|clockColor property.|
|`secondHandColor`|`color`|`{`|secondHandColor property.|
|`progressColor`|`color`|`root.secondHandColor`|progressColor property.|
|`hoursFontSize`|`real`|`Style.fontSizeXS`|Font size properties for digital clock|
|`minutesFontSize`|`real`|`Style.fontSizeXXS`|minutesFontSize property.|
|`hoursFontWeight`|`int`|`Style.fontWeightBold`|hoursFontWeight property.|
|`minutesFontWeight`|`int`|`Style.fontWeightBold`|minutesFontWeight property.|
|`scaleRatio`|`real`|`Style.uiScaleRatio`|Scale ratio for canvas line widths (used by desktop widget scaling)|

#### Signals
_None._

#### Example
```qml
NClock { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NCollapsible`

Source: `/tmp/noctalia-shell/Widgets/NCollapsible.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`label`|`string`|`""`|label property.|
|`description`|`string`|`""`|description property.|
|`expanded`|`bool`|`false`|expanded property.|
|`contentSpacing`|`real`|`Style.marginM`|contentSpacing property.|
|`_userInteracted`|`bool`|`false`|_userInteracted property.|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`toggled`|`(bool expanded)`|Emitted on toggled.|

#### Example
```qml
NCollapsible { label: I18n.tr("common.settings") }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NColorChoice`

Source: `/tmp/noctalia-shell/Widgets/NColorChoice.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`label`|`string`|`I18n.tr("common.select-color")`|label property.|
|`description`|`string`|`I18n.tr("common.select-color-description")`|description property.|
|`tooltip`|`string`|`""`|tooltip property.|
|`currentKey`|`string`|`""`|currentKey property.|
|`defaultValue`|`var`|`undefined`|defaultValue property.|
|`noneColor`|`var`|`undefined`|color declared as var so we can nullify|
|`noneOnColor`|`var`|`undefined`|color declared as var so we can nullify|
|`isValueChanged`|`bool`|`(defaultValue !== undefined) && (currentKey !== defaultValue)`|isValueChanged property (readonly).|
|`indicatorTooltip`|`string`|`{`|indicatorTooltip property (readonly).|
|`diameter`|`int`|`Style.baseWidgetSize * 0.9 * Style.uiScaleRatio`|diameter property (readonly).|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`selected`|`(string key)`|Emitted on selected.|

#### Example
```qml
NColorChoice { label: I18n.tr("common.settings") }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NColorPicker`

Source: `/tmp/noctalia-shell/Widgets/NColorPicker.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`screen`|`var`|`—`|screen property.|
|`selectedColor`|`color`|`"black"`|selectedColor property.|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`colorSelected`|`(color color)`|Emitted on colorSelected.|

#### Example
```qml
NColorPicker { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NColorPickerDialog`

Source: `/tmp/noctalia-shell/Widgets/NColorPickerDialog.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`screen`|`var`|`—`|screen property.|
|`selectedColor`|`color`|`"black"`|selectedColor property.|
|`editMode`|`int`|`NColorPickerDialog.EditMode.R`|editMode property.|
|`stableHue`|`real`|`0`|Code to deal with Hue when color is achromatic|
|`displayHue`|`real`|`selectedColor.hsvHue < 0 ? stableHue : selectedColor.hsvHue`|displayHue property (readonly).|
|`liveMode`|`bool`|`false`|When true: hides Cancel/Apply, emits colorSelected on every color change|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`colorSelected`|`(color color)`|Emitted on colorSelected.|

#### Example
```qml
NColorPickerDialog { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NColorSlider`

Source: `/tmp/noctalia-shell/Widgets/NColorSlider.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`fillColor`|`color`|`"transparent"`|fillColor property.|
|`cutoutColor`|`var`|`Color.mSurface`|cutoutColor property.|
|`snapAlways`|`bool`|`true`|snapAlways property.|
|`widthRatio`|`real`|`0.7`|widthRatio property.|
|`tooltipText`|`var`|`—`|tooltipText property.|
|`tooltipDirection`|`string`|`"auto"`|tooltipDirection property.|
|`hovering`|`bool`|`false`|hovering property.|
|`topColor`|`color`|`"white"`|topColor property.|
|`bottomColor`|`color`|`"black"`|bottomColor property.|
|`rainbowMode`|`bool`|`false`|rainbowMode property.|
|`knobDiameter`|`real`|`Math.round((Style.baseWidgetSize * widthRatio * Style.uiScaleRatio) / 2) * 2`|knobDiameter property (readonly).|
|`trackWidth`|`real`|`Math.round((knobDiameter * 0.4 * Style.uiScaleRatio) / 2) * 2`|trackWidth property (readonly).|
|`trackRadius`|`real`|`Math.min(Style.iRadiusL, trackWidth / 2)`|trackRadius property (readonly).|
|`cutoutExtra`|`real`|`Math.round((Style.baseWidgetSize * 0.1 * Style.uiScaleRatio) / 2) * 2`|cutoutExtra property (readonly).|

#### Signals
_None._

#### Example
```qml
NColorSlider { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NContextMenu`

Source: `/tmp/noctalia-shell/Widgets/NContextMenu.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`model`|`var`|`[]`|model property.|
|`itemHeight`|`real`|`36`|itemHeight property.|
|`itemPadding`|`real`|`Style.marginM`|itemPadding property.|
|`verticalPolicy`|`int`|`ScrollBar.AsNeeded`|verticalPolicy property.|
|`horizontalPolicy`|`int`|`ScrollBar.AsNeeded`|horizontalPolicy property.|
|`constrainTo`|`Item`|`null`|Optional: explicit item whose bounds the menu must stay within. When unset, openAtItem auto-detects the nearest clipping ancestor.|
|`_detectedConstraint`|`Item`|`null`|_detectedConstraint property.|
|`filteredModel`|`var`|`{`|Filter out hidden items to avoid spacing artifacts from zero-height items|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`triggered`|`(string action)`|Emitted on triggered.|

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`openAt`|`(x, y)`|Helper function to open at mouse position|
|`openAtItem`|`(item, mouseX, mouseY)`|Helper function to open at item|

#### Example
```qml
NContextMenu { model: [] }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NDateTimeTokens`

Source: `/tmp/noctalia-shell/Widgets/NDateTimeTokens.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`sampleDate`|`date`|`new Date()`|Dec 25, 2023, 2:30:45.123 PM|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`tokenClicked`|`(string token)`|Emitted on tokenClicked.|

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`getCategoryColor`|`(category)`|Method getCategoryColor.|

#### Example
```qml
NDateTimeTokens { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NDropShadow`

Source: `/tmp/noctalia-shell/Widgets/NDropShadow.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`source`|`var`|`—`|source property (required).|
|`autoPaddingEnabled`|`bool`|`false`|autoPaddingEnabled property.|
|`shadowHorizontalOffset`|`real`|`Settings.data.general.shadowOffsetX`|shadowHorizontalOffset property.|
|`shadowVerticalOffset`|`real`|`Settings.data.general.shadowOffsetY`|shadowVerticalOffset property.|
|`shadowOpacity`|`real`|`Style.shadowOpacity`|shadowOpacity property.|
|`shadowColor`|`color`|`"black"`|shadowColor property.|
|`shadowBlur`|`real`|`Style.shadowBlur`|shadowBlur property.|

#### Signals
_None._

#### Example
```qml
NDropShadow { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NGraph`

Source: `/tmp/noctalia-shell/Widgets/NGraph.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`values`|`var`|`[]`|Primary line|
|`color`|`color`|`Color.mPrimary`|color property.|
|`values2`|`var`|`[]`|Optional secondary line|
|`color2`|`color`|`Color.mError`|color2 property.|
|`minValue`|`real`|`0`|Range settings for primary line|
|`maxValue`|`real`|`100`|maxValue property.|
|`minValue2`|`real`|`minValue`|Range settings for secondary line (defaults to primary range)|
|`maxValue2`|`real`|`maxValue`|maxValue2 property.|
|`strokeWidth`|`real`|`1`|Style settings|
|`fill`|`bool`|`true`|fill property.|
|`fillOpacity`|`real`|`0.15`|fillOpacity property.|
|`antialiasing`|`real`|`0.5`|antialiasing property.|
|`updateInterval`|`int`|`1000`|Smooth scrolling interval (how often data updates)|
|`animateScale`|`bool`|`false`|Animate scale changes (for network graphs with dynamic max)|
|`curvePadding`|`real`|`0.12`|Vertical padding (percentage of range) to keep values from touching edges|
|`hasData`|`bool`|`values.length >= 4`|hasData property (readonly).|
|`hasData2`|`bool`|`values2.length >= 4`|hasData2 property (readonly).|
|`_targetMax1`|`real`|`maxValue`|Scale animation state|
|`_targetMax2`|`real`|`maxValue2`|_targetMax2 property.|
|`_animMax1`|`real`|`maxValue`|_animMax1 property.|
|`_animMax2`|`real`|`maxValue2`|_animMax2 property.|
|`_effectiveMax1`|`real`|`animateScale ? _animMax1 : maxValue`|Effective max values (animated or direct)|
|`_effectiveMax2`|`real`|`animateScale ? _animMax2 : maxValue2`|_effectiveMax2 property (readonly).|
|`_t1`|`real`|`1.0`|Scroll state (driven by NumberAnimation)|
|`_ready1`|`bool`|`false`|_ready1 property.|
|`_pred1`|`real`|`0`|_pred1 property.|
|`_t2`|`real`|`1.0`|_t2 property.|
|`_ready2`|`bool`|`false`|_ready2 property.|
|`_pred2`|`real`|`0`|_pred2 property.|

#### Signals
_None._

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`_normalize`|`(val, minVal, maxVal)`|Normalize a value to [0, 1] with padding applied|

#### Example
```qml
NGraph { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NGridView`

Source: `/tmp/noctalia-shell/Widgets/NGridView.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`handleColor`|`color`|`Qt.alpha(Color.mHover, 0.8)`|handleColor property.|
|`handleHoverColor`|`color`|`handleColor`|handleHoverColor property.|
|`handlePressedColor`|`color`|`handleColor`|handlePressedColor property.|
|`trackColor`|`color`|`"transparent"`|trackColor property.|
|`handleWidth`|`real`|`6`|handleWidth property.|
|`handleRadius`|`real`|`Style.iRadiusM`|handleRadius property.|
|`verticalPolicy`|`int`|`ScrollBar.AsNeeded`|verticalPolicy property.|
|`horizontalPolicy`|`int`|`ScrollBar.AlwaysOff`|horizontalPolicy property.|
|`verticalScrollBarActive`|`bool`|`{`|verticalScrollBarActive property (readonly).|
|`contentOverflows`|`bool`|`gridView.contentHeight > gridView.height`|contentOverflows property (readonly).|
|`showGradientMasks`|`bool`|`true`|Gradient properties|
|`gradientColor`|`color`|`Color.mSurfaceVariant`|gradientColor property.|
|`gradientHeight`|`int`|`16`|gradientHeight property.|
|`reserveScrollbarSpace`|`bool`|`true`|reserveScrollbarSpace property.|
|`showScrollbarWhenScrollable`|`bool`|`Settings.data.ui.scrollbarAlwaysVisible`|Keep scrollbars visible whenever overflow exists (without forcing visibility when not scrollable)|
|`availableWidth`|`real`|`width - (reserveScrollbarSpace ? handleWidth + Style.marginXS : 0)`|Available width for content (excludes scrollbar space when reserveScrollbarSpace is true) Note: Always reserves space when enabled to avoid binding loops with cellWidth calculations|
|`hasActiveFocus`|`bool`|`gridView.activeFocus`|Expose activeFocus from internal gridView|
|`model`|`alias`|`gridView.model`|Forward GridView properties|
|`delegate`|`alias`|`gridView.delegate`|delegate property.|
|`cellWidth`|`alias`|`gridView.cellWidth`|cellWidth property.|
|`cellHeight`|`alias`|`gridView.cellHeight`|cellHeight property.|
|`leftMargin`|`alias`|`gridView.leftMargin`|leftMargin property.|
|`rightMargin`|`alias`|`gridView.rightMargin`|rightMargin property.|
|`topMargin`|`alias`|`gridView.topMargin`|topMargin property.|
|`bottomMargin`|`alias`|`gridView.bottomMargin`|bottomMargin property.|
|`currentIndex`|`alias`|`gridView.currentIndex`|currentIndex property.|
|`count`|`alias`|`gridView.count`|count property.|
|`contentHeight`|`alias`|`gridView.contentHeight`|contentHeight property.|
|`contentWidth`|`alias`|`gridView.contentWidth`|contentWidth property.|
|`contentY`|`alias`|`gridView.contentY`|contentY property.|
|`contentX`|`alias`|`gridView.contentX`|contentX property.|
|`currentItem`|`alias`|`gridView.currentItem`|currentItem property.|
|`highlightItem`|`alias`|`gridView.highlightItem`|highlightItem property.|
|`highlightFollowsCurrentItem`|`alias`|`gridView.highlightFollowsCurrentItem`|highlightFollowsCurrentItem property.|
|`preferredHighlightBegin`|`alias`|`gridView.preferredHighlightBegin`|preferredHighlightBegin property.|
|`preferredHighlightEnd`|`alias`|`gridView.preferredHighlightEnd`|preferredHighlightEnd property.|
|`highlightRangeMode`|`alias`|`gridView.highlightRangeMode`|highlightRangeMode property.|
|`snapMode`|`alias`|`gridView.snapMode`|snapMode property.|
|`keyNavigationEnabled`|`alias`|`gridView.keyNavigationEnabled`|keyNavigationEnabled property.|
|`keyNavigationWraps`|`alias`|`gridView.keyNavigationWraps`|keyNavigationWraps property.|
|`cacheBuffer`|`alias`|`gridView.cacheBuffer`|cacheBuffer property.|
|`displayMarginBeginning`|`alias`|`gridView.displayMarginBeginning`|displayMarginBeginning property.|
|`displayMarginEnd`|`alias`|`gridView.displayMarginEnd`|displayMarginEnd property.|
|`layoutDirection`|`alias`|`gridView.layoutDirection`|layoutDirection property.|
|`effectiveLayoutDirection`|`alias`|`gridView.effectiveLayoutDirection`|effectiveLayoutDirection property.|
|`flow`|`alias`|`gridView.flow`|flow property.|
|`boundsBehavior`|`alias`|`gridView.boundsBehavior`|boundsBehavior property.|
|`flickableDirection`|`alias`|`gridView.flickableDirection`|flickableDirection property.|
|`interactive`|`alias`|`gridView.interactive`|interactive property.|
|`moving`|`alias`|`gridView.moving`|moving property.|
|`flicking`|`alias`|`gridView.flicking`|flicking property.|
|`dragging`|`alias`|`gridView.dragging`|dragging property.|
|`horizontalVelocity`|`alias`|`gridView.horizontalVelocity`|horizontalVelocity property.|
|`verticalVelocity`|`alias`|`gridView.verticalVelocity`|verticalVelocity property.|
|`reuseItems`|`alias`|`gridView.reuseItems`|reuseItems property.|
|`animateMovement`|`bool`|`false`|Animate items when the model is reordered (e.g. ListModel.move())|
|`wheelScrollMultiplier`|`real`|`2.0`|Scroll speed multiplier for mouse wheel (1.0 = default, higher = faster)|
|`smoothWheelAnimationDuration`|`int`|`Style.animationNormal`|smoothWheelAnimationDuration property.|
|`_wheelTargetY`|`real`|`0`|_wheelTargetY property.|
|`trackedSelectionIndex`|`int`|`-1`|Track selection index for gradient visibility (set externally)|
|`selectionOnFirstVisibleRow`|`bool`|`{`|Check if selection is on first visible row|
|`selectionOnLastVisibleRow`|`bool`|`{`|Check if selection is on last visible row|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`keyPressed`|`(var event)`|Signal for key press events when keyNavigationEnabled is true|

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`clampScrollY`|`(value)`|Method clampScrollY.|
|`applyWheelScroll`|`(delta)`|Method applyWheelScroll.|
|`animateToContentY`|`(targetY)`|Method animateToContentY.|
|`positionViewAtIndex`|`(index, mode)`|Forward GridView methods|
|`positionViewAtBeginning`|`(—)`|Method positionViewAtBeginning.|
|`positionViewAtEnd`|`(—)`|Method positionViewAtEnd.|
|`forceLayout`|`(—)`|Method forceLayout.|
|`forceActiveFocus`|`(—)`|Method forceActiveFocus.|
|`cancelFlick`|`(—)`|Method cancelFlick.|
|`flick`|`(xVelocity, yVelocity)`|Method flick.|
|`incrementCurrentIndex`|`(—)`|Method incrementCurrentIndex.|
|`decrementCurrentIndex`|`(—)`|Method decrementCurrentIndex.|
|`indexAt`|`(x, y)`|Method indexAt.|
|`itemAt`|`(x, y)`|Method itemAt.|
|`itemAtIndex`|`(index)`|Method itemAtIndex.|
|`moveCurrentIndexUp`|`(—)`|Method moveCurrentIndexUp.|
|`moveCurrentIndexDown`|`(—)`|Method moveCurrentIndexDown.|
|`moveCurrentIndexLeft`|`(—)`|Method moveCurrentIndexLeft.|
|`moveCurrentIndexRight`|`(—)`|Method moveCurrentIndexRight.|
|`createGradients`|`(—)`|Dynamically create gradient overlays|

#### Example
```qml
NGridView { model: [] }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NHeader`

Source: `/tmp/noctalia-shell/Widgets/NHeader.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`label`|`string`|`""`|label property.|
|`description`|`string`|`""`|description property.|
|`enableDescriptionRichText`|`bool`|`false`|enableDescriptionRichText property.|

#### Signals
_None._

#### Example
```qml
NHeader { label: I18n.tr("common.settings") }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NIcon`

Source: `/tmp/noctalia-shell/Widgets/NIcon.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`icon`|`string`|`Icons.defaultIcon`|icon property.|
|`pointSize`|`real`|`Style.fontSizeL`|pointSize property.|
|`applyUiScale`|`bool`|`true`|applyUiScale property.|

#### Signals
_None._

#### Example
```qml
NIcon { icon: "settings" }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NIconPicker`

Source: `/tmp/noctalia-shell/Widgets/NIconPicker.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`selectedIcon`|`string`|`""`|selectedIcon property.|
|`initialIcon`|`string`|`""`|initialIcon property.|
|`query`|`string`|`""`|query property.|
|`allIcons`|`var`|`Object.keys(Icons.icons)`|allIcons property.|
|`filteredIcons`|`var`|`{`|filteredIcons property.|
|`columns`|`int`|`6`|columns property (readonly).|
|`cellW`|`int`|`Math.floor(grid.width / columns)`|cellW property (readonly).|
|`cellH`|`int`|`Math.round(cellW * 0.7 + 36)`|cellH property (readonly).|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`iconSelected`|`(string iconName)`|Emitted on iconSelected.|

#### Example
```qml
NIconPicker { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NImageRounded`

Source: `/tmp/noctalia-shell/Widgets/NImageRounded.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`radius`|`real`|`0`|radius property.|
|`imagePath`|`string`|`""`|imagePath property.|
|`fallbackIcon`|`string`|`""`|fallbackIcon property.|
|`fallbackIconSize`|`real`|`Style.fontSizeXXL`|fallbackIconSize property.|
|`borderWidth`|`real`|`0`|borderWidth property.|
|`borderColor`|`color`|`"transparent"`|borderColor property.|
|`imageFillMode`|`int`|`Image.PreserveAspectCrop`|imageFillMode property.|
|`_isAnimated`|`bool`|`imagePath.toLowerCase().endsWith(".gif")`|_isAnimated property (readonly).|
|`imageSource`|`Item`|`imageSourceLoader.item`|imageSource property (readonly).|
|`showFallback`|`bool`|`fallbackIcon !== "" && (imagePath === "" \|\| (imageSource && imageSource.status === Image.Error))`|showFallback property (readonly).|
|`status`|`int`|`imageSource ? imageSource.status : Image.Null`|status property (readonly).|

#### Signals
_None._

#### Example
```qml
NImageRounded { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NInputAction`

Source: `/tmp/noctalia-shell/Widgets/NInputAction.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`label`|`string`|`""`|Public properties|
|`description`|`string`|`""`|description property.|
|`placeholderText`|`string`|`""`|placeholderText property.|
|`text`|`string`|`""`|text property.|
|`actionButtonText`|`string`|`I18n.tr("common.test")`|actionButtonText property.|
|`actionButtonIcon`|`string`|`"media-play"`|actionButtonIcon property.|
|`actionButtonEnabled`|`bool`|`text !== ""`|actionButtonEnabled property.|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`editingFinished`|`(—)`|Signals|
|`actionClicked`|`(—)`|Emitted on actionClicked.|

#### Example
```qml
NInputAction { text: I18n.tr("common.ok") }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NKeybindRecorder`

Source: `/tmp/noctalia-shell/Widgets/NKeybindRecorder.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`label`|`string`|`""`|label property.|
|`description`|`string`|`""`|description property.|
|`currentKeybinds`|`var`|`[]`|currentKeybinds property.|
|`defaultKeybind`|`string`|`""`|defaultKeybind property.|
|`allowEmpty`|`bool`|`false`|allowEmpty property.|
|`labelColor`|`color`|`Color.mOnSurface`|labelColor property.|
|`descriptionColor`|`color`|`Color.mOnSurfaceVariant`|descriptionColor property.|
|`settingsPath`|`string`|`""`|settingsPath property.|
|`maxKeybinds`|`int`|`2`|maxKeybinds property.|
|`requireModifierForNormalKeys`|`bool`|`true`|requireModifierForNormalKeys property.|
|`recordingIndex`|`int`|`-1`|-1 = not recording, >= 0 = re-recording at index, -2 = adding new|
|`hasConflict`|`bool`|`false`|hasConflict property.|
|`_pillHeight`|`real`|`Style.baseWidgetSize * 1.1 * Style.uiScaleRatio`|_pillHeight property (readonly).|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`keybindsChanged`|`(var newKeybinds)`|Emitted on keybindsChanged.|

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`_applyKeybind`|`(keyStr)`|Method _applyKeybind.|

#### Example
```qml
NKeybindRecorder { label: I18n.tr("common.settings") }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NLinearGauge`

Source: `/tmp/noctalia-shell/Widgets/NLinearGauge.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`fillColor`|`color`|`Color.mPrimary`|fillColor property.|

#### Signals
_None._

#### Example
```qml
NLinearGauge { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NLinearSpectrum`

Source: `/tmp/noctalia-shell/Widgets/AudioSpectrum/NLinearSpectrum.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`fillColor`|`color`|`Color.mPrimary`|fillColor property.|
|`strokeColor`|`color`|`Color.mOnSurface`|strokeColor property.|
|`strokeWidth`|`int`|`0`|strokeWidth property.|
|`values`|`var`|`[]`|values property.|
|`vertical`|`bool`|`false`|vertical property.|
|`barPosition`|`string`|`"top"`|"top", "bottom", "left", "right"|
|`mirrored`|`bool`|`true`|mirrored property.|
|`showMinimumSignal`|`bool`|`false`|Minimum signal properties|
|`minimumSignalValue`|`real`|`0.01`|Default to 1% of height|
|`valuesCount`|`int`|`(values && values.length !== undefined) ? values.length : 0`|Pre compute horizontal mirroring|
|`totalBars`|`int`|`mirrored ? valuesCount * 2 : valuesCount`|totalBars property (readonly).|
|`barSlotSize`|`real`|`totalBars > 0 ? (vertical ? height : width) / totalBars : 0`|barSlotSize property (readonly).|
|`highQuality`|`bool`|`(Settings.data.audio.visualizerType === "low") ? false : true`|highQuality property (readonly).|

#### Signals
_None._

#### Example
```qml
NLinearSpectrum { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NListView`

Source: `/tmp/noctalia-shell/Widgets/NListView.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`handleColor`|`color`|`Qt.alpha(Color.mHover, 0.8)`|handleColor property.|
|`handleHoverColor`|`color`|`handleColor`|handleHoverColor property.|
|`handlePressedColor`|`color`|`handleColor`|handlePressedColor property.|
|`trackColor`|`color`|`"transparent"`|trackColor property.|
|`handleWidth`|`real`|`Math.round(6 * Style.uiScaleRatio)`|handleWidth property.|
|`handleRadius`|`real`|`Style.iRadiusM`|handleRadius property.|
|`verticalPolicy`|`int`|`ScrollBar.AsNeeded`|verticalPolicy property.|
|`horizontalPolicy`|`int`|`ScrollBar.AlwaysOff`|horizontalPolicy property.|
|`verticalScrollBarActive`|`bool`|`{`|verticalScrollBarActive property (readonly).|
|`contentOverflows`|`bool`|`listView.contentHeight > listView.height`|contentOverflows property (readonly).|
|`showGradientMasks`|`bool`|`true`|showGradientMasks property.|
|`gradientColor`|`color`|`Color.mSurfaceVariant`|gradientColor property.|
|`gradientHeight`|`int`|`16`|gradientHeight property.|
|`reserveScrollbarSpace`|`bool`|`true`|reserveScrollbarSpace property.|
|`showScrollbarWhenScrollable`|`bool`|`Settings.data.ui.scrollbarAlwaysVisible`|Keep scrollbars visible whenever overflow exists (without forcing visibility when not scrollable)|
|`availableWidth`|`real`|`width - (reserveScrollbarSpace ? handleWidth + Style.marginXS : 0)`|Available width for content (excludes scrollbar space when reserveScrollbarSpace is true)|
|`model`|`alias`|`listView.model`|Forward ListView properties|
|`delegate`|`alias`|`listView.delegate`|delegate property.|
|`spacing`|`alias`|`listView.spacing`|spacing property.|
|`orientation`|`alias`|`listView.orientation`|orientation property.|
|`currentIndex`|`alias`|`listView.currentIndex`|currentIndex property.|
|`count`|`alias`|`listView.count`|count property.|
|`contentHeight`|`alias`|`listView.contentHeight`|contentHeight property.|
|`contentWidth`|`alias`|`listView.contentWidth`|contentWidth property.|
|`contentY`|`alias`|`listView.contentY`|contentY property.|
|`contentX`|`alias`|`listView.contentX`|contentX property.|
|`currentItem`|`alias`|`listView.currentItem`|currentItem property.|
|`highlightItem`|`alias`|`listView.highlightItem`|highlightItem property.|
|`headerItem`|`alias`|`listView.headerItem`|headerItem property.|
|`footerItem`|`alias`|`listView.footerItem`|footerItem property.|
|`section`|`alias`|`listView.section`|section property.|
|`highlightFollowsCurrentItem`|`alias`|`listView.highlightFollowsCurrentItem`|highlightFollowsCurrentItem property.|
|`highlightMoveDuration`|`alias`|`listView.highlightMoveDuration`|highlightMoveDuration property.|
|`highlightMoveVelocity`|`alias`|`listView.highlightMoveVelocity`|highlightMoveVelocity property.|
|`preferredHighlightBegin`|`alias`|`listView.preferredHighlightBegin`|preferredHighlightBegin property.|
|`preferredHighlightEnd`|`alias`|`listView.preferredHighlightEnd`|preferredHighlightEnd property.|
|`highlightRangeMode`|`alias`|`listView.highlightRangeMode`|highlightRangeMode property.|
|`snapMode`|`alias`|`listView.snapMode`|snapMode property.|
|`keyNavigationWraps`|`alias`|`listView.keyNavigationWraps`|keyNavigationWraps property.|
|`cacheBuffer`|`alias`|`listView.cacheBuffer`|cacheBuffer property.|
|`displayMarginBeginning`|`alias`|`listView.displayMarginBeginning`|displayMarginBeginning property.|
|`displayMarginEnd`|`alias`|`listView.displayMarginEnd`|displayMarginEnd property.|
|`layoutDirection`|`alias`|`listView.layoutDirection`|layoutDirection property.|
|`effectiveLayoutDirection`|`alias`|`listView.effectiveLayoutDirection`|effectiveLayoutDirection property.|
|`verticalLayoutDirection`|`alias`|`listView.verticalLayoutDirection`|verticalLayoutDirection property.|
|`boundsBehavior`|`alias`|`listView.boundsBehavior`|boundsBehavior property.|
|`flickableDirection`|`alias`|`listView.flickableDirection`|flickableDirection property.|
|`interactive`|`alias`|`listView.interactive`|interactive property.|
|`moving`|`alias`|`listView.moving`|moving property.|
|`flicking`|`alias`|`listView.flicking`|flicking property.|
|`dragging`|`alias`|`listView.dragging`|dragging property.|
|`horizontalVelocity`|`alias`|`listView.horizontalVelocity`|horizontalVelocity property.|
|`verticalVelocity`|`alias`|`listView.verticalVelocity`|verticalVelocity property.|
|`wheelScrollMultiplier`|`real`|`2.0`|Scroll speed multiplier for mouse wheel (1.0 = default, higher = faster)|
|`smoothWheelAnimationDuration`|`int`|`Style.animationNormal`|smoothWheelAnimationDuration property.|
|`_wheelTargetY`|`real`|`0`|_wheelTargetY property.|

#### Signals
_None._

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`clampScrollY`|`(value)`|Method clampScrollY.|
|`applyWheelScroll`|`(delta)`|Method applyWheelScroll.|
|`animateToContentY`|`(targetY)`|Method animateToContentY.|
|`positionViewAtIndex`|`(index, mode)`|Forward ListView methods|
|`positionViewAtBeginning`|`(—)`|Method positionViewAtBeginning.|
|`positionViewAtEnd`|`(—)`|Method positionViewAtEnd.|
|`forceLayout`|`(—)`|Method forceLayout.|
|`cancelFlick`|`(—)`|Method cancelFlick.|
|`flick`|`(xVelocity, yVelocity)`|Method flick.|
|`incrementCurrentIndex`|`(—)`|Method incrementCurrentIndex.|
|`decrementCurrentIndex`|`(—)`|Method decrementCurrentIndex.|
|`indexAt`|`(x, y)`|Method indexAt.|
|`itemAt`|`(x, y)`|Method itemAt.|
|`itemAtIndex`|`(index)`|Method itemAtIndex.|
|`createGradients`|`(—)`|Dynamically create gradient overlays|

#### Example
```qml
NListView { model: [] }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NMirroredSpectrum`

Source: `/tmp/noctalia-shell/Widgets/AudioSpectrum/NMirroredSpectrum.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`fillColor`|`color`|`Color.mPrimary`|fillColor property.|
|`strokeColor`|`color`|`Color.mOnSurface`|strokeColor property.|
|`strokeWidth`|`int`|`0`|strokeWidth property.|
|`values`|`var`|`[]`|values property.|
|`vertical`|`bool`|`false`|vertical property.|
|`mirrored`|`bool`|`true`|mirrored property.|
|`showMinimumSignal`|`bool`|`false`|Minimum signal properties|
|`minimumSignalValue`|`real`|`0.01`|Default to 1% of height|
|`valuesCount`|`int`|`(values && values.length !== undefined) ? values.length : 0`|Pre-compute mirroring|
|`totalBars`|`int`|`mirrored ? valuesCount * 2 : valuesCount`|totalBars property (readonly).|
|`barSlotSize`|`real`|`totalBars > 0 ? (vertical ? height : width) / totalBars : 0`|barSlotSize property (readonly).|
|`highQuality`|`bool`|`(Settings.data.audio.visualizerType === "low") ? false : true`|highQuality property (readonly).|
|`centerY`|`real`|`height / 2`|centerY property (readonly).|
|`centerX`|`real`|`width / 2`|centerX property (readonly).|

#### Signals
_None._

#### Example
```qml
NMirroredSpectrum { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NPluginSettingsPopup`

Source: `/tmp/noctalia-shell/Widgets/NPluginSettingsPopup.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`screen`|`var`|`null`|screen property.|
|`maxHeight`|`real`|`(screen ? screen.height : (parent ? parent.height : 800)) * 0.8`|maxHeight property (readonly).|
|`_minWidth`|`real`|`600 * Style.uiScaleRatio`|_minWidth property.|
|`currentPlugin`|`var`|`null`|currentPlugin property.|
|`currentPluginApi`|`var`|`null`|currentPluginApi property.|
|`showToastOnSave`|`bool`|`false`|showToastOnSave property.|

#### Signals
_None._

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`openPluginSettings`|`(pluginManifest, settingsEntryPoint)`|Method openPluginSettings.|

#### Example
```qml
NPluginSettingsPopup { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NRadioButton`

Source: `/tmp/noctalia-shell/Widgets/NRadioButton.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`pointSize`|`real`|`Style.fontSizeM`|pointSize property.|

#### Signals
_None._

#### Example
```qml
NRadioButton { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NReorderCheckboxes`

Source: `/tmp/noctalia-shell/Widgets/NReorderCheckboxes.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`model`|`var`|`[]`|Public API|
|`disabledIds`|`var`|`[]`|disabledIds property.|
|`activeColor`|`color`|`Color.mPrimary`|activeColor property.|
|`activeOnColor`|`color`|`Color.mOnPrimary`|activeOnColor property.|
|`dragHandleColor`|`color`|`Color.mOutline`|dragHandleColor property.|
|`baseSize`|`int`|`Style.baseWidgetSize * 0.7`|baseSize property.|
|`spacing`|`int`|`Style.marginM`|spacing property.|
|`itemHeight`|`real`|`root.baseSize`|itemHeight property (readonly).|
|`contentHeight`|`real`|`root.model.length > 0 ? root.model.length * itemHeight + (root.model.length - 1) * root.spacing : 0`|contentHeight property (readonly).|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`itemToggled`|`(int index, bool enabled)`|Emitted on itemToggled.|
|`itemsReordered`|`(int fromIndex, int toIndex)`|Emitted on itemsReordered.|
|`dragPotentialStarted`|`(—)`|Emitted on dragPotentialStarted.|
|`dragPotentialEnded`|`(—)`|Emitted on dragPotentialEnded.|

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`toggleItem`|`(index)`|Method toggleItem.|
|`moveItem`|`(fromIndex, toIndex)`|Method moveItem.|

#### Example
```qml
NReorderCheckboxes { model: [] }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NScrollText`

Source: `/tmp/noctalia-shell/Widgets/NScrollText.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`text`|`string`|`—`|text property (required).|
|`maxWidth`|`real`|`Infinity`|maxWidth property.|
|`scrollMode`|`int`|`NScrollText.ScrollMode.Never`|scrollMode property.|
|`alwaysMaxWidth`|`bool`|`false`|alwaysMaxWidth property.|
|`forcedHover`|`bool`|`false`|forcedHover property.|
|`cursorShape`|`int`|`Qt.ArrowCursor`|cursorShape property.|
|`waitBeforeScrolling`|`real`|`1000`|waitBeforeScrolling property.|
|`scrollCycleDuration`|`real`|`Math.max(4000, root.text.length * 120)`|scrollCycleDuration property.|
|`resettingDuration`|`real`|`300`|resettingDuration property.|
|`fadeExtent`|`real`|`0.1`|Fade controls (fadeExtent: 0.0–0.5, fraction of width that fades)|
|`fadeCornerRadius`|`real`|`0`|fadeCornerRadius property.|
|`fadeRoundLeftCorners`|`bool`|`true`|fadeRoundLeftCorners property.|
|`contentWidth`|`real`|`{`|contentWidth property (readonly).|
|`measuredWidth`|`real`|`scrollContainer.width`|measuredWidth property (readonly).|
|`state`|`int`|`NScrollText.ScrollState.None`|state property.|

#### Signals
_None._

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`resetState`|`(—)`|Method resetState.|
|`ensureReset`|`(—)`|Method ensureReset.|
|`updateState`|`(—)`|Method updateState.|

#### Example
```qml
NScrollText { text: I18n.tr("common.ok") }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NSearchableComboBox`

Source: `/tmp/noctalia-shell/Widgets/NSearchableComboBox.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`minimumWidth`|`real`|`280`|minimumWidth property.|
|`popupHeight`|`real`|`180`|popupHeight property.|
|`selectOnNavigation`|`bool`|`true`|selectOnNavigation property.|
|`label`|`string`|`""`|label property.|
|`description`|`string`|`""`|description property.|
|`model`|`ListModel`|`{}`|model property.|
|`currentKey`|`string`|`""`|currentKey property.|
|`placeholder`|`string`|`""`|placeholder property.|
|`searchPlaceholder`|`string`|`I18n.tr("placeholders.search")`|searchPlaceholder property.|
|`delegate`|`Component`|`null`|delegate property.|
|`defaultValue`|`var`|`undefined`|defaultValue property.|
|`settingsPath`|`string`|`""`|settingsPath property.|
|`preferredHeight`|`real`|`Math.round(Style.baseWidgetSize * 1.1)`|preferredHeight property (readonly).|
|`isValueChanged`|`bool`|`(defaultValue !== undefined) && (currentKey !== defaultValue)`|isValueChanged property (readonly).|
|`indicatorTooltip`|`string`|`{`|indicatorTooltip property (readonly).|
|`filteredModel`|`ListModel`|`ListModel {}`|Filtered model for search results|
|`searchText`|`string`|`""`|searchText property.|
|`activeModel`|`var`|`isFiltered ? filteredModel : root.model`|The active model used for the popup list (source model or filtered results)|
|`isFiltered`|`bool`|`false`|Whether we're using filtered results or the source model directly|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`selected`|`(string key)`|Emitted on selected.|

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`findIndexByKey`|`(key)`|Method findIndexByKey.|
|`findIndexInActiveModel`|`(key)`|Method findIndexInActiveModel.|
|`filterModel`|`(—)`|Method filterModel.|

#### Example
```qml
NSearchableComboBox { label: I18n.tr("common.settings") }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NSectionEditor`

Source: `/tmp/noctalia-shell/Widgets/NSectionEditor.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`sectionName`|`string`|`""`|sectionName property.|
|`sectionSubtitle`|`string`|`""`|sectionSubtitle property.|
|`sectionId`|`string`|`""`|sectionId property.|
|`widgetModel`|`var`|`[]`|widgetModel property.|
|`availableWidgets`|`var`|`[]`|availableWidgets property.|
|`availableSections`|`var`|`["left", "center", "right"]`|availableSections property.|
|`sectionLabels`|`var`|`({})`|Map of sectionId -> display label|
|`sectionIcons`|`var`|`({})`|Map of sectionId -> icon name|
|`barIsVertical`|`bool`|`false`|When true, map left/right to top/bottom in labels|
|`maxWidgets`|`int`|`-1`|-1 means unlimited|
|`draggable`|`bool`|`true`|Enable/disable drag reordering|
|`crossSectionDraggable`|`bool`|`false`|crossSectionDraggable property.|
|`dropTargetArea`|`alias`|`gridContainer`|dropTargetArea property.|
|`pluginSettingsEntryPoints`|`var`|`["settings"]`|pluginSettingsEntryPoints property.|
|`widgetRegistry`|`var`|`null`|widgetRegistry property.|
|`settingsDialogComponent`|`string`|`"invalid-settings-dialog"`|settingsDialogComponent property.|
|`screen`|`var`|`null`|Screen reference for per-screen widget settings|
|`_activeDialog`|`var`|`null`|_activeDialog property.|
|`crossDropHoverActive`|`bool`|`false`|crossDropHoverActive property.|
|`showCrossSectionDropHint`|`bool`|`crossDropHoverActive`|showCrossSectionDropHint property (readonly).|
|`gridColumns`|`int`|`3`|gridColumns property (readonly).|
|`miniButtonSize`|`real`|`Style.baseWidgetSize * 0.65`|miniButtonSize property (readonly).|
|`isAtMaxCapacity`|`bool`|`maxWidgets >= 0 && widgetModel.length >= maxWidgets`|isAtMaxCapacity property (readonly).|
|`widgetItemHeight`|`real`|`Style.baseWidgetSize * 1.3 * Style.uiScaleRatio`|widgetItemHeight property (readonly).|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`addWidget`|`(string widgetId, string section)`|Emitted on addWidget.|
|`removeWidget`|`(string section, int index)`|Emitted on removeWidget.|
|`reorderWidget`|`(string section, int fromIndex, int toIndex)`|Emitted on reorderWidget.|
|`updateWidgetSettings`|`(string section, int index, var settings)`|Emitted on updateWidgetSettings.|
|`moveWidget`|`(string fromSection, int index, string toSection)`|Emitted on moveWidget.|
|`dragPotentialStarted`|`(—)`|Emitted on dragPotentialStarted.|
|`dragPotentialEnded`|`(—)`|Emitted on dragPotentialEnded.|
|`openPluginSettingsRequested`|`(var pluginManifest, string settingsEntryPoint)`|Emitted on openPluginSettingsRequested.|

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`getSectionLabel`|`(sectionId)`|Get display label for a section|
|`getSectionIcon`|`(sectionId)`|Get icon for a section|
|`clearCrossSectionHover`|`(—)`|Method clearCrossSectionHover.|
|`updateCrossSectionHover`|`(globalX, globalY)`|Method updateCrossSectionHover.|
|`isPointInsideSelf`|`(globalX, globalY)`|Method isPointInsideSelf.|
|`calculateWidgetWidth`|`(gridWidth)`|Calculate width to fit gridColumns widgets with spacing|
|`findSectionAtGlobalPosition`|`(globalX, globalY)`|Method findSectionAtGlobalPosition.|
|`getWidgetColor`|`(widget)`|Generate widget color from name checksum|
|`widgetHasSettings`|`(widgetId)`|Check if widget has settings (either core widget with metadata or plugin with settings entry point)|
|`openWidgetSettings`|`(index, widgetData)`|Open settings for a widget|

#### Example
```qml
NSectionEditor { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NSettingsIndicator`

Source: `/tmp/noctalia-shell/Widgets/NSettingsIndicator.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`show`|`bool`|`false`|show property.|
|`tooltipText`|`var`|`—`|tooltipText property.|

#### Signals
_None._

#### Example
```qml
NSettingsIndicator { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NSlideSwapView`

Source: `/tmp/noctalia-shell/Widgets/NSlideSwapView.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`sourceComponent`|`Component`|`—`|sourceComponent property.|
|`animationsEnabled`|`bool`|`true`|animationsEnabled property.|
|`duration`|`int`|`Style.animationNormal`|duration property.|
|`transitionGap`|`real`|`Style.marginXL`|transitionGap property.|
|`incomingStartOpacity`|`real`|`0.0`|incomingStartOpacity property.|
|`outgoingTargetOpacity`|`real`|`0.25`|outgoingTargetOpacity property.|
|`item`|`var`|`contentLoader.item`|item property (readonly).|
|`running`|`bool`|`_running`|running property (readonly).|
|`_running`|`bool`|`false`|_running property.|
|`_pendingApplyChange`|`var`|`null`|_pendingApplyChange property.|
|`_contentOffset`|`real`|`0`|_contentOffset property.|
|`_contentOpacity`|`real`|`1`|_contentOpacity property.|
|`_snapshotOffset`|`real`|`0`|_snapshotOffset property.|
|`_snapshotOpacity`|`real`|`0`|_snapshotOpacity property.|
|`_snapshotTargetOffset`|`real`|`0`|_snapshotTargetOffset property.|

#### Signals
_None._

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`resetVisuals`|`(—)`|Method resetVisuals.|
|`swap`|`(direction, applyChange)`|Method swap.|

#### Example
```qml
NSlideSwapView { sourceComponent: myComponent }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NTabBar`

Source: `/tmp/noctalia-shell/Widgets/NTabBar.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`currentIndex`|`int`|`0`|Public properties|
|`spacing`|`real`|`Style.marginXS`|spacing property.|
|`margins`|`real`|`0`|margins property.|
|`tabHeight`|`real`|`Style.baseWidgetSize`|tabHeight property.|
|`distributeEvenly`|`bool`|`false`|distributeEvenly property.|

#### Signals
_None._

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`_updateFirstLast`|`(—)`|Method _updateFirstLast.|
|`_applyDistribution`|`(—)`|Method _applyDistribution.|

#### Example
```qml
NTabBar { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NTabButton`

Source: `/tmp/noctalia-shell/Widgets/NTabButton.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`text`|`string`|`""`|Public properties|
|`icon`|`string`|`""`|icon property.|
|`tooltipText`|`var`|`—`|tooltipText property.|
|`checked`|`bool`|`false`|checked property.|
|`tabIndex`|`int`|`0`|tabIndex property.|
|`pointSize`|`real`|`Style.fontSizeM`|pointSize property.|
|`isFirst`|`bool`|`false`|isFirst property.|
|`isLast`|`bool`|`false`|isLast property.|
|`isHovered`|`bool`|`false`|Internal state|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`clicked`|`(—)`|Emitted on clicked.|

#### Example
```qml
NTabButton { text: I18n.tr("common.ok") }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NTabView`

Source: `/tmp/noctalia-shell/Widgets/NTabView.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`currentIndex`|`int`|`0`|currentIndex property.|
|`previousIndex`|`int`|`0`|Private|
|`initialized`|`bool`|`false`|initialized property.|
|`animating`|`bool`|`false`|animating property.|
|`animatingHeight`|`real`|`0`|animatingHeight property.|
|`transitionGap`|`real`|`Style.marginXL`|transitionGap property.|
|`transitionTime`|`real`|`Style.animationNormal`|transitionTime property.|
|`contentItems`|`list<Item>`|`[]`|contentItems property.|

#### Signals
_None._

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`setIndexWithoutAnimation`|`(idx)`|Set the visible tab to idx without triggering a slide animation. Call this BEFORE the bound currentIndex changes so that onCurrentIndexChanged sees previousIndex === currentIndex and skips.|
|`_initializeItems`|`(—)`|Method _initializeItems.|
|`_animateTransition`|`(fromIdx, toIdx)`|Method _animateTransition.|

#### Example
```qml
NTabView { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NTagFilter`

Source: `/tmp/noctalia-shell/Widgets/NTagFilter.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`tags`|`var`|`[]`|Public API|
|`selectedTag`|`string`|`""`|selectedTag property.|
|`label`|`alias`|`root.label`|label property.|
|`description`|`alias`|`root.description`|description property.|
|`expanded`|`alias`|`root.expanded`|expanded property.|
|`formatTag`|`var`|`function (tag) {`|Formatting function for tag display (optional override)|

#### Signals
_None._

#### Example
```qml
NTagFilter { label: I18n.tr("common.settings") }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NText`

Source: `/tmp/noctalia-shell/Widgets/NText.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`richTextEnabled`|`bool`|`false`|richTextEnabled property.|
|`markdownTextEnabled`|`bool`|`false`|markdownTextEnabled property.|
|`family`|`string`|`Settings.data.ui.fontDefault`|family property.|
|`pointSize`|`real`|`Style.fontSizeM`|pointSize property.|
|`applyUiScale`|`bool`|`true`|applyUiScale property.|
|`fontScale`|`real`|`{`|fontScale property.|
|`features`|`var`|`({})`|features property.|

#### Signals
_None._

#### Example
```qml
NText { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NTextInputButton`

Source: `/tmp/noctalia-shell/Widgets/NTextInputButton.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`text`|`alias`|`input.text`|text property.|
|`placeholderText`|`alias`|`input.placeholderText`|placeholderText property.|
|`label`|`string`|`""`|label property.|
|`description`|`string`|`""`|description property.|
|`inputIconName`|`string`|`""`|inputIconName property.|
|`buttonIcon`|`alias`|`button.icon`|buttonIcon property.|
|`buttonTooltip`|`alias`|`button.tooltipText`|buttonTooltip property.|
|`buttonEnabled`|`alias`|`button.enabled`|buttonEnabled property.|
|`maximumWidth`|`real`|`0`|maximumWidth property.|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`buttonClicked`|`(—)`|Emitted on buttonClicked.|
|`inputTextChanged`|`(string text)`|Emitted on inputTextChanged.|
|`inputEditingFinished`|`(—)`|Emitted on inputEditingFinished.|

#### Example
```qml
NTextInputButton { text: I18n.tr("common.ok") }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NValueSlider`

Source: `/tmp/noctalia-shell/Widgets/NValueSlider.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`from`|`real`|`0`|from property.|
|`to`|`real`|`1`|to property.|
|`value`|`real`|`0`|value property.|
|`stepSize`|`real`|`0.01`|stepSize property.|
|`cutoutColor`|`var`|`Color.mSurface`|cutoutColor property.|
|`snapAlways`|`bool`|`true`|snapAlways property.|
|`heightRatio`|`real`|`0.7`|heightRatio property.|
|`text`|`string`|`""`|text property.|
|`textSize`|`real`|`Style.fontSizeM`|textSize property.|
|`customHeight`|`real`|`-1`|customHeight property.|
|`customHeightRatio`|`real`|`-1`|customHeightRatio property.|
|`label`|`string`|`""`|label property.|
|`description`|`string`|`""`|description property.|
|`defaultValue`|`var`|`undefined`|defaultValue property.|
|`showReset`|`bool`|`false`|showReset property.|
|`sliderActive`|`bool`|`slider.activeFocus \|\| slider.pressed`|sliderActive property (readonly).|
|`isValueChanged`|`bool`|`defaultValue !== undefined && (value !== defaultValue)`|isValueChanged property (readonly).|
|`indicatorTooltip`|`string`|`{`|indicatorTooltip property (readonly).|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`moved`|`(real value)`|Signals|
|`pressedChanged`|`(bool pressed, real value)`|Emitted on pressedChanged.|

#### Example
```qml
NValueSlider { text: I18n.tr("common.ok") }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

### `NWaveSpectrum`

Source: `/tmp/noctalia-shell/Widgets/AudioSpectrum/NWaveSpectrum.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`fillColor`|`color`|`Color.mPrimary`|fillColor property.|
|`strokeColor`|`color`|`Color.mOnSurface`|strokeColor property.|
|`strokeWidth`|`int`|`0`|strokeWidth property.|
|`values`|`var`|`[]`|values property.|
|`vertical`|`bool`|`false`|vertical property.|
|`mirrored`|`bool`|`true`|mirrored property.|
|`showMinimumSignal`|`bool`|`false`|Minimum signal properties|
|`minimumSignalValue`|`real`|`0.01`|Default to 1% of height|
|`valuesCount`|`int`|`(values && values.length !== undefined) ? values.length : 0`|valuesCount property (readonly).|
|`hasData`|`bool`|`valuesCount >= 2`|hasData property (readonly).|

#### Signals
_None._

#### Example
```qml
NWaveSpectrum { }
```

> **Common Mistakes**
> - Confirm required properties are set before instantiation.
> - Use `I18n.tr(...)` for visible strings and `Logger` instead of `console.log` in production widgets.

## qs.Commons

> Existing Commons reference retained and merged below.

This document covers the singleton modules under `qs.Commons` used throughout Noctalia Shell.

## Import Pattern

```qml
import qs.Commons
```

---

## `Color.qml`

Material-like color singleton with animated updates from `colors.json`.

### Exported properties

| Property | Type | Default | Notes |
|---|---|---:|---|
| `reloadColors` | `bool` | `false` | Internal flag used during file reloads. |
| `skipTransition` | `bool` | `true` (initial) | Suppresses color transition animation until first colors load completes. |
| `isTransitioning` | `bool` | `false` | True while a color transition animation is in progress. |
| `mPrimary` | `color` | `#fff59b` | Primary accent. |
| `mOnPrimary` | `color` | `#0e0e43` | Foreground for primary surfaces. |
| `mSecondary` | `color` | `#a9aefe` | Secondary accent. |
| `mOnSecondary` | `color` | `#0e0e43` | Foreground for secondary surfaces. |
| `mTertiary` | `color` | `#9BFECE` | Tertiary accent. |
| `mOnTertiary` | `color` | `#0e0e43` | Foreground for tertiary surfaces. |
| `mError` | `color` | `#FD4663` | Error accent. |
| `mOnError` | `color` | `#0e0e43` | Foreground for error surfaces. |
| `mSurface` | `color` | `#070722` | Main surface background. |
| `mOnSurface` | `color` | `#f3edf7` | Main surface foreground. |
| `mSurfaceVariant` | `color` | `#11112d` | Secondary surface background. |
| `mOnSurfaceVariant` | `color` | `#7c80b4` | Secondary surface foreground. |
| `mOutline` | `color` | `#21215F` | Outline/border color. |
| `mShadow` | `color` | `#070722` | Shadow base color. |
| `mHover` | `color` | `#9BFECE` | Hover highlight color. |
| `mOnHover` | `color` | `#0e0e43` | Foreground for hover color. |
| `colorKeyModel` | `var[]` | `none/primary/secondary/tertiary/error` | UI model with translated names (`I18n.tr`). |

### Exported functions

| Function | Signature | Behavior |
|---|---|---|
| `startTransition` | `()` | Marks transition active and restarts transition timer. |
| `resolveColorKey` | `(key)` | Maps `primary/secondary/tertiary/error`; fallback `mOnSurface`. |
| `resolveOnColorKey` | `(key)` | Maps to `mOn*`; fallback `mSurface`. |
| `resolveColorKeyOptional` | `(key)` | Same as `resolveColorKey`, fallback `"transparent"`. |
| `adaptiveOpacity` | `(baseOpacity)` | Light mode uses `pow(baseOpacity, 1.5)`, dark mode uses raw opacity. |
| `smartAlpha` | `(baseColor, minAlpha=0.4)` | Applies translucent-widget alpha policy and preserves minimum opacity. |

### Example

```qml
Rectangle {
  color: Color.smartAlpha(Color.mSurface)
  border.color: Color.resolveColorKey("primary")
}
```

---

## `Style.qml`

Sizing, spacing, animation, and bar geometry singleton.

### Core constants (exported)

| Group | Keys |
|---|---|
| Font size | `fontSizeXXS`, `fontSizeXS`, `fontSizeS`, `fontSizeM`, `fontSizeL`, `fontSizeXL`, `fontSizeXXL`, `fontSizeXXXL` |
| Font weight | `fontWeightRegular`, `fontWeightMedium`, `fontWeightSemiBold`, `fontWeightBold` |
| Container radii | `radiusXXXS`, `radiusXXS`, `radiusXS`, `radiusS`, `radiusM`, `radiusL` |
| Input radii | `iRadiusXXXS`, `iRadiusXXS`, `iRadiusXS`, `iRadiusS`, `iRadiusM`, `iRadiusL` |
| Screen radius | `screenRadius` |
| Border widths | `borderS`, `borderM`, `borderL` |
| Margins | `marginXXXS`, `marginXXS`, `marginXS`, `marginS`, `marginM`, `marginL`, `marginXL` |
| Double margins | `margin2XXXS`, `margin2XXS`, `margin2XS`, `margin2S`, `margin2M`, `margin2L`, `margin2XL` |
| Opacity | `opacityNone`, `opacityLight`, `opacityMedium`, `opacityHeavy`, `opacityAlmost`, `opacityFull` |
| Shadow | `shadowOpacity`, `shadowBlur`, `shadowBlurMax`, `shadowHorizontalOffset`, `shadowVerticalOffset` |
| Animation | `animationFaster`, `animationFast`, `animationNormal`, `animationSlow`, `animationSlowest` |
| Delays | `tooltipDelay`, `tooltipDelayLong`, `pillDelay` |
| Widget metrics | `baseWidgetSize`, `sliderWidth`, `uiScaleRatio` |
| Bar/capsule | `barHeight`, `capsuleHeight`, `barFontSize`, `capsuleColor`, `capsuleBorderColor`, `capsuleBorderWidth`, `boxBorderColor` |

### Exported functions

| Function | Signature | Behavior |
|---|---|---|
| `pixelAlignCenter` | `(containerSize, contentSize)` | Integer center alignment to avoid subpixel rendering. |
| `toOdd` | `(n)` | Rounds down to nearest odd integer. |
| `toEven` | `(n)` | Rounds down to nearest even integer. |
| `getBarHeightForDensity` | `(density, isVertical)` | Density-aware odd bar height. |
| `getCapsuleHeightForDensity` | `(density, barHeight)` | Density-aware odd capsule height. |
| `getBarFontSizeForDensity` | `(barHeight, capsuleHeight, isVertical)` | Computes density/orientation-aware font size. |
| `getBarHeightForScreen` | `(screenName)` | Uses per-screen Settings override. |
| `getCapsuleHeightForScreen` | `(screenName)` | Uses per-screen Settings override. |
| `getBarFontSizeForScreen` | `(screenName)` | Uses per-screen Settings override. |

### Example

```qml
Text {
  font.pixelSize: Style.getBarFontSizeForScreen(screen.name)
  font.weight: Style.fontWeightMedium
}
```

---

## `Settings.qml`

Persistent settings service backed by JSON (`settings.json`) through a `JsonAdapter`.

### Exported singleton properties

| Property | Type | Notes |
|---|---|---|
| `isLoaded` | `bool` | True after initial settings load/migration. |
| `reloadSettings` | `bool` | Internal file-change guard. |
| `directoriesCreated` | `bool` | Becomes true once config/cache directories are created. |
| `shouldOpenSetupWizard` | `bool` | Set on fresh install/no settings file. |
| `isFreshInstall` | `bool` | True when settings file is first created. |
| `data` | `alias` | Main settings tree alias to `adapter` (`Settings.data.<section>.<key>`). |
| `settingsVersion` | `int` | Current schema version (`59`). |
| `isDebug` | `bool` | Controlled by `NOCTALIA_DEBUG=1`. |
| `shellName` | `string` | `"noctalia"`. |
| `configDir` | `string` | Config base dir (env-overridable). |
| `cacheDir` | `string` | Cache base dir (env-overridable). |
| `settingsFile` | `string` | Settings file path (env-overridable). |
| `defaultAvatar` | `string` | `${HOME}/.face`. |
| `defaultVideosDirectory` | `string` | `${HOME}/Videos`. |
| `defaultWallpapersDirectory` | `string` | `${HOME}/Pictures/Wallpapers`. |

### Exported signals

| Signal |
|---|
| `settingsLoaded()` |
| `settingsSaved()` |
| `settingsReloaded()` |

### Exported functions

| Function | Signature | Behavior |
|---|---|---|
| `ensureTrailingSlash` | `(path)` | Ensures `/` suffix. |
| `preprocessPath` | `(path)` | Expands `~` to `$HOME`. |
| `getDefaultValue` | `(path)` | Looks up default from `Assets/settings-default.json`. |
| `isValueChanged` | `(path, currentValue)` | Deep compare vs default. |
| `formatDefaultValueForTooltip` | `(path)` | Human-readable default value display. |
| `_findScreenOverride` | `(screenName)` | Internal helper for `bar.screenOverrides`. |
| `_findScreenOverrideIndex` | `(screenName)` | Internal helper returning index or `-1`. |
| `isScreenOverrideEnabled` | `(screenName)` | Override enabled unless explicitly `false`. |
| `getBarPositionForScreen` | `(screenName)` | Effective position with inheritance. |
| `getBarWidgetsForScreen` | `(screenName)` | Effective widgets with inheritance. |
| `getBarDensityForScreen` | `(screenName)` | Effective density with inheritance. |
| `getBarDisplayModeForScreen` | `(screenName)` | Effective display mode with inheritance. |
| `hasScreenOverride` | `(screenName, property)` | Tests override presence. |
| `getScreenOverrideEntry` | `(screenName)` | Returns actual override entry object. |
| `setScreenOverride` | `(screenName, property, value)` | Upserts override entry/field. |
| `clearScreenOverride` | `(screenName, property)` | Clears one property or full screen override. |
| `saveImmediate` | `()` | Writes settings to disk immediately and emits `settingsSaved`. |
| `generateDefaultSettings` | `()` | Debug utility to regenerate `Assets/settings-default.json`. |
| `generateWidgetDefaultSettings` | `()` | Debug utility to regenerate `Assets/settings-widgets-default.json`. |
| `runVersionedMigrations` | `(rawJson)` | Applies migration components from `MigrationRegistry`. |
| `upgradeSettings` | `()` | Cleans/remaps widget config after plugin registries load. |
| `upgradeWidget` | `(widget)` | Removes deprecated widget keys, injects new defaults. |

### `Settings.data` structure (top-level sections)

| Section | Direct keys |
|---|---|
| `bar` | `autoHideDelay`, `autoShowDelay`, `backgroundOpacity`, `barType`, `capsuleColorKey`, `capsuleOpacity`, `contentPadding`, `density`, `displayMode`, `enableExclusionZoneInset`, `fontScale`, `frameRadius`, `frameThickness`, `hideOnOverview`, `marginHorizontal`, `marginVertical`, `middleClickAction`, `middleClickCommand`, `middleClickFollowMouse`, `monitors`, `mouseWheelAction`, `mouseWheelWrap`, `outerCorners`, `position`, `reverseScroll`, `rightClickAction`, `rightClickCommand`, `rightClickFollowMouse`, `screenOverrides`, `showCapsule`, `showOnWorkspaceSwitch`, `showOutline`, `useSeparateOpacity`, `widgetSpacing`, `widgets` |
| `general` | `allowPanelsOnScreenWithoutBar`, `allowPasswordWithFprintd`, `animationDisabled`, `animationSpeed`, `autoStartAuth`, `avatarImage`, `boxRadiusRatio`, `clockFormat`, `clockStyle`, `compactLockScreen`, `dimmerOpacity`, `enableBlurBehind`, `enableLockScreenCountdown`, `enableLockScreenMediaControls`, `enableShadows`, `forceBlackScreenCorners`, `iRadiusRatio`, `keybinds`, `language`, `lockOnSuspend`, `lockScreenAnimations`, `lockScreenBlur`, `lockScreenCountdownDuration`, `lockScreenMonitors`, `lockScreenTint`, `passwordChars`, `radiusRatio`, `reverseScroll`, `scaleRatio`, `screenRadiusRatio`, `shadowDirection`, `shadowOffsetX`, `shadowOffsetY`, `showChangelogOnStartup`, `showHibernateOnLockScreen`, `showScreenCorners`, `showSessionButtonsOnLockScreen`, `smoothScrollEnabled`, `telemetryEnabled` |
| `ui` | `boxBorderEnabled`, `fontDefault`, `fontDefaultScale`, `fontFixed`, `fontFixedScale`, `panelBackgroundOpacity`, `panelsAttachedToBar`, `scrollbarAlwaysVisible`, `settingsPanelMode`, `settingsPanelSideBarCardStyle`, `tooltipsEnabled`, `translucentWidgets` |
| `location` | `analogClockInCalendar`, `autoLocate`, `firstDayOfWeek`, `hideWeatherCityName`, `hideWeatherTimezone`, `name`, `showCalendarEvents`, `showCalendarWeather`, `showWeekNumberInCalendar`, `use12hourFormat`, `useFahrenheit`, `weatherEnabled`, `weatherShowEffects`, `weatherTaliaMascotAlways` |
| `calendar` | `cards` |
| `wallpaper` | `automationEnabled`, `directory`, `enableMultiMonitorDirectories`, `enabled`, `favorites`, `fillColor`, `fillMode`, `hideWallpaperFilenames`, `linkLightAndDarkWallpapers`, `monitorDirectories`, `overviewBlur`, `overviewEnabled`, `overviewTint`, `panelPosition`, `randomIntervalSec`, `setWallpaperOnAllMonitors`, `showHiddenFiles`, `skipStartupTransition`, `solidColor`, `sortOrder`, `transitionDuration`, `transitionEdgeSmoothness`, `transitionType`, `useOriginalImages`, `useSolidColor`, `useWallhaven`, `viewMode`, `wallhavenApiKey`, `wallhavenCategories`, `wallhavenOrder`, `wallhavenPurity`, `wallhavenQuery`, `wallhavenRatios`, `wallhavenResolutionHeight`, `wallhavenResolutionMode`, `wallhavenResolutionWidth`, `wallhavenSorting`, `wallpaperChangeMode` |
| `appLauncher` | `autoPasteClipboard`, `clipboardWatchImageCommand`, `clipboardWatchTextCommand`, `clipboardWrapText`, `customLaunchPrefix`, `customLaunchPrefixEnabled`, `density`, `enableClipPreview`, `enableClipboardChips`, `enableClipboardHistory`, `enableClipboardSmartIcons`, `enableSessionSearch`, `enableSettingsSearch`, `enableWindowsSearch`, `iconMode`, `ignoreMouseInput`, `overviewLayer`, `pinnedApps`, `position`, `screenshotAnnotationTool`, `showCategories`, `showIconBackground`, `sortByMostUsed`, `terminalCommand`, `viewMode` |
| `controlCenter` | `cards`, `diskPath`, `position`, `shortcuts` |
| `audio` | `mprisBlacklist`, `preferredPlayer`, `spectrumFrameRate`, `spectrumMirrored`, `visualizerType`, `volumeFeedback`, `volumeFeedbackSoundFile`, `volumeOverdrive`, `volumeStep` |
| `brightness` | `backlightDeviceMappings`, `brightnessStep`, `enableDdcSupport`, `enforceMinimum` |
| `network` | `bluetoothAutoConnect`, `bluetoothDetailsViewMode`, `bluetoothHideUnnamedDevices`, `bluetoothRssiPollIntervalMs`, `bluetoothRssiPollingEnabled`, `disableDiscoverability`, `networkPanelView`, `wifiDetailsViewMode` |
| `colorSchemes` | `darkMode`, `generationMethod`, `manualSunrise`, `manualSunset`, `monitorForColors`, `predefinedScheme`, `schedulingMode`, `syncGsettings`, `useWallpaperColors` |
| `notifications` | `backgroundOpacity`, `clearDismissed`, `criticalUrgencyDuration`, `density`, `enableBatteryToast`, `enableKeyboardLayoutToast`, `enableMarkdown`, `enableMediaToast`, `enabled`, `location`, `lowUrgencyDuration`, `monitors`, `normalUrgencyDuration`, `overlayLayer`, `respectExpireTimeout`, `saveToHistory`, `sounds` |
| `dock` | `animationSpeed`, `backgroundOpacity`, `colorizeIcons`, `deadOpacity`, `displayMode`, `dockType`, `enabled`, `floatingRatio`, `groupApps`, `groupClickAction`, `groupContextMenuMode`, `groupIndicatorStyle`, `inactiveIndicators`, `indicatorColor`, `indicatorOpacity`, `indicatorThickness`, `launcherIcon`, `launcherIconColor`, `launcherPosition`, `launcherUseDistroLogo`, `monitors`, `onlySameOutput`, `pinnedApps`, `pinnedStatic`, `position`, `showDockIndicator`, `showLauncherIcon`, `sitOnFrame`, `size` |
| `sessionMenu` | `countdownDuration`, `enableCountdown`, `largeButtonsLayout`, `largeButtonsStyle`, `position`, `powerOptions`, `showHeader`, `showKeybinds` |
| `systemMonitor` | `batteryCriticalThreshold`, `batteryWarningThreshold`, `cpuCriticalThreshold`, `cpuWarningThreshold`, `criticalColor`, `diskAvailCriticalThreshold`, `diskAvailWarningThreshold`, `diskCriticalThreshold`, `diskWarningThreshold`, `enableDgpuMonitoring`, `externalMonitor`, `gpuCriticalThreshold`, `gpuWarningThreshold`, `memCriticalThreshold`, `memWarningThreshold`, `swapCriticalThreshold`, `swapWarningThreshold`, `tempCriticalThreshold`, `tempWarningThreshold`, `useCustomColors`, `warningColor` |
| `osd` | `autoHideMs`, `backgroundOpacity`, `enabled`, `enabledTypes`, `location`, `monitors`, `overlayLayer` |
| `idle` | `customCommands`, `enabled`, `fadeDuration`, `lockCommand`, `lockTimeout`, `resumeLockCommand`, `resumeScreenOffCommand`, `resumeSuspendCommand`, `screenOffCommand`, `screenOffTimeout`, `suspendCommand`, `suspendTimeout` |
| `nightLight` | `autoSchedule`, `dayTemp`, `enabled`, `forced`, `manualSunrise`, `manualSunset`, `nightTemp` |
| `noctaliaPerformance` | `disableDesktopWidgets`, `disableWallpaper` |
| `desktopWidgets` | `enabled`, `gridSnap`, `gridSnapScale`, `monitorWidgets`, `overviewEnabled` |
| `hooks` | `colorGeneration`, `darkModeChange`, `enabled`, `performanceModeDisabled`, `performanceModeEnabled`, `screenLock`, `screenUnlock`, `session`, `startup`, `wallpaperChange` |
| `plugins` | `autoUpdate`, `notifyUpdates` |
| `templates` | `activeTemplates`, `enableUserTheming` |

### Example

```qml
// Read values
const density = Settings.data.bar.density;

// Per-screen override
Settings.setScreenOverride("DP-1", "position", "left");

// Persist immediately
Settings.saveImmediate();
```

---

## `Logger.qml`

Structured console logging with timestamp and module tagging.

### Exported methods

| Method | Signature | Notes |
|---|---|---|
| `d` | `(...args)` | Debug only (`Settings.isDebug === true`). |
| `i` | `(...args)` | Info, always logged. |
| `w` | `(...args)` | Warning, always logged. |
| `e` | `(...args)` | Error, always logged. |
| `callStack` | `()` | Logs current JS stack trace line-by-line. |

Internal helpers also present: `_formatMessage`, `_getStackTrace`.

### Example

```qml
Logger.i("Network", "Connected to", ssid)
Logger.e("Wallpaper", "Failed to load", path)
```

---

## `I18n.qml`

Runtime translation loader with locale detection and English fallback.

### Exported properties

| Property | Type | Notes |
|---|---|---|
| `isLoaded` | `bool` | True after current language file loads/parses. |
| `langCode` | `string` | Active translation code (may be shortened fallback). |
| `locale` | `var` | `Qt.locale(fullLocaleCode)`. |
| `systemDetectedLangCode` | `string` | Initial auto-detected language code. |
| `fullLocaleCode` | `string` | Preserves region/script variant from system. |
| `translations` | `var` | Active language dictionary object. |
| `fallbackTranslations` | `var` | English fallback dictionary. |
| `availableLanguages` | `var[]` | `en`, `en-GB`, `cs`, `de`, `es`, `fr`, `hu`, `it`, `ja`, `ko-KR`, `ku`, `nl`, `nn-HN`, `nn-NO`, `pl`, `pt`, `ru`, `sv`, `tr`, `uk-UA`, `vi`, `zh-CN`, `zh-TW`. |
| `dateFormats` | `var` | Language→date-format map used by calendar/lock screen. |

### Exported signals

| Signal | Notes |
|---|---|
| `languageChanged(string newLanguage)` | Emitted when `setLanguage` switches language. |
| `translationsLoaded()` | Emitted after translation file load and parse. |

### Exported functions

| Function | Signature | Behavior |
|---|---|---|
| `stripScript` | `(tag)` | Removes 4-letter script subtag (e.g. `fr-Latn-FR` → `fr-FR`). |
| `determineFastLanguage` | `()` | Picks language from user setting or `Qt.locale().uiLanguages`. |
| `dateFormat` | `()` | Returns default date format for active language family. |
| `setLanguage` | `(newLangCode, fullLocale?)` | Sets active language and reloads translations. |
| `loadTranslations` | `()` | Loads `Assets/Translations/<langCode>.json`. |
| `hasTranslation` | `(key)` | Checks dot-path key exists and resolves to string. |
| `getAllKeys` | `(obj?, prefix?)` | Returns flattened translation keys. |
| `reload` | `()` | Reloads current language file. |
| `tr` | `(key, interpolations={})` | Main translation with interpolation and fallback to English. |
| `trp` | `(key, count, interpolations={})` | Plural helper (`key` vs `key-plural`) + `{count}` interpolation. |

### Example

```qml
text: I18n.tr("common.settings")
text: I18n.trp("notifications.item", unreadCount)
```

---

## `Icons.qml` and `IconsTabler.qml`

`Icons.qml` wraps the tabler icon font, handles cache-busting font reloads, and exposes icon maps from `IconsTabler.qml`.

### `Icons.qml` exported API

| Property | Type | Notes |
|---|---|---|
| `fontFamily` | `string` | Current loaded icon font family name. |
| `defaultIcon` | `string` | From `IconsTabler.defaultIcon` (`"skull"`). |
| `icons` | `var` | Raw icon-name → glyph map from `IconsTabler.icons`. |
| `aliases` | `var` | Alias map from `IconsTabler.aliases`. |
| `fontPath` | `string` | `/Assets/Fonts/tabler/noctalia-tabler-icons.ttf`. |
| `currentFontLoader` | `FontLoader` | Active loader object. |
| `fontVersion` | `int` | Incremented on forced reload. |
| `cacheBustingPath` | `string` | Font URL with `?v=<fontVersion>&t=<timestamp>`. |

| Signal | Notes |
|---|---|
| `fontReloaded()` | Emitted when new FontLoader reports `Ready`. |

| Function | Signature | Behavior |
|---|---|---|
| `get` | `(iconName)` | Resolves alias then returns glyph from icon map. |
| `loadFontWithCacheBusting` | `()` | Recreates FontLoader with cache-busted URL. |
| `reloadFont` | `()` | Increments version and reloads font. |

### `IconsTabler.qml` exported API

| Property | Type | Notes |
|---|---|---|
| `defaultIcon` | `string` | Fallback icon key (`"skull"`). |
| `aliases` | `var` | Alias map (~171 keys) mapping friendly names to canonical icon names. |
| `icons` | `var` | Canonical icon map (~6013 icon glyph entries). |

### Example

```qml
Text {
  font.family: Icons.fontFamily
  text: Icons.get("settings") || Icons.get(Icons.defaultIcon)
}
```

---

## Common Patterns and Common Mistakes (`qs.Commons`)

### Good patterns

- Use `Settings.data` for reactive reads; use `Settings.saveImmediate()` only when you need immediate disk flush.
- Use `I18n.tr`/`I18n.trp` for all user-visible strings, including list models (as done in `Color.colorKeyModel`).
- Use `Icons.get(aliasOrName)` instead of hardcoding raw glyphs.
- Use `Color.resolveColorKey*` helper methods when settings store semantic keys (`primary`, `secondary`, etc.).
- Use `Style` helpers (`toOdd`, per-screen sizing helpers) for pixel-aligned bar geometry.

### Frequent mistakes

- Assuming `I18n.isLoaded` is true during early startup; `tr()` returns keys before load.
- Writing directly to `Settings.data.bar.screenOverrides` structures without cloning/upsert helpers (`setScreenOverride`, `clearScreenOverride`).
- Using `Logger.d` for critical production logs (debug logs are hidden unless `NOCTALIA_DEBUG=1`).
- Hardcoding icon names without alias/canonical fallback handling.
- Bypassing `Color.smartAlpha` while translucent widgets are enabled, causing inconsistent alpha behavior.

## qs.Services.UI

### `PanelService`

Source: `/tmp/noctalia-shell/Services/UI/PanelService.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`lockScreen`|`var`|`null`|A ref. to the lockScreen, so it's accessible from anywhere.|
|`registeredPanels`|`var`|`({})`|Panels|
|`openedPanel`|`var`|`null`|openedPanel property.|
|`closingPanel`|`var`|`null`|closingPanel property.|
|`closedImmediately`|`bool`|`false`|closedImmediately property.|
|`overlayLauncherOpen`|`bool`|`false`|Overlay launcher state (separate from normal panels)|
|`overlayLauncherScreen`|`var`|`null`|overlayLauncherScreen property.|
|`overlayLauncherCore`|`var`|`null`|Reference to LauncherCore when overlay is active|
|`isInitializingKeyboard`|`bool`|`false`|Brief window after panel opens where Exclusive keyboard is allowed on Hyprland This allows text inputs to receive focus, then switches to OnDemand for click-to-close|
|`isKeybindRecording`|`bool`|`false`|Global state for keybind recording components to block global shortcuts|
|`backgroundSlotAssignments`|`var`|`[null, null]`|Background slot assignments for dynamic panel background rendering Slot 0: currently opening/open panel, Slot 1: closing panel|
|`popupMenuWindows`|`var`|`({})`|Popup menu windows (one per screen) - used for both tray menus and context menus|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`willOpen`|`(—)`|Emitted on willOpen.|
|`didClose`|`(—)`|Emitted on didClose.|
|`slotAssignmentChanged`|`(int slotIndex, var panel)`|Emitted on slotAssignmentChanged.|
|`popupMenuWindowRegistered`|`(var screen)`|Emitted on popupMenuWindowRegistered.|

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`assignToSlot`|`(slotIndex, panel)`|Method assignToSlot.|
|`registerPanel`|`(panel)`|Register this panel (called after panel is loaded)|
|`registerPopupMenuWindow`|`(screen, window)`|Register popup menu window for a screen|
|`unregisterPopupMenuWindow`|`(screen)`|Unregister popup menu window for a screen (called on destruction)|
|`getPopupMenuWindow`|`(screen)`|Get popup menu window for a screen|
|`showContextMenu`|`(contextMenu, anchorItem, screen, targetItem)`|Show a context menu with proper handling for all compositors Optional targetItem: if provided, menu will be horizontally centered on this item instead of anchorItem|
|`closeContextMenu`|`(screen)`|Close any open context menu or popup menu window|
|`showTrayMenu`|`(screen, trayItem, trayMenu, anchorItem, menuX, menuY, widgetSection, widgetIndex)`|Show a tray menu with proper handling for all compositors Returns true if menu was shown successfully|
|`closeTrayMenu`|`(screen)`|Close tray menu|
|`findFallbackScreen`|`(—)`|Find a fallback screen, prioritizing 0x0 position (primary)|
|`getPanel`|`(name, screen, fallback = true)`|Returns a panel (loads it on-demand if not yet loaded) By default, if panel not found on screen, tries other screens (favoring 0x0) Pass fallback=false to disable this behavior|
|`hasPanel`|`(name)`|Check if a panel exists|
|`canShowPanelsOnScreen`|`(screen)`|Check if panels can be shown on a given screen (has bar enabled or allowPanelsOnScreenWithoutBar)|
|`findScreenForPanels`|`(—)`|Find a screen that can show panels|
|`willOpenPanel`|`(panel)`|Helper to keep only one panel open at any time|
|`openLauncher`|`(screen)`|Open launcher panel (handles both normal and overlay mode)|
|`toggleLauncher`|`(screen)`|Toggle launcher panel|
|`closeOverlayLauncher`|`(—)`|Close overlay launcher|
|`closeOverlayLauncherImmediately`|`(—)`|Close overlay launcher immediately (for app launches)|
|`isLauncherOpen`|`(screen)`|Method isLauncherOpen.|
|`getLauncherSearchText`|`(screen)`|Method getLauncherSearchText.|
|`setLauncherSearchText`|`(screen, text)`|Method setLauncherSearchText.|
|`openLauncherWithSearch`|`(screen, searchText)`|Method openLauncherWithSearch.|
|`closeLauncher`|`(screen)`|Method closeLauncher.|
|`closePanel`|`(—)`|Close any open panel (for general use)|
|`closedPanel`|`(panel)`|Method closedPanel.|

#### Example
```qml
PanelService.openLauncher(Quickshell.screens[0])
```

### `BarService`

Source: `/tmp/noctalia-shell/Services/UI/BarService.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`isVisible`|`bool`|`true`|isVisible property.|
|`effectivelyVisible`|`bool`|`{`|Computed visibility that factors in compositor overview state|
|`readyBars`|`var`|`({})`|readyBars property.|
|`widgetsRevision`|`int`|`0`|Revision counter - increment when widget list structure changes (add/remove/reorder) This triggers Bar.qml to re-sync its ListModels|
|`widgetInstances`|`var`|`({})`|Registry to store actual widget instances Key format: "screenName\|section\|widgetId\|index"|
|`popupOpen`|`bool`|`false`|Track if a popup menu is open from the bar (prevents auto-hide)|
|`screenAutoHideState`|`var`|`({})`|Auto-hide state per screen: { screenName: { hovered: bool, hidden: bool } }|
|`lastWorkspaceId`|`var`|`null`|Track last workspace ID to detect actual workspace changes|
|`_pendingWorkspaceScreen`|`string`|`""`|Debounce rapid workspace switches to reduce load/unload races (SIGSEGV in QV4)|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`activeWidgetsChanged`|`(—)`|Emitted on activeWidgetsChanged.|
|`barReadyChanged`|`(string screenName)`|Emitted on barReadyChanged.|
|`barAutoHideStateChanged`|`(string screenName, bool hidden)`|Emitted on barAutoHideStateChanged.|
|`barHoverStateChanged`|`(string screenName, bool hovered)`|Emitted on barHoverStateChanged.|

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`getOrCreateAutoHideState`|`(screenName)`|Get or create auto-hide state for a screen|
|`setScreenHovered`|`(screenName, hovered)`|Set hover state for a screen|
|`setScreenHidden`|`(screenName, hidden)`|Set hidden state for a screen|
|`isBarHidden`|`(screenName)`|Check if bar is hidden on a screen|
|`isBarHovered`|`(screenName)`|Check if bar is hovered on a screen|
|`toggleVisibility`|`(—)`|Toggle bar visibility. In auto-hide mode, toggles the per-screen hidden state without touching isVisible (so hover-to-show still works). For non-auto-hide screens, toggles the global isVisible flag.|
|`show`|`(—)`|Show bar. In auto-hide mode, un-hides on screens with auto-hide enabled. The bar stays visible until the user hovers and moves away.|
|`hide`|`(—)`|Hide bar. In auto-hide mode, sets per-screen hidden state without touching isVisible so hover-to-show still works. For non-auto-hide screens, sets global visibility to false.|
|`peek`|`(—)`|Temporarily show the bar, then auto-hide after the configured delay. Uses the same pattern as workspace switch: show, then emit unhover to start the hide timer.|
|`registerBar`|`(screenName)`|Function for the Bar to call when it's ready|
|`isBarReady`|`(screenName)`|Function for the Dock to check if the bar is ready|
|`registerWidget`|`(screenName, section, widgetId, index, instance)`|Register a widget instance|
|`unregisterWidget`|`(screenName, section, widgetId, index)`|Unregister a widget instance|
|`lookupWidget`|`(widgetId, screenName = null, section = null, index = null)`|Lookup a specific widget instance (returns the actual QML instance)|
|`getAllWidgetInstances`|`(widgetId = null, screenName = null, section = null)`|Get all instances of a widget type|
|`getWidgetWithMetadata`|`(widgetId, screenName = null, section = null)`|Get widget with full metadata|
|`getWidgetsBySection`|`(section, screenName = null)`|Get all widgets in a specific section|
|`getAllRegisteredWidgets`|`(—)`|Get all registered widgets (for debugging)|
|`hasWidget`|`(widgetId, section = null, screenName = null)`|Check if a widget type exists in a section|
|`destroyPluginWidgetInstances`|`(pluginId)`|Unregister all widget instances for a plugin (used during hot reload) Note: We don't destroy instances here - the Loader manages that when the component is unregistered|
|`getPillDirection`|`(widgetInstance)`|Get pill direction for a widget instance|
|`getTooltipDirection`|`(screenName)`|Method getTooltipDirection.|
|`closeExistingDialogs`|`(popupMenuWindow)`|Helper to close any existing dialogs in a popup menu window|
|`openWidgetSettings`|`(screen, section, index, widgetId, widgetData)`|Open widget settings dialog for a bar widget Parameters: screen: The screen to show the dialog on section: Section id ("left", "center", "right") index: Widget index in section widgetId: Widget type id (e.g., "Volume") widgetData: Current widget settings object|
|`openPluginSettings`|`(screen, pluginManifest)`|Open plugin settings dialog Parameters: screen: The screen to show the dialog on pluginManifest: The plugin's manifest object (must have entryPoints.settings)|

#### Example
```qml
BarService.toggleVisibility()
```

### `ToastService`

Source: `/tmp/noctalia-shell/Services/UI/ToastService.qml`

#### Properties
_None._

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`notify`|`(string title, string description, string icon, string type, int duration, string actionLabel, var actionCallback)`|Simple signal-based notification system actionLabel: optional label for clickable action link actionCallback: optional function to call when action is clicked|
|`dismiss`|`(—)`|Emitted on dismiss.|

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`showNotice`|`(title, description = "", icon = "", duration = 3000, actionLabel = "", actionCallback = null)`|Convenience methods|
|`showWarning`|`(title, description = "", duration = 4000, actionLabel = "", actionCallback = null)`|Method showWarning.|
|`showError`|`(title, description = "", duration = 6000, actionLabel = "", actionCallback = null)`|Method showError.|
|`dismissToast`|`(—)`|Method dismissToast.|

#### Example
```qml
ToastService.showNotice(I18n.tr("common.saved"))
```

### `TooltipService`

Source: `/tmp/noctalia-shell/Services/UI/TooltipService.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`activeTooltip`|`var`|`null`|activeTooltip property.|
|`pendingTooltip`|`var`|`null`|Track tooltip being created|
|`tooltipComponent`|`Component`|`Component {`|tooltipComponent property.|

#### Signals
_None._

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`show`|`(target, content, direction, delay, fontFamily)`|Method show.|
|`hide`|`(target)`|Method hide.|
|`hideImmediately`|`(—)`|Method hideImmediately.|
|`updateContent`|`(newContent)`|Method updateContent.|
|`updateText`|`(newText)`|Backward compatibility alias|

#### Example
```qml
TooltipService.show(someItem, I18n.tr("common.settings"), "auto")
```

### `WallpaperService`

Source: `/tmp/noctalia-shell/Services/UI/WallpaperService.qml`

#### Properties
|Name|Type|Default|Description|
|---|---|---|---|
|`fillModeModel`|`ListModel`|`ListModel {}`|fillModeModel property (readonly).|
|`defaultDirectory`|`string`|`Settings.preprocessPath(Settings.data.wallpaper.directory)`|defaultDirectory property (readonly).|
|`solidColorPrefix`|`string`|`"solid:`|"|
|`transitionsModel`|`ListModel`|`ListModel {}`|All available wallpaper transitions|
|`allTransitions`|`var`|`Array.from({`|All transition keys but filter out "none" and "random" so we are left with the real transitions|
|`wallpaperLists`|`var`|`({})`|wallpaperLists property.|
|`scanningCount`|`int`|`0`|scanningCount property.|
|`currentWallpapers`|`var`|`({})`|Cache for current wallpapers - can be updated directly since we use signals for notifications|
|`alphabeticalIndices`|`var`|`({})`|Track current alphabetical index for each screen|
|`usedRandomWallpapers`|`var`|`({})`|Track used wallpapers for random mode (persisted across reboots)|
|`isInitialized`|`bool`|`false`|isInitialized property.|
|`wallpaperCacheFile`|`string`|`""`|wallpaperCacheFile property.|
|`scanning`|`bool`|`(scanningCount > 0)`|scanning property (readonly).|
|`noctaliaDefaultWallpaper`|`string`|`Quickshell.shellDir + "/Assets/Wallpaper/noctalia.png"`|noctaliaDefaultWallpaper property (readonly).|
|`defaultWallpaper`|`string`|`noctaliaDefaultWallpaper`|defaultWallpaper property.|
|`currentBrowsePaths`|`var`|`({})`|Browse mode: track current browse path per screen (separate from root directory)|
|`wallpaperSelectionAppearance`|`string`|`"light"`|Wallpaper panel: which appearance slot (light/dark) new selections apply to — like picking a monitor tab|
|`favoritesRevision`|`int`|`0`|Bumped when favorites are added/removed so grid delegates can refresh star state|
|`pendingFavoriteSchemeRefresh`|`var`|`null`|After favoriting, refresh snapshot once theme colors finish transitioning|
|`recursiveProcesses`|`var`|`({})`|Process instances for scanning (one per screen)|
|`_favoriteNotFound`|`int`|`-1`|------------------------------------------------------------------- Favorites ------------------------------------------------------------------- TODO (~few weeks): Remove per-favorite `darkMode` (the boolean on each Settings.data.wallpaper.favorites[] entry). It duplicates `appearance` and is unrelated to Settings.data.colorSchemes.darkMode (global shell light/dark). Plan: one-time migration, then drop writes and the fallback in _favoriteAppearanceSlot. -------------------------------------------------------------------|

#### Signals
|Signal|Signature|Description|
|---|---|---|
|`wallpaperChanged`|`(string screenName, string path)`|Signals for reactive UI updates|
|`wallpaperProcessingComplete`|`(string screenName, string path, string cachedPath)`|Emitted when a wallpaper changes|
|`wallpaperDirectoryChanged`|`(string screenName, string directory)`|Emitted when wallpaper processing (resize/cache) is complete. cachedPath is the resized version.|
|`wallpaperListChanged`|`(string screenName, int count)`|Emitted when a monitor's directory changes|
|`browsePathChanged`|`(string screenName, string path)`|Signal emitted when browse path changes for a screen|
|`favoritesChanged`|`(string path)`|Emitted on favoritesChanged.|
|`favoriteDataUpdated`|`(string path)`|Emitted on favoriteDataUpdated.|

#### Methods
|Method|Parameters|Description|
|---|---|---|
|`scheduleFavoriteSchemeSnapshot`|`(path, slot)`|Method scheduleFavoriteSchemeSnapshot.|
|`init`|`(—)`|-------------------------------------------------|
|`_scheduleThemeSyncFromCachedWallpaper`|`(—)`|Cache restore updates currentWallpapers without _setWallpaper, so wallpaperChanged does not fire.|
|`translateModels`|`(—)`|-------------------------------------------------|
|`getFillModeUniform`|`(—)`|-------------------------------------------------------------------|
|`isSolidColorPath`|`(path)`|------------------------------------------------------------------- Solid color helpers -------------------------------------------------------------------|
|`getSolidColor`|`(path)`|Method getSolidColor.|
|`createSolidColorPath`|`(colorString)`|Method createSolidColorPath.|
|`setSolidColor`|`(colorString)`|Method setSolidColor.|
|`_isSplitWallpaperEntry`|`(entry)`|------------------------------------------------------------------- Per-screen wallpaper: persisted as { light, dark } (legacy string loads are normalized) -------------------------------------------------------------------|
|`_pathsFromEntry`|`(entry)`|Method _pathsFromEntry.|
|`_cloneWallpaperEntry`|`(entry)`|Method _cloneWallpaperEntry.|
|`_entriesEqual`|`(a, b)`|Method _entriesEqual.|
|`_entryToEffectivePath`|`(entry)`|Method _entryToEffectivePath.|
|`_normalizeAppearanceSlot`|`(slot)`|Method _normalizeAppearanceSlot.|
|`_defaultAppearanceSlotForChange`|`(slot)`|Method _defaultAppearanceSlotForChange.|
|`getWallpaperPathForSlot`|`(screenName, appearanceSlot)`|Method getWallpaperPathForSlot.|
|`getWallpapersEffectiveMap`|`(—)`|Method getWallpapersEffectiveMap.|
|`_ensureObjectWallpaperEntries`|`(—)`|Method _ensureObjectWallpaperEntries.|
|`_notifyAllWallpapersChanged`|`(—)`|Method _notifyAllWallpapersChanged.|
|`getMonitorConfig`|`(screenName)`|------------------------------------------------------------------- Get specific monitor wallpaper data|
|`getMonitorDirectory`|`(screenName)`|------------------------------------------------------------------- Get specific monitor directory|
|`setMonitorDirectory`|`(screenName, directory)`|------------------------------------------------------------------- Set specific monitor directory|
|`getWallpaper`|`(screenName)`|------------------------------------------------------------------- Get specific monitor wallpaper - now from cache|
|`changeWallpaper`|`(path, screenName, appearanceSlot)`|-------------------------------------------------------------------|
|`_saveOutgoingFavorites`|`(newPath, screenName, appearanceSlot)`|------------------------------------------------------------------- Save the color scheme of any favorited wallpapers that are about to be replaced, while the current settings still reflect them.|
|`_inheritWallpaperFromExistingScreen`|`(screenName)`|-------------------------------------------------------------------|
|`_syncWallpaperSlotsWhenLinking`|`(—)`|Method _syncWallpaperSlotsWhenLinking.|
|`_setWallpaper`|`(screenName, path, appearanceSlot)`|Method _setWallpaper.|
|`setRandomWallpaper`|`(screen)`|-------------------------------------------------------------------|
|`_pickUnusedRandom`|`(key, wallpaperList)`|------------------------------------------------------------------- Pick a random wallpaper that hasn't been used yet in the current cycle. Once all wallpapers have been shown, resets the pool (keeping only the last-shown wallpaper to avoid an immediate repeat).|
|`setAlphabeticalWallpaper`|`(—)`|-------------------------------------------------------------------|
|`toggleRandomWallpaper`|`(—)`|-------------------------------------------------------------------|
|`setNextWallpaper`|`(—)`|-------------------------------------------------------------------|
|`restartRandomWallpaperTimer`|`(—)`|-------------------------------------------------------------------|
|`getWallpapersList`|`(screenName)`|-------------------------------------------------------------------|
|`getCurrentBrowsePath`|`(screenName)`|------------------------------------------------------------------- Browse mode helper functions -------------------------------------------------------------------|
|`setBrowsePath`|`(screenName, path)`|Method setBrowsePath.|
|`navigateUp`|`(screenName)`|Method navigateUp.|
|`navigateToRoot`|`(screenName)`|Method navigateToRoot.|
|`scanDirectoryWithDirs`|`(screenName, directory, callback)`|Scan directory with optional directory listing (for browse mode) callback receives { files: [], directories: [] }|
|`_scanForDirectories`|`(directory, callback)`|Method _scanForDirectories.|
|`refreshWallpapersList`|`(—)`|-------------------------------------------------------------------|
|`_scanDirectoryInternal`|`(screenName, directory, recursive, updateList, callback)`|Internal scan function recursive: whether to scan subdirectories updateList: whether to update wallpaperLists and emit signal callback: optional callback with files array|
|`scanDirectoryRecursive`|`(screenName, directory)`|-------------------------------------------------------------------|
|`_favoriteAppearanceSlot`|`(f)`|-------------------------------------------------------------------|
|`_findFavoriteIndex`|`(path, appearanceSlot)`|Method _findFavoriteIndex.|
|`_findAnyFavoriteIndexForPath`|`(path)`|Method _findAnyFavoriteIndexForPath.|
|`_dedupeWallpaperFavoritesByPath`|`(—)`|Method _dedupeWallpaperFavoritesByPath.|
|`_createFavoriteEntry`|`(path, appearanceSlot)`|-------------------------------------------------------------------|
|`isFavorite`|`(path, appearanceSlot)`|------------------------------------------------------------------- Favorites are per (path, light\|dark): at most one entry per path, tagged with the tab you starred from.|
|`favoriteEntryForPath`|`(path)`|Single favorite entry per path; use _favoriteAppearanceSlot(entry) for light vs dark it was starred under.|
|`getFavoriteForDisplay`|`(path)`|Method getFavoriteForDisplay.|
|`toggleFavorite`|`(path, appearanceSlot, screenName)`|-------------------------------------------------------------------|
|`_applyFavoriteThemeFromEntry`|`(favorite, appearanceSlotOverride)`|Apply saved scheme from a favorite. Optional appearanceSlotOverride sets light vs dark target (UI tab or system mode).|
|`reapplyFavoriteThemeForActiveWallpaper`|`(—)`|When light/dark changes (or on startup), re-load scheme from the favorite for the wallpaper now shown for that slot.|
|`applyFavoriteTheme`|`(path, screenName, appearanceSlot)`|-------------------------------------------------------------------|
|`updateFavoriteColorScheme`|`(path, appearanceSlot)`|-------------------------------------------------------------------|
|`_updateCurrentWallpaperFavorites`|`(—)`|Method _updateCurrentWallpaperFavorites.|

#### Example
```qml
WallpaperService.setNextWallpaper()
```

## Appendix: Common Mistakes

1. `NIconButton`: using `iconColor` instead of `colorFg` / `colorFgHover`.
2. Calling `I18n.tr("key")` and expecting fallback strings without validating key existence (missing keys return the key path).
3. Forgetting required widget properties (`required property ...`) such as `NBattery.percentage` or `NLinearGauge.ratio`.
4. Hardcoding user-facing strings instead of routing through `I18n.tr` / `I18n.trp`.
5. Using `console.log` directly instead of `Logger.d/i/w/e` (especially debug-level filtering via `Settings.isDebug`).
6. Passing empty arrays/objects to tooltips or menus without guard checks, leading to blank popups.
7. Mutating `Settings.data` nested objects directly in-place without using helper APIs when available.
8. Ignoring screen-specific behavior (`screen.name`, per-screen overrides) in panel/bar/wallpaper operations.
9. Using `Color.m*` constants directly where semantic keys (`primary`, `secondary`, etc.) should be resolved through `Color.resolveColorKey*`.
10. Not handling disabled state (`enabled: false`) in interactive widgets, causing visual mismatch and unintended input handling.
