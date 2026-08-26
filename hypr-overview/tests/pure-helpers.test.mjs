import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const pluginRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function readPluginFile(relativePath) {
  return fs.readFileSync(path.join(pluginRoot, relativePath), "utf8");
}

function loadHelper(relativePath) {
  const source = readPluginFile(relativePath).replace(/^\.pragma library\s*$/m, "");
  const context = vm.createContext({ console, Math, Number, String, parseInt, isFinite, isNaN, Object });
  vm.runInContext(source, context, { filename: relativePath });
  return context;
}

const settings = loadHelper("helpers/SettingsSchema.js");
const state = loadHelper("helpers/HyprlandState.js");
const drag = loadHelper("helpers/DragDecision.js");
const intent = loadHelper("helpers/DropIntent.js");
const retileBlueprint = loadHelper("helpers/RetileBlueprint.js");
const mapping = loadHelper("helpers/WorkspaceDragMapping.js");
const geometry = loadHelper("helpers/WorkspaceGeometry.js");
const layout = loadHelper("helpers/LayoutStrategy.js");
const dispatchCompat = loadHelper("helpers/DispatchCompat.js");
const mainQml = readPluginFile("Main.qml");
const hyprlandConfigQml = readPluginFile("helpers/HyprlandConfig.qml");
const windowPreviewQml = readPluginFile("components/WindowPreview.qml");
const overviewGridQml = readPluginFile("components/OverviewGrid.qml");
const layoutSwitcherQml = readPluginFile("components/LayoutSwitcher.qml");
const settingsPreviewWindowQml = readPluginFile("components/SettingsPreviewWindow.qml");
const retilePreviewQml = readPluginFile("components/RetilePreview.qml");
const settingsQml = readPluginFile("Settings.qml");
const manifestJson = readPluginFile("manifest.json");
const i18nEnJson = readPluginFile("i18n/en.json");

function hasTopLevelRootBinding(source, bindingName, valuePattern = "[^\\n]+") {
  return new RegExp(`^  ${bindingName}:\\s*${valuePattern}`, "m").test(source);
}

function nearlyEqual(actual, expected, epsilon = 0.001) {
  assert.equal(Math.abs(actual - expected) <= epsilon, true);
}

assert.equal(/ThemeIcons\.(iconForAppId|iconFromName)/.test(windowPreviewQml), true);
assert.equal(windowPreviewQml.includes('Quickshell.iconPath(resolvedIcon, "application-x-executable")'), false);
assert.equal(/id:\s*steamIconFinder[\s\S]*?librarycache\/" \+ root\.steamAppId[\s\S]*?logo\.png/.test(windowPreviewQml), true);
assert.equal([mainQml, overviewGridQml, windowPreviewQml, settingsPreviewWindowQml].some(source => source.includes("scheduleCapture(")), false);
assert.equal(/property\s+int\s+overlayCaptureRevision:\s*0/.test(mainQml), true);
assert.equal(/property\s+var\s+overlayCaptureRevisionsByAddress:\s*\(\{\}\)/.test(mainQml), true);
assert.equal(/property\s+var\s+pendingOverlayRecaptureAddresses:\s*\[\]/.test(mainQml), true);
assert.equal(/function\s+requestOverlayRecapture\s*\(\s*reason,\s*addresses\s*\)[\s\S]*?pendingOverlayRecaptureAddresses\s*=\s*normalizeAddressList\(addresses\)[\s\S]*?overlayRecaptureEarly\.restart\(\)[\s\S]*?overlayRecaptureSettled\.restart\(\)/.test(mainQml), true);
assert.equal(/id:\s*overlayRecaptureEarly[\s\S]*?interval:\s*80[\s\S]*?bumpOverlayCaptureRevision/.test(mainQml), true);
assert.equal(/id:\s*overlayRecaptureSettled[\s\S]*?interval:\s*220[\s\S]*?bumpOverlayCaptureRevision/.test(mainQml), true);
assert.equal(/readonly\s+property\s+int\s+overlayCaptureRevision:\s*pluginMain\s*\?\s*pluginMain\.overlayCaptureRevision\s*:\s*0/.test(overviewGridQml), true);
assert.equal(/readonly\s+property\s+var\s+overlayCaptureRevisionsByAddress:\s*pluginMain\s*\?\s*pluginMain\.overlayCaptureRevisionsByAddress\s*:\s*\(\{\}\)/.test(overviewGridQml), true);
assert.equal(/readonly\s+property\s+int\s+clientRefreshRevision:\s*pluginMain\s*\?\s*pluginMain\.clientRefreshRevision\s*:\s*0/.test(overviewGridQml), true);
assert.equal(/captureRevision:\s*root\.overlayCaptureRevision \+ root\.overlayCaptureRevisionForAddress\(address\)/.test(overviewGridQml), true);
assert.equal(/property\s+int\s+captureRevision:\s*0/.test(windowPreviewQml), true);
assert.equal(/onCaptureRevisionChanged:\s*\{[\s\S]*?queueCaptureRebind\("revision"\)/.test(windowPreviewQml), true);
assert.equal(/onDisplayedPreviewSizeKeyChanged:\s*\{[\s\S]*?queueCaptureRebind\("size"\)/.test(windowPreviewQml), true);
assert.equal(/function\s+queueCaptureRebind\(reason\)[\s\S]*?captureSourceEnabled\s*=\s*false[\s\S]*?captureSourceRebind\.restart\(\)/.test(windowPreviewQml), true);
assert.equal(/property\s+string\s+pendingCaptureRebindReason:\s*""/.test(windowPreviewQml), true);
assert.equal(/function\s+queueCaptureRebind\(reason\)[\s\S]*?if\s*\(retileTransitionActive\)\s*\{[\s\S]*?pendingCaptureRebindReason\s*=\s*reason \|\| "retile";[\s\S]*?return;[\s\S]*?\}/.test(windowPreviewQml), true);
assert.equal(/onRetileTransitionActiveChanged:\s*\{[\s\S]*?!retileTransitionActive && pendingCaptureRebindReason !== ""[\s\S]*?queueCaptureRebind\(pendingReason\)/.test(windowPreviewQml), true);
assert.equal(/captureSource:\s*\{[\s\S]*?!root\.captureSourceEnabled[\s\S]*?return\s+null[\s\S]*?return\s+root\.toplevel/.test(windowPreviewQml), true);
assert.equal(/live:\s*root\.visualMode === "live" && !root\.retileTransitionActive/.test(windowPreviewQml), true);
assert.equal((overviewGridQml.match(/pluginMain\.requestOverlayRecapture\(/g) || []).length, 1);
assert.equal((overviewGridQml.match(/pluginMain\.requestRetileGeometryRefresh\(/g) || []).length, 1);
assert.equal((overviewGridQml.match(/pluginMain\.requestRetileOverlayRecapture\(/g) || []).length, 0);
assert.equal(/needsOverlayRecapture\s*=\s*releaseDecision\.type\s*===\s*"tiledSwap"\s*\|\|\s*releaseDecision\.type\s*===\s*"tiledSplit"\s*\|\|\s*releaseDecision\.type\s*===\s*"layoutReorder"/.test(overviewGridQml), true);
assert.equal(/var\s+needsRetileTransition\s*=\s*releaseDecision\.type\s*===\s*"tiledSwap"\s*\|\|\s*releaseDecision\.type\s*===\s*"tiledSplit";/.test(overviewGridQml), true);
assert.equal(/var\s+layoutRecaptureAddresses\s*=\s*needsOverlayRecapture \? root\.workspaceWindowAddresses\(currentWsId\) : \[\]/.test(overviewGridQml), true);
assert.equal(/if\s*\(needsOverlayRecapture\s*&&\s*pluginMain\.updateAll\)\s*\{[\s\S]*?pluginMain\.updateAll\(\);[\s\S]*?if\s*\(needsRetileTransition && pluginMain\.requestRetileGeometryRefresh\)[\s\S]*?pluginMain\.requestRetileGeometryRefresh\(releaseDecision\.type,\s*layoutRecaptureAddresses\);[\s\S]*?else if\s*\(pluginMain\.requestOverlayRecapture\)[\s\S]*?pluginMain\.requestOverlayRecapture\(releaseDecision\.type,\s*layoutRecaptureAddresses\);[\s\S]*?\}/.test(overviewGridQml), true);
assert.equal(/debugLog\("drag",\s*"release=/.test(overviewGridQml), true);
assert.equal(/debugLog\("dispatch",[\s\S]*?commands=/.test(overviewGridQml), true);
assert.equal(overviewGridQml.includes('payload += "dispatch " + commands[i]'), false);
assert.equal(layoutSwitcherQml.includes("bash\", \"-c"), false);
assert.equal(layoutSwitcherQml.includes("hyprctl dispatch workspace"), false);
assert.equal(layoutSwitcherQml.includes("hyprctl\", \"--batch"), false);
assert.equal(overviewGridQml.includes("root.toggleSpecialWorkspace("), false);
assert.equal(/runHyprBatch\(\["togglespecialworkspace " \+/.test(overviewGridQml), true);
assert.equal(/property\s+bool\s+originalWarpOnChangeWorkspace:\s*false/.test(hyprlandConfigQml), true);
assert.equal(/property\s+bool\s+originalWarpOnToggleSpecial:\s*false/.test(hyprlandConfigQml), true);
assert.equal(/property\s+bool\s+originalAlwaysFollowOnDnd:\s*false/.test(hyprlandConfigQml), true);
assert.equal(/fetchOptionWithDefault\("cursor:warp_on_change_workspace",\s*false[\s\S]*?originalWarpOnChangeWorkspace\s*=\s*!!v/.test(hyprlandConfigQml), true);
assert.equal(/fetchOptionWithDefault\("cursor:warp_on_toggle_special",\s*false[\s\S]*?originalWarpOnToggleSpecial\s*=\s*!!v/.test(hyprlandConfigQml), true);
assert.equal(/fetchOptionWithDefault\("misc:always_follow_on_dnd",\s*false[\s\S]*?originalAlwaysFollowOnDnd\s*=\s*!!v/.test(hyprlandConfigQml), true);
assert.equal(/property\s+int\s+originalFetchPending:\s*0/.test(hyprlandConfigQml), true);
assert.equal(/function\s+completeOriginalFetch\(optionName\)[\s\S]*?originalFetchPending\s*=\s*Math\.max\(0,\s*originalFetchPending - 1\)[\s\S]*?if\s*\(originalFetchPending === 0\)[\s\S]*?hasFetchedOriginals\s*=\s*true/.test(hyprlandConfigQml), true);
assert.equal(/json\.bool !== undefined[\s\S]*?result\(json\.bool\)/.test(hyprlandConfigQml), true);
assert.equal(/function\s+enableDragMode\(\)[\s\S]*?runKeyword\("input:follow_mouse 0"\)[\s\S]*?runKeyword\("cursor:no_warps 1"\)[\s\S]*?runKeyword\("cursor:warp_on_change_workspace 0"\)[\s\S]*?runKeyword\("cursor:warp_on_toggle_special 0"\)[\s\S]*?runKeyword\("misc:always_follow_on_dnd 0"\)/.test(hyprlandConfigQml), true);
assert.equal(/function\s+disableDragMode\(\)[\s\S]*?runKeyword\("input:follow_mouse " \+ root\.originalFollowMouse\)[\s\S]*?runKeyword\("cursor:no_warps " \+ \(root\.originalNoWarps \? "1" : "0"\)\)[\s\S]*?runKeyword\("cursor:warp_on_change_workspace " \+ \(root\.originalWarpOnChangeWorkspace \? "1" : "0"\)\)[\s\S]*?runKeyword\("cursor:warp_on_toggle_special " \+ \(root\.originalWarpOnToggleSpecial \? "1" : "0"\)\)[\s\S]*?runKeyword\("misc:always_follow_on_dnd " \+ \(root\.originalAlwaysFollowOnDnd \? "1" : "0"\)\)/.test(hyprlandConfigQml), true);
assert.equal(/import\s+"DispatchCompat\.js"\s+as\s+DispatchCompat/.test(hyprlandConfigQml), true);
assert.equal(/function\s+runKeyword\(keyword\)[\s\S]*?DispatchCompat\.keywordToLuaConfig\("keyword " \+ keyword\)[\s\S]*?\["hyprctl",\s*"eval",\s*luaConfig\]/.test(hyprlandConfigQml), true);
assert.equal(/function\s+pointerProtectCommands\(\)[\s\S]*?"keyword input:follow_mouse 0"[\s\S]*?"keyword cursor:no_warps 1"[\s\S]*?"keyword cursor:warp_on_change_workspace 0"[\s\S]*?"keyword cursor:warp_on_toggle_special 0"[\s\S]*?"keyword misc:always_follow_on_dnd 0"/.test(mainQml), true);
assert.equal(/function\s+pointerRestoreCommands\(\)[\s\S]*?"keyword input:follow_mouse " \+[\s\S]*?originalFollowMouse[\s\S]*?"keyword cursor:no_warps " \+[\s\S]*?originalNoWarps[\s\S]*?"keyword cursor:warp_on_change_workspace " \+[\s\S]*?originalWarpOnChangeWorkspace[\s\S]*?"keyword cursor:warp_on_toggle_special " \+[\s\S]*?originalWarpOnToggleSpecial[\s\S]*?"keyword misc:always_follow_on_dnd " \+[\s\S]*?originalAlwaysFollowOnDnd/.test(mainQml), true);
assert.equal(/function\s+runHyprBatch\(commands,\s*options\)[\s\S]*?pluginMain\.runOverviewDispatch\(commands,\s*opts\)/.test(overviewGridQml), true);
assert.equal(/function\s+runOverviewDispatch\(commands,\s*options\)[\s\S]*?overviewCursorCaptureProcessComponent\.createObject\(root/.test(mainQml), true);
assert.equal(/command:\s*\["hyprctl",\s*"cursorpos"\]/.test(mainQml), true);
assert.equal(/function\s+launchOverviewDispatch\(batchId,\s*reason,\s*commands,\s*closeAfterDispatch,\s*cursorPosition,\s*captureFailure\)[\s\S]*?pointerProtectCommands\(\)\.concat\(commandsWithCursorRestore\(commands,\s*cursorPosition\)\)[\s\S]*?DispatchCompat\.commandsToBatchPayload\(guarded\)[\s\S]*?createObject\(root/.test(mainQml), true);
assert.equal(/cursor capture failed batchId=/.test(mainQml), true);
assert.equal(/var guarded = pointerProtectCommands\(\)\.concat\(commands\);[\s\S]{0,800}pointerRestoreCommands/.test(mainQml), false);
assert.equal(/function\s+runOverviewDispatch\(commands,\s*options\)[\s\S]*?closeAfterDispatch[\s\S]*?createObject\(root,[\s\S]*?"closeAfterDispatch":[\s\S]*?\)[\s\S]*?if\s*\(opts\.closeAfterDispatch\)\s*close\(\)/.test(mainQml), false);
assert.equal(/function\s+finishOverviewDispatch\(batchId,\s*reason,\s*exitCode[\s\S]*?if\s*\(exitCode === 0 && closeAfterDispatch\)[\s\S]*?close\(\)/.test(mainQml), true);
assert.equal(/function\s+requestOverviewPointerRestore\(reason,\s*force\)[\s\S]*?if\s*\(!force && \(overviewOpen \|\| overviewDispatchInFlight > 0\)\)[\s\S]*?return;[\s\S]*?overviewPointerRestoreGrace\.restart\(\)/.test(mainQml), true);
assert.equal(/onOverviewOpenChanged:\s*\{[\s\S]*?requestOverviewPointerRestore\("overview-closed"\)/.test(mainQml), true);
assert.equal(/Component\.onDestruction:\s*\{[\s\S]*?hyprConfig\.disableDragMode\(\)/.test(mainQml), true);
assert.equal(/onClicked:\s*\{[\s\S]*?root\.runHyprBatch\(\["workspace " \+ workspace\.workspaceValue\],\s*\{[\s\S]*?"closeAfterDispatch":\s*true(?![\s\S]*?"restoreAfterDispatch":\s*true)[\s\S]*?\}\);[\s\S]*?\}/.test(overviewGridQml), true);
assert.equal(/onTapped:\s*\(eventPoint,\s*button\) => \{[\s\S]*?var commands = \[\];[\s\S]*?commands\.push\("focuswindow address:" \+ address\);[\s\S]*?root\.runHyprBatch\(commands,\s*\{[\s\S]*?"closeAfterDispatch":\s*true(?![\s\S]*?"restoreAfterDispatch":\s*true)/.test(overviewGridQml), true);
assert.equal(overviewGridQml.includes("restoreAfterDispatch"), false);
assert.equal(/Clicked window[\s\S]*?dispatching close then focus/.test(overviewGridQml), false);
assert.equal(/root\.runHyprBatch\(releaseDecision\.commands\)/.test(overviewGridQml), true);
assert.equal(/switchLayout\(wsId,\s*layoutName\)[\s\S]*?commands\.push\("workspace " \+ wsId\)[\s\S]*?commands\.push\("keyword general:layout " \+ layoutName\)[\s\S]*?commands\.push\("workspace " \+ activeWsId\)[\s\S]*?pluginMain\.runOverviewDispatch\(commands/.test(layoutSwitcherQml), true);
assert.equal(/reset\/no-command reason=/.test(overviewGridQml), true);
assert.equal(/cancelled before decision/.test(overviewGridQml), true);
assert.equal(/beginLayoutMutationDebug\(releaseId,\s*releaseDecision\.type,\s*windowAddress,\s*debugRetileTargetAddress,\s*releaseDecision\.commands\)/.test(overviewGridQml), true);
assert.equal(/var\s+needsOverlayRecapture\s*=\s*releaseDecision\.type\s*===\s*"tiledSwap"\s*\|\|\s*releaseDecision\.type\s*===\s*"tiledSplit"\s*\|\|\s*releaseDecision\.type\s*===\s*"layoutReorder";[\s\S]*?if\s*\(needsOverlayRecapture\s*&&\s*pluginMain\s*&&\s*pluginMain\.beginLayoutMutationDebug\)/.test(overviewGridQml), true);
assert.equal(/function\s+beginLayoutMutationDebug[\s\S]*?mutationType !== "tiledSwap"[\s\S]*?mutationType !== "tiledSplit"[\s\S]*?mutationType !== "layoutReorder"[\s\S]*?return;/.test(mainQml), true);
assert.equal(/debugLog\("dispatch",\s*"release="[\s\S]*?tracking layout mutation/.test(mainQml), true);
assert.equal(/debugLog\("reconcile",\s*"release="[\s\S]*?elapsedMs=/.test(mainQml), true);
assert.equal(/property\s+int\s+clientRefreshRevision:\s*0/.test(mainQml), true);
assert.equal(/property\s+bool\s+pendingClientRefreshRecapture:\s*false/.test(mainQml), true);
assert.equal(/debugLog\("capture",\s*"request reason="[\s\S]*?scopedAddresses=[\s\S]*?timers=80ms,220ms,client-refresh/.test(mainQml), true);
assert.equal(/function\s+requestRetileGeometryRefresh\s*\(\s*reason,\s*addresses\s*\)[\s\S]*?pendingOverlayRecaptureAddresses\s*=\s*normalizeAddressList\(addresses\)[\s\S]*?timers=client-refresh[\s\S]*?overlayClientRefreshSettled\.restart\(\)/.test(mainQml), true);
assert.equal(/function\s+requestSettledRetileOverlayRecapture\s*\(\s*reason,\s*addresses\s*\)[\s\S]*?pendingOverlayRecaptureAddresses\s*=\s*normalizeAddressList\(addresses \|\| pendingOverlayRecaptureAddresses\)[\s\S]*?timers=settled-retile[\s\S]*?retileOverlayRecaptureSettled\.restart\(\)/.test(mainQml), true);
assert.equal(/debugLog\("capture",\s*"bump revision=/.test(mainQml), true);
assert.equal(/debugLog\("capture",\s*"bump scoped reason=/.test(mainQml), true);
assert.equal(/id:\s*overlayRecaptureEarly[\s\S]*?interval:\s*80[\s\S]*?bumpOverlayCaptureRevision/.test(mainQml), true);
assert.equal(/id:\s*overlayRecaptureSettled[\s\S]*?interval:\s*220[\s\S]*?bumpOverlayCaptureRevision/.test(mainQml), true);
assert.equal(/id:\s*retileOverlayRecaptureSettled[\s\S]*?interval:\s*16[\s\S]*?bumpOverlayCaptureRevision\(root\.pendingOverlayRecaptureReason \+ ":retile-settled",\s*root\.pendingOverlayRecaptureAddresses\)/.test(mainQml), true);
assert.equal(/id:\s*overlayClientRefreshEarly[\s\S]*?interval:\s*70[\s\S]*?updateWindowList\(\)/.test(mainQml), true);
assert.equal(/id:\s*overlayClientRefreshSettled[\s\S]*?interval:\s*150[\s\S]*?updateWindowList\(\)/.test(mainQml), true);
assert.equal(/id:\s*overlayRecaptureAfterClientRefresh[\s\S]*?interval:\s*16[\s\S]*?bumpOverlayCaptureRevision\(root\.pendingOverlayRecaptureReason \+ ":client-refresh",\s*root\.pendingOverlayRecaptureAddresses\)/.test(mainQml), true);
assert.equal(/root\.clientRefreshRevision \+= 1;[\s\S]*?if\s*\(root\.pendingClientRefreshRecapture\)[\s\S]*?overlayRecaptureAfterClientRefresh\.restart\(\)/.test(mainQml), true);
assert.equal(/debugLog\("revisionChanged address=/.test(windowPreviewQml), true);
assert.equal(/sourceDisabled address=/.test(windowPreviewQml), true);
assert.equal(/sourceEnabled address=/.test(windowPreviewQml), true);
assert.equal(/onRetileTransitionActiveChanged:\s*\{[\s\S]*?if\s*\(retileTransitionActive\)\s*\{[\s\S]*?captureSourceRebind\.stop\(\);[\s\S]*?captureSourceEnabled\s*=\s*overviewOpen/.test(windowPreviewQml), true);
assert.equal(/property\s+int\s+positionResyncRevision:\s*0/.test(windowPreviewQml), true);
assert.equal(/onPositionResyncRevisionChanged:[\s\S]*?x\s*=\s*Math\.round\(initX \+ calculatedShiftX\);[\s\S]*?y\s*=\s*Math\.round\(initY \+ calculatedShiftY\);/.test(windowPreviewQml), true);
assert.equal([manifestJson, i18nEnJson, settingsQml].some(source => /hypr-overview-debug|debug/i.test(source)), false);
assert.equal(windowPreviewQml.includes("hideSource: true"), false);
assert.equal(windowPreviewQml.includes("hideSource: root.visualMode === \"simplified\""), true);
assert.equal(/property\s+real\s+dragScale:\s*1\s*(?:\r?\n|$)/.test(windowPreviewQml), false);
assert.equal(windowPreviewQml.includes("property real dragOriginX"), true);
assert.equal(hasTopLevelRootBinding(windowPreviewQml, "transform", "\\["), false);
assert.equal(hasTopLevelRootBinding(windowPreviewQml, "clip", "true"), false);
assert.equal(/id:\s*visualShell[\s\S]*?transform:\s*\[[\s\S]*?Scale\s*\{[\s\S]*?origin\.x:\s*root\.dragOriginX/.test(windowPreviewQml), true);
assert.equal(/id:\s*visualShell[\s\S]*?Rotation\s*\{[\s\S]*?origin\.x:\s*root\.dragOriginX[\s\S]*?origin\.y:\s*root\.dragOriginY/.test(windowPreviewQml), true);
assert.equal(/id:\s*visualShell[\s\S]*?transform:\s*\[[\s\S]*?Translate\s*\{/.test(windowPreviewQml), false);
assert.equal(/id:\s*previewContentMask[\s\S]*?radius:\s*root\.effectiveCornerRadius/.test(windowPreviewQml), true);
assert.equal(/id:\s*maskedPreviewContent[\s\S]*?maskEnabled:\s*true[\s\S]*?maskSource:\s*previewContentMask/.test(windowPreviewQml), true);
assert.equal(windowPreviewQml.includes("origin.x: root.dragOriginX"), true);
assert.equal(/drag\.target:\s*parent/.test(overviewGridQml), false);
assert.equal(/drag\.target:\s*windowDelegate/.test(overviewGridQml), false);
assert.equal(/mapToGlobal/.test(overviewGridQml), false);
assert.equal(/mapFromGlobal/.test(overviewGridQml), false);
assert.equal(/DragHandler\s*\{[\s\S]*?target:\s*windowDelegate[\s\S]*?snapMode:\s*DragHandler\.NoSnap[\s\S]*?dragThreshold:\s*0[\s\S]*?acceptedButtons:\s*Qt\.LeftButton/.test(overviewGridQml), true);
assert.equal(/TapHandler\s*\{[\s\S]*?acceptedButtons:\s*Qt\.LeftButton/.test(overviewGridQml), true);
assert.equal(/TapHandler\s*\{[\s\S]*?acceptedButtons:\s*Qt\.MiddleButton/.test(overviewGridQml), true);
assert.equal(/HoverHandler\s*\{[\s\S]*?onHoveredChanged:\s*windowDelegate\.hovered\s*=/.test(overviewGridQml), true);
assert.equal(/windowDelegate\.x\s*=\s*dragStartItemX\s*\+\s*currentPointer\.x\s*-\s*dragStartPointerX/.test(overviewGridQml), false);
assert.equal(/windowDelegate\.y\s*=\s*dragStartItemY\s*\+\s*currentPointer\.y\s*-\s*dragStartPointerY/.test(overviewGridQml), false);
assert.equal(/dragArea\.mapToItem\(windowSpace/.test(overviewGridQml), false);
assert.equal(/target:\s*dragSurface/.test(settingsPreviewWindowQml), false);
assert.equal(/DragHandler\s*\{[\s\S]*?target:\s*null[\s\S]*?dragThreshold:\s*0/.test(settingsPreviewWindowQml), true);
assert.equal(/dragHandler\.translation\.x/.test(settingsPreviewWindowQml), true);
assert.equal(/dragHandler\.translation\.y/.test(settingsPreviewWindowQml), true);
assert.equal(/margins\s*\{[\s\S]*?(top|left):\s*previewRoot\.window[XY]/.test(settingsPreviewWindowQml), false);
assert.equal(/id:\s*windowFrame[\s\S]*?x:\s*previewRoot\.windowX[\s\S]*?y:\s*previewRoot\.windowY/.test(settingsPreviewWindowQml), true);
assert.equal(/mask:\s*Region\s*\{[\s\S]*?item:\s*previewRoot\.visible\s*\?\s*windowFrame\s*:\s*null/.test(settingsPreviewWindowQml), true);
assert.equal(/centroid\.scenePosition/.test(settingsPreviewWindowQml), false);
assert.equal(/startCursorScene/.test(settingsPreviewWindowQml), false);
assert.equal(/commitDragSurfacePosition/.test(settingsPreviewWindowQml), false);
assert.equal(/import\s+"\.\.\/helpers\/DropIntent\.js"\s+as\s+DropIntent/.test(overviewGridQml), true);
assert.equal(/property\s+var\s+currentDropIntent:\s+null/.test(overviewGridQml), true);
assert.equal(/function\s+buildDropIntentForDelegate/.test(overviewGridQml), true);
assert.equal(/DragDecision\.decideRelease\(\{[\s\S]*?"intent":\s*dropIntent/.test(overviewGridQml), true);
assert.equal(/import\s+"\.\.\/helpers\/RetileBlueprint\.js"\s+as\s+RetileBlueprint/.test(overviewGridQml), true);
assert.equal(/function\s+buildRetileWindowRecords\(workspaceId\)/.test(overviewGridQml), true);
assert.equal(/RetileBlueprint\.resolveTarget\(\{[\s\S]*?"deadzonePx":\s*6/.test(overviewGridQml), true);
assert.equal(/"minSplitRatio":\s*root\.minimumSplitZoneRatio/.test(overviewGridQml), true);
assert.equal(/readonly\s+property\s+real\s+minimumSplitZoneRatio:\s*0\.42/.test(overviewGridQml), true);
assert.equal(/directionDebounce|pendingRetileTarget|pendingRetileDirection|directionLockMinConfidence/.test(overviewGridQml), false);
assert.equal(/function\s+dragHotspotInWindowSpace\(workspaceItem,\s*drag,\s*dragSource\)[\s\S]*?workspaceItem\.mapToItem\(windowSpace,\s*drag\.x,\s*drag\.y\)/.test(overviewGridQml), true);
assert.equal(/dragSource\.x \+ dragSource\.dragOriginX[\s\S]*?dragSource\.y \+ dragSource\.dragOriginY/.test(overviewGridQml), true);
assert.equal(/calculateRetileTarget\(workspace\.workspaceValue,\s*hotspot\.x,\s*hotspot\.y\)/.test(overviewGridQml), true);
assert.equal(/var\s+dragCenterX\s*=|var\s+dragCenterY\s*=|dragWidth\s*\/\s*2|dragHeight\s*\/\s*2/.test(overviewGridQml), false);
assert.equal(/property\s+real\s+dragSnapThreshold:\s*0\.42/.test(settingsQml), true);
assert.equal(/label:\s*tr\("settings\.behavior\.dragSnapThreshold\.label"\)[\s\S]*?from:\s*0\.42[\s\S]*?to:\s*0\.49/.test(settingsQml), true);
assert.equal(/property\s+var\s+previewModel/.test(retilePreviewQml), true);
assert.equal(/property\s+string\s+layerRole:\s*"base"/.test(retilePreviewQml), true);
assert.equal(/readonly\s+property\s+bool\s+isBaseLayer:\s*layerRole === "base"/.test(retilePreviewQml), true);
assert.equal(/readonly\s+property\s+bool\s+isForegroundLayer:\s*layerRole === "foreground"/.test(retilePreviewQml), true);
assert.equal(/readonly\s+property\s+real\s+swapBadgeHeight:[^\n]*(root\.swapBadgeTargetHeight|rectH\(root\.targetRect\))/.test(retilePreviewQml), true);
assert.equal(/height:\s*Math\.min\(root\.rectH\(root\.targetRect\)[\s\S]*actionText\.implicitHeight/.test(retilePreviewQml), false);
assert.equal(/font\.pixelSize:\s*Math\.[^\n]*swapBadge\.height/.test(retilePreviewQml), false);
assert.equal(/id:\s*foregroundTargetContour[\s\S]*?visible:\s*root\.visible && root\.isForegroundLayer/.test(retilePreviewQml), true);
assert.equal(/^    z:\s*99998\s*$/m.test(retilePreviewQml), false);
assert.equal(/id:\s*retilingPreviewBase[\s\S]*?anchors\.fill:\s*parent[\s\S]*?z:\s*root\.windowDraggingZ - 3[\s\S]*?layerRole:\s*"base"[\s\S]*?showPreview:\s*root\.retilingTarget !== null/.test(overviewGridQml), true);
assert.equal(/id:\s*retilingPreviewForeground[\s\S]*?anchors\.fill:\s*parent[\s\S]*?z:\s*root\.windowDraggingZ \+ 1[\s\S]*?layerRole:\s*"foreground"[\s\S]*?showPreview:\s*root\.retilingTarget !== null/.test(overviewGridQml), true);
assert.equal(/showPreview:\s*root\.retilingTarget !== null/.test(overviewGridQml), true);
assert.equal(/previewModel:\s*root\.retilingTarget\s*\?\s*root\.retilingTarget\.previewModel\s*:\s*null/.test(overviewGridQml), true);
assert.equal(/property\s+real\s+dragFeedbackOpacity:\s*1/.test(windowPreviewQml), true);
assert.equal(/opacity:\s*clamp\(\(monitorOpacityFactor \* workspaceOpacityFactor \* \(1 - unfocusedIdleOpacityCut\) \+ hoverOpacityBoost\) \* dragFeedbackOpacity,\s*0,\s*1\)/.test(windowPreviewQml), true);
assert.equal(/dragFeedbackOpacity:\s*\(windowDelegate\.isDragging && root\.retilingTarget !== null && !\(windowDelegate\.windowData && windowDelegate\.windowData\.floating\)\) \? 0\.42 : 1/.test(overviewGridQml), true);
assert.equal(/property\s+var\s+retileTransitionRecords:\s*\(\{\}\)/.test(overviewGridQml), true);
assert.equal(/readonly\s+property\s+bool\s+retileTransitionActive:\s*Object\.keys\(retileTransitionRecords \|\| \(\{\}\)\)\.length > 0/.test(overviewGridQml), true);
assert.equal(/property\s+var\s+retileFinalizedAddressMap:\s*\(\{\}\)/.test(overviewGridQml), true);
assert.equal(/property\s+int\s+retileFinalizedPositionRevision:\s*0/.test(overviewGridQml), true);
assert.equal(/function\s+buildRetileTransitionRecords\(sourceAddress,\s*retilingInfo,\s*releaseType\)[\s\S]*?RetileBlueprint\.buildTransitionRecords/.test(overviewGridQml), true);
assert.equal(/durationMs:\s*140/.test(overviewGridQml), true);
assert.equal(/settleTimeoutMs:\s*450/.test(overviewGridQml), true);
assert.equal(/function\s+reconcileRetileTransitionRecords\(\)[\s\S]*?RetileBlueprint\.reconcileTransitionRecords/.test(overviewGridQml), true);
assert.equal(/transitionResult\.retargeted[\s\S]*?scheduleRetileTransitionReconcile\(transitionResult\.nextWakeAt/.test(overviewGridQml), true);
assert.equal(/function\s+finishRetileTransitionRecords\(addresses,\s*reason\)[\s\S]*?clearRetileTransitionRecords\(\);[\s\S]*?markRetileFinalizedAddresses\(addresses,\s*reason\)/.test(overviewGridQml), true);
assert.equal(/requestSettledRetileOverlayRecapture\(reason \|\| "retile-settled",\s*root\.retileSettledRecaptureAddresses\.length > 0 \? root\.retileSettledRecaptureAddresses : addresses\)/.test(overviewGridQml), true);
assert.equal(/retileTransitionFrame:\s*root\.retileTransitionFrameForDelegate\(address,\s*effectiveWorkspaceValue\)/.test(overviewGridQml), true);
assert.equal(/retileTransitionActive:\s*root\.retileTransitionActive/.test(overviewGridQml), true);
assert.equal(/positionResyncRevision:\s*\(root\.retileFinalizedAddressMap && root\.retileFinalizedAddressMap\[address\]\) \? root\.retileFinalizedPositionRevision : 0/.test(overviewGridQml), true);
assert.equal(/onClientRefreshRevisionChanged:\s*reconcileRetileTransitionRecords\(\)/.test(overviewGridQml), true);
assert.equal(/id:\s*retileTransitionTimeout[\s\S]*?interval:\s*140[\s\S]*?onTriggered:\s*root\.reconcileRetileTransitionRecords\(\)/.test(overviewGridQml), true);
assert.equal(/id:\s*retileTransitionTimeout[\s\S]*?retileTransitionRecords\s*=\s*\(\{\}\)/.test(overviewGridQml), false);
assert.equal(/if\s*\(!needsRetileTransition\)\s*\{[\s\S]*?updateWindowPosition\.restart\(\);[\s\S]*?\}/.test(overviewGridQml), true);
assert.equal(/WlrLayershell\.namespace:\s*"noctalia-background-hypr-overview-" \+/.test(mainQml), true);
assert.equal(mainQml.includes('WlrLayershell.namespace: "noctalia:hypr-overview"'), false);
assert.equal(/WlrLayershell\.layer:\s*WlrLayer\.Top/.test(mainQml), true);
assert.equal(/WlrLayershell\.layer:\s*WlrLayer\.Overlay/.test(mainQml), false);
assert.equal(/BackgroundEffect\.blurRegion:\s*Settings\.data\.general\.enableBlurBehind \? overviewBlurRegion : null/.test(mainQml), true);
assert.equal(/color:\s*Qt\.alpha\(Color\.mShadow,\s*Settings\.data\.general\.dimmerOpacity/.test(mainQml), true);
assert.equal(/Rectangle\s*\{[\s\S]*?anchors\.fill:\s*parent[\s\S]*?color:\s*Qt\.alpha\(Color\.mShadow,\s*Settings\.data\.general\.dimmerOpacity/.test(mainQml), false);
assert.equal(/id:\s*overviewBlurRegion[\s\S]*?width:\s*root\.overviewOpen \? overlayWindow\.width : 0[\s\S]*?height:\s*root\.overviewOpen \? overlayWindow\.height : 0/.test(mainQml), true);
assert.equal(/Region\s*\{[\s\S]*?id:\s*overviewBlurRegion[\s\S]*?x:\s*Math\.round\(contentColumn\.x \+ overviewSurfaceX\)/.test(mainQml), true);
assert.equal(/readonly\s+property\s+real\s+surfacePadding:\s*Math\.max\(4,\s*root\.workspaceSpacing\)/.test(overviewGridQml), true);
assert.equal(/NDropShadow\s*\{[\s\S]*?source:\s*overviewSurface/.test(overviewGridQml), true);
assert.equal(/NDropShadow\s*\{[\s\S]*?anchors\.fill:\s*overviewBackground[\s\S]*?source:\s*overviewSurface/.test(overviewGridQml), true);
assert.equal(/NDropShadow\s*\{[\s\S]*?anchors\.fill:\s*overviewSurface/.test(overviewGridQml), false);
assert.equal(/id:\s*overviewSurface[\s\S]*?color:\s*Color\.mSurface[\s\S]*?opacity:\s*root\.clamp\(\(Color\.panelBackgroundOpacity \|\| Commons\.Settings\.data\.ui\.panelBackgroundOpacity \|\| 0\.8\) \* root\.backgroundOpacityRatio/.test(overviewGridQml), true);
assert.equal(/color:\s*Qt\.alpha\(Color\.mSurface,\s*root\.clamp/.test(overviewGridQml), false);
assert.equal(overviewGridQml.includes("gridNaturalWidth: (pluginMain ? pluginMain.gridColumns : 5) * workspaceImplicitWidth + ((pluginMain ? pluginMain.gridColumns : 5) - 1) * workspaceSpacing + 40"), false);
assert.equal(overviewGridQml.includes("overviewBackground.implicitWidth + 20"), false);
assert.equal(overviewGridQml.includes("anchors.margins: 10"), false);
assert.equal(/id:\s*titleStrip[\s\S]*?z:\s*1[\s\S]*?anchors\.leftMargin:\s*root\.drawnBorderWidth/.test(windowPreviewQml), true);
assert.equal(/id:\s*windowBorderOverlay[\s\S]*?z:\s*2/.test(windowPreviewQml), true);
assert.equal(/property\s+var\s+retileTransitionFrame:\s*null/.test(windowPreviewQml), true);
assert.equal(/property\s+bool\s+retileTransitionActive:\s*false/.test(windowPreviewQml), true);
assert.equal(/readonly\s+property\s+var\s+displayGeometryModel:[\s\S]*?var frame = retileTransitionFrame[\s\S]*?next\.x = Number\(frame\.x\)[\s\S]*?next\.h = Math\.max\(1,\s*Number\(frame\.h\)\)/.test(windowPreviewQml), true);
assert.equal(/readonly\s+property\s+real\s+contentWidth:\s*\(displayGeometryModel && displayGeometryModel\.w\) \|\| 1/.test(windowPreviewQml), true);
assert.equal(/property\s+real\s+initX:\s*\(\(displayGeometryModel && displayGeometryModel\.x\) \|\| workspaceInset\) \+ xOffset/.test(windowPreviewQml), true);
assert.equal(/var\s+displayWorkspaceValue\s*=\s*resolvedWorkspaceId\s*<\s*0\s*\?\s*root\.getEffectiveWorkspaceValueForWindow\(delegateItem\.rawWindowData\s*\|\|\s*delegateItem\.windowData\)\s*:\s*resolvedWorkspaceId/.test(overviewGridQml), true);
assert.equal(/var\s+workspaceOffsets\s*=\s*root\.getWorkspaceOffsets\(displayWorkspaceValue\)/.test(overviewGridQml), true);
assert.equal(/directionConfidence|pendingDirection|directionLocked|statusTextOverride|intentType/.test(retilePreviewQml), false);
assert.equal(/Split Left|Split Right|Split Top|Split Bottom|Swap windows|Native Reorder|Move Workspace|Move and Place|Unsupported/.test(retilePreviewQml), false);
assert.equal(/labelKey\.replace/.test(overviewGridQml), false);

const pluginApi = {
  pluginSettings: {
    previewMode: "event",
    visualMode: "simplified",
    useSimplifiedPreview: true,
    shaderPreset: "mac",
    showMonitorBadge: true,
    dragSnapThreshold: 0.33,
  },
  manifest: { metadata: { defaultSettings: { enableCrossMonitorDrag: true } } }
};
const normalized = settings.normalizeSettings(pluginApi);
assert.equal(normalized.visualMode, "simplified");
assert.equal(normalized.shaderPreset, "mac");
assert.equal(normalized.useSimplifiedPreview, true);
assert.equal(Object.hasOwn(normalized, "previewMode"), false);
assert.equal(normalized.showMonitorIndicators, true);
assert.equal(normalized.enableCrossMonitorDrag, true);
assert.equal(normalized.dragSnapThreshold, 0.42);

const highSplitBiasApi = {
  pluginSettings: { dragSnapThreshold: 0.47 },
  manifest: { metadata: { defaultSettings: {} } },
};
assert.equal(settings.normalizeSettings(highSplitBiasApi).dragSnapThreshold, 0.47);

assert.equal(settings.removeObsoleteSettings(pluginApi), true);
assert.equal(pluginApi.pluginSettings.visualMode, "simplified");
assert.equal(Object.hasOwn(pluginApi.pluginSettings, "previewMode"), false);
assert.equal(Object.hasOwn(pluginApi.pluginSettings, "useSimplifiedPreview"), false);
assert.equal(pluginApi.pluginSettings.shaderPreset, "mac");
assert.equal(settings.removeObsoleteSettings(pluginApi), false);

const legacyPreviewApi = {
  pluginSettings: { previewMode: "event", useSimplifiedPreview: true },
  manifest: { metadata: { defaultSettings: {} } },
};
assert.equal(settings.removeObsoleteSettings(legacyPreviewApi), true);
assert.equal(legacyPreviewApi.pluginSettings.visualMode, "simplified");
assert.equal(Object.hasOwn(legacyPreviewApi.pluginSettings, "previewMode"), false);
assert.equal(Object.hasOwn(legacyPreviewApi.pluginSettings, "useSimplifiedPreview"), false);

const savedSettings = settings.buildPersistedSettings({
  rows: 3,
  columns: 4,
  showMonitorIndicators: true,
  enableCrossMonitorDrag: false,
  visualMode: "simplified",
  shaderPreset: "mac",
  simplifiedPixelDensity: 0.4,
  enableGlassMode: true,
});
assert.equal(savedSettings.rows, 3);
assert.equal(savedSettings.columns, 4);
assert.equal(savedSettings.showMonitorIndicators, true);
assert.equal(savedSettings.enableCrossMonitorDrag, false);
assert.equal(savedSettings.visualMode, "simplified");
assert.equal(savedSettings.shaderPreset, "mac");
assert.equal(savedSettings.simplifiedPixelDensity, 0.4);
assert.equal(Object.hasOwn(savedSettings, "enableGlassMode"), false);

const bindings = state.buildWorkspaceMonitorBindings(
  [{ address: "0x1", workspace: { id: 1 }, monitor: 0 }],
  [{ id: 2, monitorID: 1 }]
);
assert.equal(JSON.stringify(bindings[1]), JSON.stringify([0]));
assert.equal(JSON.stringify(bindings[2]), JSON.stringify([1]));

const specials = state.collectSpecialWorkspaces(
  [{ id: -99, name: "special:music" }],
  { "0x2": { address: "0x2", workspace: { id: -99, name: "special:music" } } },
  true
);
assert.equal(specials[0].name, "music");
assert.equal(specials[0].windows.length, 1);

const ordered = state.sortWindowRecords([
  { win: { address: "old", focusHistoryID: 9 } },
  { win: { address: "focused", focusHistoryID: 0 } }
]);
assert.equal(ordered[0].win.address, "old");
assert.equal(ordered[1].win.address, "focused");

const floatingDrop = mapping.resolveFloatingDropPosition({
  frameX: 95,
  frameY: 95,
  frameWidth: 20,
  frameHeight: 20,
  workspaceWidth: 100,
  workspaceHeight: 100,
  inset: 0,
  positionScaleX: 0.1,
  positionScaleY: 0.1,
  monitorX: 0,
  monitorY: 0,
  monitorLogicalWidth: 1000,
  monitorLogicalHeight: 1000,
  windowWidthRaw: 300,
  windowHeightRaw: 300,
  workspaceId: 1,
  monitorId: 0,
  draggedAddress: "0x1",
  windowByAddress: {}
});
assert.equal(JSON.stringify(floatingDrop), JSON.stringify({ x: 700, y: 700 }));

const unsnappedFloatingDrop = mapping.resolveFloatingDropPosition({
  frameX: 49,
  frameY: 49,
  frameWidth: 20,
  frameHeight: 20,
  workspaceWidth: 100,
  workspaceHeight: 100,
  inset: 0,
  positionScaleX: 0.1,
  positionScaleY: 0.1,
  monitorX: 0,
  monitorY: 0,
  monitorLogicalWidth: 1000,
  monitorLogicalHeight: 1000,
  windowWidthRaw: 300,
  windowHeightRaw: 300,
  workspaceId: 1,
  monitorId: 0,
  draggedAddress: "0x1",
  windowByAddress: {
    "0x2": {
      address: "0x2",
      workspace: { id: 1 },
      monitor: 0,
      floating: true,
      at: [500, 500],
      size: [300, 300],
    },
  },
  snapBasePx: 42,
  snapRatio: 0.1,
  minStepPx: 28,
  maxOffsetSteps: 6,
});
assert.equal(JSON.stringify(unsnappedFloatingDrop), JSON.stringify({ x: 490, y: 490 }));
assert.equal(/snapBasePx|snapRatio|minStepPx|maxOffsetSteps|overlapThresholdRatio/.test(overviewGridQml), false);

const dp2Monitor = {
  name: "DP-2",
  x: 0,
  y: 0,
  width: 3840,
  height: 2160,
  scale: 2,
  transform: 0,
  reserved: [0, 0, 0, 30],
};
const dp2WorkArea = geometry.getMonitorWorkArea(dp2Monitor);
assert.equal(JSON.stringify(dp2WorkArea), JSON.stringify({ x: 0, y: 0, width: 1920, height: 1050 }));
const dp2WindowFrame = geometry.mapWindowToPreviewFrame({
  windowData: { at: [12, 12], size: [1896, 501], fullscreen: false, maximized: false },
  monitorData: dp2Monitor,
  workspaceWidth: 960,
  workspaceHeight: 525,
  workAreaX: dp2WorkArea.x,
  workAreaY: dp2WorkArea.y,
  workAreaWidth: dp2WorkArea.width,
  workAreaHeight: dp2WorkArea.height,
  positionScaleX: 0.5,
  positionScaleY: 0.5,
  windowScale: 0.5,
  fallbackInset: 1,
  hyprGapsIn: 0,
  hyprBorderSize: 0,
  forceTreatedAsFullscreen: false,
});
assert.equal(dp2WindowFrame.logicalMonitorHeight, 1050);
nearlyEqual(dp2WindowFrame.frameTargetY, 6.977142857142857);
nearlyEqual(dp2WindowFrame.h, 249.5457142857143);
nearlyEqual(dp2WindowFrame.frameMaxY, 274.4542857142857);
const dp2BottomWindowFrame = geometry.mapWindowToPreviewFrame({
  windowData: { at: [12, 537], size: [1896, 501], fullscreen: false, maximized: false },
  monitorData: dp2Monitor,
  workspaceWidth: 960,
  workspaceHeight: 525,
  workAreaX: dp2WorkArea.x,
  workAreaY: dp2WorkArea.y,
  workAreaWidth: dp2WorkArea.width,
  workAreaHeight: dp2WorkArea.height,
  positionScaleX: 0.5,
  positionScaleY: 0.5,
  windowScale: 0.5,
  fallbackInset: 1,
  hyprGapsIn: 0,
  hyprBorderSize: 0,
  forceTreatedAsFullscreen: false,
});
nearlyEqual(dp2BottomWindowFrame.frameTargetY, 268.47714285714284);
nearlyEqual(dp2BottomWindowFrame.y, 268.47714285714284);

const dp2ReservedMonitor = {
  name: "DP-2",
  x: 0,
  y: 0,
  width: 3840,
  height: 2160,
  scale: 2,
  transform: 0,
  reserved: [0, 164, 0, 30],
};
const dp2ReservedWorkArea = geometry.getMonitorWorkArea(dp2ReservedMonitor);
assert.equal(JSON.stringify(dp2ReservedWorkArea), JSON.stringify({ x: 0, y: 164, width: 1920, height: 886 }));
const dp2ReservedFullWidthFrame = geometry.mapWindowToPreviewFrame({
  windowData: { at: [12, 164], size: [1896, 886], fullscreen: false, maximized: false },
  monitorData: dp2ReservedMonitor,
  workspaceWidth: 307.2,
  workspaceHeight: 141.76,
  workAreaX: dp2ReservedWorkArea.x,
  workAreaY: dp2ReservedWorkArea.y,
  workAreaWidth: dp2ReservedWorkArea.width,
  workAreaHeight: dp2ReservedWorkArea.height,
  positionScaleX: 0.16,
  positionScaleY: 0.16,
  windowScale: 0.16,
  fallbackInset: 1,
  hyprGapsIn: 0,
  hyprBorderSize: 0,
  forceTreatedAsFullscreen: false,
});
const dp2ReservedLeftGap = dp2ReservedFullWidthFrame.x;
const dp2ReservedRightGap = dp2ReservedFullWidthFrame.workspaceWidth - dp2ReservedFullWidthFrame.x - dp2ReservedFullWidthFrame.w;
nearlyEqual(dp2ReservedLeftGap, dp2ReservedRightGap);

assert.equal(
  JSON.stringify(drag.decideRelease({ windowAddress: "0x1", currentWorkspaceId: 1, targetWorkspace: 2 }).commands),
  JSON.stringify(["movetoworkspacesilent 2, address:0x1"])
);
assert.equal(
  drag.decideRelease({ windowAddress: "0x1", currentWorkspaceId: -99, currentSpecialName: "music", targetSpecial: { name: "music" } }).type,
  "reset"
);
const sameSpecialFloatingIntent = intent.resolve({
  windowAddress: "0x1",
  currentWorkspaceId: -99,
  currentSpecialName: "music",
  targetSpecial: { name: "music" },
  isFloating: true,
  floatingDropPosition: { x: 240, y: 360 },
});
assert.equal(sameSpecialFloatingIntent.type, "floatingPlace");
assert.equal(sameSpecialFloatingIntent.status, "ready");
const sameSpecialFloatingDecision = drag.decideRelease({
  intent: sameSpecialFloatingIntent,
  floatingDropPosition: { x: 240, y: 360 },
});
assert.equal(sameSpecialFloatingDecision.type, "floatingMove");
assert.equal(
  JSON.stringify(sameSpecialFloatingDecision.commands),
  JSON.stringify(["movewindowpixel exact 240 360,address:0x1"])
);
assert.equal(sameSpecialFloatingDecision.optimisticMove.workspaceId, -99);
assert.equal(
  intent.resolve({
    windowAddress: "0x1",
    currentWorkspaceId: 1,
    targetSpecial: { name: "music" },
    isFloating: true,
    floatingDropPosition: { x: 240, y: 360 },
  }).type,
  "specialMove"
);
assert.equal(
  drag.decideRelease({ windowAddress: "0x1", currentWorkspaceId: 1, targetWorkspace: 2, isFloating: true }).type,
  "workspaceMove"
);
assert.equal(
  drag.decideRelease({ windowAddress: "0x1", currentWorkspaceId: 1, targetWorkspace: 2, sourceMonitorId: 0, targetMonitorId: 1, enableCrossMonitorDrag: false }).type,
  "reset"
);
assert.equal(
  drag.decideRelease({ windowAddress: "0x1", currentWorkspaceId: 1, targetWorkspace: 2, sourceMonitorId: 0, targetMonitorId: -1, enableCrossMonitorDrag: true, crossMonitorDrag: true }).type,
  "reset"
);
assert.equal(
  drag.decideRelease({ windowAddress: "0x1", currentWorkspaceId: 1, targetWorkspace: 2, sourceMonitorId: 0, targetMonitorId: 1, enableCrossMonitorDrag: true }).type,
  "workspaceMove"
);

const dwindleAction = layout.get("dwindle").getDropAction({
  sourceAddress: "0x1",
  wsId: 1,
  retilingInfo: { targetAddress: "0x2", direction: "l", isNoop: false }
});
assert.equal(JSON.stringify(dwindleAction.commands), JSON.stringify([
  "movetoworkspacesilent 9999, address:0x1",
  "focuswindow address:0x2",
  "layoutmsg preselect l",
  "movetoworkspacesilent 1, address:0x1",
  "layoutmsg preselect 0",
]));
assert.equal(layout.get("dwindle").getDropAction({ sourceAddress: "0x1", wsId: 1, retilingInfo: { isNoop: true } }).type, "noop");
assert.equal(layout.get("master").getDropAction({ sourceAddress: "0x1", wsId: 1, retilingInfo: { targetAddress: "0x2" } }).commands[1], "swapwindow address:0x2");
assert.equal(layout.get("scroll").getDropAction({ sourceAddress: "0x1", dragDeltaX: 10, scrollDirection: "right" }).commands[1], "layoutmsg movewindow r");
assert.equal(layout.get("monocle").getDropAction({ sourceAddress: "0x1", dragDeltaY: -10 }).commands[1], "cyclenext");

assert.equal(retileBlueprint.resolveZone({ x: 50, y: 50, width: 100, height: 100, edgeRatio: 0.25 }).direction, "swap");
assert.equal(retileBlueprint.resolveZone({ x: 5, y: 18, width: 100, height: 100, edgeRatio: 0.25, deadzonePx: 4 }).direction, "l");
assert.equal(retileBlueprint.resolveZone({ x: 18, y: 5, width: 100, height: 100, edgeRatio: 0.25, deadzonePx: 4 }).direction, "u");
assert.equal(retileBlueprint.resolveZone({ x: 95, y: 82, width: 100, height: 100, edgeRatio: 0.25, deadzonePx: 4 }).direction, "r");
assert.equal(retileBlueprint.resolveZone({ x: 82, y: 95, width: 100, height: 100, edgeRatio: 0.25, deadzonePx: 4 }).direction, "d");
assert.equal(retileBlueprint.resolveZone({ x: 5, y: 50, width: 100, height: 100, edgeRatio: 0.25 }).confidence, 1);
assert.equal(retileBlueprint.resolveZone({ x: 24, y: 50, width: 100, height: 100, edgeRatio: 0.25, minEdgePx: 0, deadzonePx: 4 }).confidence < 1, true);
assert.equal(retileBlueprint.resolveZone({ x: 5, y: 5, width: 100, height: 100, edgeRatio: 0.25, deadzonePx: 4 }).confidence, 0);
assert.equal(retileBlueprint.resolveZone({ x: 35, y: 50, width: 100, height: 100, edgeRatio: 0.33, minSplitRatio: 0.42 }).direction, "l");
assert.equal(retileBlueprint.resolveZone({ x: 65, y: 50, width: 100, height: 100, edgeRatio: 0.33, minSplitRatio: 0.42 }).direction, "r");
assert.equal(retileBlueprint.resolveZone({ x: 50, y: 35, width: 100, height: 100, edgeRatio: 0.33, minSplitRatio: 0.42 }).direction, "u");
assert.equal(retileBlueprint.resolveZone({ x: 50, y: 65, width: 100, height: 100, edgeRatio: 0.33, minSplitRatio: 0.42 }).direction, "d");
assert.equal(retileBlueprint.resolveZone({ x: 50, y: 50, width: 100, height: 100, edgeRatio: 0.33, minSplitRatio: 0.42 }).direction, "swap");
assert.deepEqual(
  [
    retileBlueprint.resolveZone({ x: 5, y: 50, width: 100, height: 100, edgeRatio: 0.25 }).direction,
    retileBlueprint.resolveZone({ x: 50, y: 50, width: 100, height: 100, edgeRatio: 0.25, previousDirection: "l" }).direction,
    retileBlueprint.resolveZone({ x: 95, y: 50, width: 100, height: 100, edgeRatio: 0.25, previousDirection: "swap" }).direction,
    retileBlueprint.resolveZone({ x: 50, y: 5, width: 100, height: 100, edgeRatio: 0.25, previousDirection: "r" }).direction,
  ],
  ["l", "swap", "r", "u"]
);
assert.equal(retileBlueprint.resolveZone({ x: 5, y: 5, width: 100, height: 100, edgeRatio: 0.25, deadzonePx: 4, previousDirection: "u" }).direction, "u");
assert.equal(retileBlueprint.resolveZone({ x: 5, y: 5, width: 100, height: 100, edgeRatio: 0.25, deadzonePx: 4, previousDirection: "l" }).direction, "l");
assert.equal(retileBlueprint.resolveZone({ x: 5, y: 6, width: 100, height: 100, edgeRatio: 0.25, deadzonePx: 4, previousDirection: "u" }).direction, "l");
assert.equal(retileBlueprint.zoneForPoint({ x: 50, y: 50, width: 100, height: 100, edgeRatio: 0.25 }), "swap");
assert.equal(retileBlueprint.zoneForPoint({ x: 5, y: 50, width: 100, height: 100, edgeRatio: 0.25 }), "l");
assert.equal(retileBlueprint.zoneForPoint({ x: 95, y: 50, width: 100, height: 100, edgeRatio: 0.25 }), "r");
assert.equal(retileBlueprint.zoneForPoint({ x: 50, y: 5, width: 100, height: 100, edgeRatio: 0.25 }), "u");
assert.equal(retileBlueprint.zoneForPoint({ x: 50, y: 95, width: 100, height: 100, edgeRatio: 0.25 }), "d");

const blueprintModel = retileBlueprint.buildPreviewModel(
  { targetAddress: "0x2", targetX: 10, targetY: 20, targetW: 200, targetH: 100 },
  "l",
  { l: "Left label", draggedSlot: "Dragged slot", targetSlot: "Target slot" }
);
assert.equal(blueprintModel.mode, "split");
assert.equal(blueprintModel.draggedResultRect.w, 100);
assert.equal(blueprintModel.targetResultRect.x, 110);
assert.equal(blueprintModel.label, "Left label");
assert.equal(retileBlueprint.buildPreviewModel({ targetAddress: "0x2", targetX: 10, targetY: 20, targetW: 200, targetH: 100 }, "swap", { swap: "Swap label" }).mode, "swap");
assert.equal(retileBlueprint.sameCandidate({ targetAddress: "0x2", direction: "l" }, { targetAddress: "0x2", direction: "l" }), true);
assert.equal(retileBlueprint.sameCandidate({ targetAddress: "0x2", direction: "l" }, { targetAddress: "0x3", direction: "l" }), false);

const splitTransitions = retileBlueprint.buildTransitionRecords({
  sourceAddress: "0x1",
  releaseType: "tiledSplit",
  durationMs: 140,
  nowMs: 1000,
  retilingInfo: {
    targetAddress: "0x2",
    draggedCurrentRect: { x: 0, y: 0, w: 100, h: 100 },
    previewModel: {
      targetRect: { x: 100, y: 0, w: 100, h: 100 },
      draggedResultRect: { x: 100, y: 0, w: 50, h: 100 },
      targetResultRect: { x: 150, y: 0, w: 50, h: 100 },
    },
  },
});
assert.equal(splitTransitions["0x1"].role, "dragged");
assert.equal(JSON.stringify(splitTransitions["0x1"].fromFrame), JSON.stringify({ x: 0, y: 0, w: 100, h: 100 }));
assert.equal(JSON.stringify(splitTransitions["0x1"].toFrame), JSON.stringify({ x: 100, y: 0, w: 50, h: 100 }));
assert.equal(splitTransitions["0x1"].durationMs, 140);
assert.equal(splitTransitions["0x1"].settleDeadlineMs, 1450);
assert.equal(splitTransitions["0x2"].role, "target");
assert.equal(JSON.stringify(splitTransitions["0x2"].fromFrame), JSON.stringify({ x: 100, y: 0, w: 100, h: 100 }));
assert.equal(JSON.stringify(splitTransitions["0x2"].toFrame), JSON.stringify({ x: 150, y: 0, w: 50, h: 100 }));

const swapTransitions = retileBlueprint.buildTransitionRecords({
  sourceAddress: "0x1",
  releaseType: "tiledSwap",
  durationMs: 140,
  nowMs: 1200,
  retilingInfo: {
    targetAddress: "0x2",
    draggedCurrentRect: { x: 0, y: 0, w: 100, h: 100 },
    previewModel: {
      targetRect: { x: 100, y: 0, w: 100, h: 100 },
    },
  },
});
assert.equal(JSON.stringify(swapTransitions["0x1"].toFrame), JSON.stringify({ x: 100, y: 0, w: 100, h: 100 }));
assert.equal(JSON.stringify(swapTransitions["0x2"].toFrame), JSON.stringify({ x: 0, y: 0, w: 100, h: 100 }));

const matchedTransitionPending = retileBlueprint.reconcileTransitionRecords({
  records: splitTransitions,
  actualFrames: {
    "0x1": { x: 100, y: 0, w: 50, h: 100 },
    "0x2": { x: 150, y: 0, w: 50, h: 100 },
  },
  epsilonPx: 2,
  nowMs: 1080,
});
assert.equal(Object.keys(matchedTransitionPending.records).length, 2);
assert.equal(matchedTransitionPending.statuses["0x1"], "pendingPrediction");

const matchedTransition = retileBlueprint.reconcileTransitionRecords({
  records: splitTransitions,
  actualFrames: {
    "0x1": { x: 100, y: 0, w: 50, h: 100 },
    "0x2": { x: 150, y: 0, w: 50, h: 100 },
  },
  epsilonPx: 2,
  nowMs: 1140,
});
assert.equal(Object.keys(matchedTransition.records).length, 0);
assert.equal(matchedTransition.cleared, true);
assert.equal(matchedTransition.statuses["0x1"], "matchedPrediction");

const unchangedTransition = retileBlueprint.reconcileTransitionRecords({
  records: splitTransitions,
  actualFrames: {
    "0x1": { x: 0, y: 0, w: 100, h: 100 },
    "0x2": { x: 100, y: 0, w: 100, h: 100 },
  },
  epsilonPx: 2,
  nowMs: 1080,
});
assert.equal(Object.keys(unchangedTransition.records).length, 2);
assert.equal(unchangedTransition.retargeted, false);
assert.equal(unchangedTransition.statuses["0x1"], "pendingPrevious");

const unchangedCapTransition = retileBlueprint.reconcileTransitionRecords({
  records: splitTransitions,
  actualFrames: {
    "0x1": { x: 0, y: 0, w: 100, h: 100 },
    "0x2": { x: 100, y: 0, w: 100, h: 100 },
  },
  epsilonPx: 2,
  nowMs: 1450,
});
assert.equal(unchangedCapTransition.cleared, true);
assert.equal(unchangedCapTransition.statuses["0x1"], "capExpiredUnchanged");

const retargetedTransition = retileBlueprint.reconcileTransitionRecords({
  records: splitTransitions,
  actualFrames: {
    "0x1": { x: 92, y: 0, w: 60, h: 100 },
    "0x2": { x: 152, y: 0, w: 48, h: 100 },
  },
  epsilonPx: 2,
  nowMs: 1080,
});
assert.equal(retargetedTransition.retargeted, true);
assert.equal(JSON.stringify(retargetedTransition.records["0x1"].toFrame), JSON.stringify({ x: 92, y: 0, w: 60, h: 100 }));
assert.equal(retargetedTransition.records["0x1"].startedAt, 1080);

const retargetedSettledTransition = retileBlueprint.reconcileTransitionRecords({
  records: retargetedTransition.records,
  actualFrames: {
    "0x1": { x: 92, y: 0, w: 60, h: 100 },
    "0x2": { x: 152, y: 0, w: 48, h: 100 },
  },
  epsilonPx: 2,
  nowMs: 1220,
});
assert.equal(retargetedSettledTransition.cleared, true);
assert.equal(retargetedSettledTransition.statuses["0x1"], "matchedActual");

const unevenFinalTransition = retileBlueprint.reconcileTransitionRecords({
  records: splitTransitions,
  actualFrames: {
    "0x1": { x: 100, y: 0, w: 63, h: 100 },
    "0x2": { x: 163, y: 0, w: 37, h: 100 },
  },
  epsilonPx: 2,
  nowMs: 1160,
});
assert.equal(unevenFinalTransition.retargeted, true);
assert.equal(JSON.stringify(unevenFinalTransition.records["0x1"].toFrame), JSON.stringify({ x: 100, y: 0, w: 63, h: 100 }));

function windowRecord(address, workspaceId, rect, extra = {}) {
  return {
    address,
    workspaceId,
    rect,
    floating: false,
    fullscreen: false,
    maximized: false,
    ...extra,
  };
}

function resolveRetile(overrides = {}) {
  return retileBlueprint.resolveTarget({
    workspaceId: 1,
    hotspotX: 0,
    hotspotY: 0,
    workspaceOffset: { x: 10, y: 20 },
    draggedAddress: "0x1",
    windows: [
      windowRecord("0x1", 1, { x: 0, y: 0, w: 100, h: 100 }),
      windowRecord("0x2", 1, { x: 100, y: 0, w: 100, h: 100 }),
    ],
    edgeRatio: 0.25,
    minSplitRatio: 0.25,
    minEdgePx: 0,
    deadzonePx: 4,
    noopGeometryEpsilonPx: 2,
    labels: { l: "Left label", swap: "Swap label", draggedSlot: "Dragged", targetSlot: "Target" },
    ...overrides,
  });
}

const horizontalSwap = resolveRetile({ hotspotX: 160, hotspotY: 70 });
assert.equal(horizontalSwap.targetAddress, "0x2");
assert.equal(horizontalSwap.direction, "swap");
assert.equal(horizontalSwap.operationType, "swap");
assert.equal(horizontalSwap.targetX, 110);
assert.equal(horizontalSwap.targetY, 20);
assert.equal(horizontalSwap.previewModel.mode, "swap");
assert.equal(horizontalSwap.previewModel.label, "Swap label");

for (const [direction, hotspotX, hotspotY] of [
  ["l", 112, 70],
  ["r", 208, 70],
  ["u", 160, 22],
  ["d", 160, 118],
]) {
  const candidate = resolveRetile({
    hotspotX,
    hotspotY,
    windows: [
      windowRecord("0x1", 1, { x: 0, y: 120, w: 100, h: 100 }),
      windowRecord("0x2", 1, { x: 100, y: 0, w: 100, h: 100 }),
    ],
  });
  assert.equal(candidate.targetAddress, "0x2");
  assert.equal(candidate.direction, direction);
  assert.equal(candidate.operationType, "split");
  assert.equal(candidate.previewModel.mode, "split");
  assert.equal(candidate.isNoop, false);
}

assert.deepEqual(
  [
    resolveRetile({ hotspotX: 112, hotspotY: 70 }).direction,
    resolveRetile({ hotspotX: 160, hotspotY: 70, previousDirection: "l" }).direction,
    resolveRetile({ hotspotX: 208, hotspotY: 70, previousDirection: "swap" }).direction,
  ],
  ["l", "swap", "r"]
);

const verticalTarget = resolveRetile({
  windows: [
    windowRecord("0x1", 1, { x: 0, y: 0, w: 100, h: 100 }),
    windowRecord("0x2", 1, { x: 0, y: 100, w: 100, h: 100 }),
  ],
  hotspotX: 60,
  hotspotY: 122,
});
assert.equal(verticalTarget.targetAddress, "0x2");
assert.equal(verticalTarget.direction, "u");

const asymmetricMove = resolveRetile({
  windows: [
    windowRecord("0x1", 1, { x: 0, y: 0, w: 120, h: 200 }),
    windowRecord("0x2", 1, { x: 120, y: 0, w: 220, h: 100 }),
    windowRecord("0x3", 1, { x: 120, y: 100, w: 80, h: 100 }),
    windowRecord("0x4", 1, { x: 200, y: 100, w: 140, h: 100 }),
  ],
  hotspotX: 145,
  hotspotY: 145,
});
assert.equal(asymmetricMove.targetAddress, "0x3");
assert.equal(asymmetricMove.direction, "l");

const invalidFiltered = resolveRetile({
  windows: [
    windowRecord("0x1", 1, { x: 0, y: 0, w: 100, h: 100 }),
    windowRecord("0x2", 1, { x: 100, y: 0, w: 100, h: 100 }, { floating: true }),
    windowRecord("0x3", 1, { x: 100, y: 0, w: 100, h: 100 }, { fullscreen: true }),
    windowRecord("0x4", 1, { x: 100, y: 0, w: 100, h: 100 }, { maximized: true }),
    windowRecord("0x5", 2, { x: 100, y: 0, w: 100, h: 100 }),
    windowRecord("0x6", 1, null),
  ],
  hotspotX: 160,
  hotspotY: 70,
});
assert.equal(invalidFiltered, null);
assert.equal(resolveRetile({ windows: [], hotspotX: 160, hotspotY: 70 }), null);
assert.equal(resolveRetile({ draggedWindow: { fullscreen: true }, hotspotX: 160, hotspotY: 70 }), null);

const adjacentNoop = resolveRetile({
  hotspotX: 112,
  hotspotY: 70,
  windows: [
    windowRecord("0x1", 1, { x: 0, y: 0, w: 100, h: 100 }),
    windowRecord("0x2", 1, { x: 100, y: 0, w: 100, h: 100 }),
  ],
});
assert.equal(adjacentNoop.isNoop, true);
assert.equal(adjacentNoop.noopReason, "split-already-matches");

const identicalPredictionNoop = resolveRetile({
  hotspotX: 112,
  hotspotY: 70,
  windows: [
    windowRecord("0x1", 1, { x: 100, y: 0, w: 50, h: 100 }),
    windowRecord("0x2", 1, { x: 100, y: 0, w: 100, h: 100 }),
  ],
});
assert.equal(identicalPredictionNoop.isNoop, true);
assert.equal(identicalPredictionNoop.noopReason, "predicted-geometry-matches");

const boundaryWindowsA = [
  windowRecord("0xsource", 1, { x: 0, y: 0, w: 50, h: 50 }),
  windowRecord("0xlarge", 1, { x: 100, y: 0, w: 100, h: 100 }),
  windowRecord("0xsmall", 1, { x: 100, y: 0, w: 50, h: 100 }),
];
const boundaryWindowsB = [boundaryWindowsA[0], boundaryWindowsA[2], boundaryWindowsA[1]];
assert.equal(resolveRetile({ draggedAddress: "0xsource", windows: boundaryWindowsA, hotspotX: 110, hotspotY: 70 }).targetAddress, "0xsmall");
assert.equal(resolveRetile({ draggedAddress: "0xsource", windows: boundaryWindowsB, hotspotX: 110, hotspotY: 70 }).targetAddress, "0xsmall");

const addressTie = [
  windowRecord("0xsource", 1, { x: 0, y: 0, w: 50, h: 50 }),
  windowRecord("0xb", 1, { x: 100, y: 0, w: 100, h: 100 }),
  windowRecord("0xa", 1, { x: 100, y: 0, w: 100, h: 100 }),
];
assert.equal(resolveRetile({ draggedAddress: "0xsource", windows: addressTie, hotspotX: 160, hotspotY: 70 }).targetAddress, "0xa");
assert.equal(resolveRetile({ hotspotX: 110, hotspotY: 30, previousDirection: "u" }).direction, "l");
assert.equal(resolveRetile({ hotspotX: 110, hotspotY: 20, previousDirection: "u" }).direction, "u");
assert.equal(/dragMode === "basic"[\s\S]*?root\.retilingTarget = candidate[\s\S]*?return;/.test(overviewGridQml), true);
assert.equal(/function\s+updateRetileCandidate\(candidate\)[\s\S]*?!candidate \|\| candidate\.direction === "" \|\| candidate\.isNoop[\s\S]*?root\.retilingTarget = null[\s\S]*?commitRetileCandidate\(candidate\);/.test(overviewGridQml), true);

const splitIntent = intent.resolve({
  windowAddress: "0x1",
  currentWorkspaceId: 1,
  targetWorkspace: 1,
  layoutName: "dwindle",
  retilingInfo: { targetAddress: "0x2", direction: "l", isNoop: false, confidence: 0.9 },
});
assert.equal(splitIntent.type, "tiledSplit");
assert.equal(splitIntent.labelKey, "dropIntent.tiledSplit");
assert.equal(layout.get("dwindle").getDropAction(splitIntent).commands.includes("layoutmsg preselect l"), true);

const splitDirections = ["l", "r", "u", "d"];
for (const direction of splitDirections) {
  const edgeIntent = intent.resolve({
    windowAddress: "0x1",
    currentWorkspaceId: 1,
    targetWorkspace: 1,
    layoutName: "dwindle",
    retilingInfo: { targetAddress: "0x2", direction, isNoop: false },
  });
  assert.equal(edgeIntent.type, "tiledSplit");
  assert.equal(JSON.stringify(layout.get("dwindle").getDropAction(edgeIntent).commands), JSON.stringify([
    "movetoworkspacesilent 9999, address:0x1",
    "focuswindow address:0x2",
    `layoutmsg preselect ${direction}`,
    "movetoworkspacesilent 1, address:0x1",
    "layoutmsg preselect 0",
  ]));
}

const swapIntent = intent.resolve({
  windowAddress: "0x1",
  currentWorkspaceId: 1,
  targetWorkspace: 1,
  layoutName: "dwindle",
  retilingInfo: { targetAddress: "0x2", direction: "swap", isNoop: false, confidence: 0.8 },
});
assert.equal(swapIntent.type, "tiledSwap");
assert.equal(layout.get("dwindle").getDropAction(swapIntent).commands[1], "swapwindow address:0x2");

const noTargetIntent = intent.resolve({
  windowAddress: "0x1",
  currentWorkspaceId: 1,
  targetWorkspace: 1,
  layoutName: "dwindle",
});
assert.equal(noTargetIntent.type, "noop");
assert.equal(drag.decideRelease({ intent: noTargetIntent }).commands.length, 0);

assert.equal(
  intent.resolve({
    windowAddress: "0x1",
    currentWorkspaceId: 1,
    targetWorkspace: 1,
    layoutName: "dwindle",
    retilingInfo: { targetAddress: "0x2", direction: "l", isNoop: true, noopReason: "split-already-matches" },
  }).type,
  "noop"
);

const masterIntent = intent.resolve({
  windowAddress: "0x1",
  currentWorkspaceId: 1,
  targetWorkspace: 1,
  layoutName: "master",
  dragDeltaX: 12,
});
assert.equal(masterIntent.type, "layoutReorder");
assert.equal(layout.get("master").getDropAction(masterIntent).commands[1], "layoutmsg swapwithmaster");

const scrollIntent = intent.resolve({
  windowAddress: "0x1",
  currentWorkspaceId: 1,
  targetWorkspace: 1,
  layoutName: "scroll",
  scrollDirection: "right",
  dragDeltaX: 12,
});
assert.equal(scrollIntent.type, "layoutReorder");
assert.equal(layout.get("scroll").getDropAction(scrollIntent).commands[1], "layoutmsg movewindow r");

const monocleIntent = intent.resolve({
  windowAddress: "0x1",
  currentWorkspaceId: 1,
  targetWorkspace: 1,
  layoutName: "monocle",
  dragDeltaY: -12,
});
assert.equal(monocleIntent.type, "layoutReorder");
assert.equal(layout.get("monocle").getDropAction(monocleIntent).commands[1], "cyclenext");

const floatingIntent = intent.resolve({
  windowAddress: "0x1",
  currentWorkspaceId: 1,
  targetWorkspace: 2,
  isFloating: true,
  floatingDropPosition: { x: 200, y: 300 },
});
assert.equal(floatingIntent.type, "floatingPlace");
const floatingDecision = drag.decideRelease({
  intent: floatingIntent,
  floatingDropPosition: { x: 200, y: 300 },
});
assert.equal(
  JSON.stringify(floatingDecision.commands),
  JSON.stringify([
    "movetoworkspacesilent 2, address:0x1",
    "movewindowpixel exact 200 300,address:0x1",
  ])
);
assert.equal(floatingDecision.optimisticMove.workspaceId, 2);

assert.equal(dispatchCompat.toLuaDispatch("workspace 3"), 'hl.dsp.focus({ workspace = "3" })');
assert.equal(dispatchCompat.toLuaDispatch("togglespecialworkspace scratch"), 'hl.dsp.workspace.toggle_special("scratch")');
assert.equal(dispatchCompat.toLuaDispatch("movetoworkspacesilent 2, address:0x1"), 'hl.dsp.window.move({ workspace = "2", window = "address:0x1", follow = false })');
assert.equal(dispatchCompat.toLuaDispatch("movetoworkspacesilent 2,address:0x1"), 'hl.dsp.window.move({ workspace = "2", window = "address:0x1", follow = false })');
assert.equal(dispatchCompat.toLuaDispatch("movewindowpixel exact 10 20,address:0x1"), 'hl.dsp.window.move({ x = 10, y = 20, relative = false, window = "address:0x1" })');
assert.equal(dispatchCompat.toLuaDispatch("focuswindow address:0x1"), 'hl.dsp.focus({ window = "address:0x1" })');
assert.equal(dispatchCompat.toLuaDispatch("closewindow address:0x1"), 'hl.dsp.window.close("address:0x1")');
assert.equal(dispatchCompat.toLuaDispatch("swapwindow address:0x2"), 'hl.dsp.window.swap({ target = "address:0x2" })');
assert.equal(dispatchCompat.toLuaDispatch("layoutmsg preselect r"), 'hl.dsp.layout("preselect r")');
assert.equal(dispatchCompat.toLuaDispatch("layoutmsg swapwithmaster"), 'hl.dsp.layout("swapwithmaster")');
assert.equal(dispatchCompat.toLuaDispatch("layoutmsg movewindow l"), 'hl.dsp.layout("movewindow l")');
assert.equal(dispatchCompat.toLuaDispatch("cyclenext"), "hl.dsp.window.cycle_next({ next = true })");
assert.equal(dispatchCompat.toLuaDispatch("cycleprev"), "hl.dsp.window.cycle_next({ next = false })");
assert.equal(dispatchCompat.keywordToLuaConfig("keyword input:follow_mouse 0"), "hl.config({ input = { follow_mouse = 0 } })");
assert.equal(dispatchCompat.keywordToLuaConfig("keyword cursor:no_warps 1"), "hl.config({ cursor = { no_warps = true } })");
assert.equal(dispatchCompat.keywordToLuaConfig("keyword cursor:warp_on_change_workspace 0"), "hl.config({ cursor = { warp_on_change_workspace = false } })");
assert.equal(dispatchCompat.keywordToLuaConfig("keyword misc:always_follow_on_dnd 0"), "hl.config({ misc = { always_follow_on_dnd = false } })");
assert.equal(dispatchCompat.cursorRestoreCommand(10, 20), "movecursor 10 20");
assert.equal(dispatchCompat.toLuaDispatch("movecursor 10 20"), "hl.dsp.cursor.move({ x = 10, y = 20 })");
assert.equal(dispatchCompat.shouldRestoreCursorAfter("focuswindow address:0x1"), true);
assert.equal(dispatchCompat.shouldRestoreCursorAfter("layoutmsg preselect r"), true);
assert.equal(dispatchCompat.shouldRestoreCursorAfter("keyword cursor:no_warps 1"), false);
assert.equal(dispatchCompat.shouldRestoreCursorAfter("movecursor 10 20"), false);
assert.equal(dispatchCompat.toLuaDispatch('hl.dsp.focus({ workspace = "4" })'), 'hl.dsp.focus({ workspace = "4" })');
assert.equal(dispatchCompat.toLuaDispatch("unknowncommand address:0x1"), "");
assert.equal(dispatchCompat.toBatchSegment("unknowncommand address:0x1"), "");
assert.equal(JSON.stringify(dispatchCompat.rejectedCommands(["workspace 3", "unknowncommand address:0x1", "keyword cursor:no_warps 1"])), JSON.stringify(["unknowncommand address:0x1"]));
assert.equal(
  dispatchCompat.commandsToBatchPayload(["focuswindow address:0x1", "layoutmsg preselect r"]),
  'dispatch hl.dsp.focus({ window = "address:0x1" }); dispatch hl.dsp.layout("preselect r")'
);
assert.equal(
  dispatchCompat.commandsToBatchPayload(["keyword cursor:no_warps 1", "focuswindow address:0x1"]),
  'eval hl.config({ cursor = { no_warps = true } }); dispatch hl.dsp.focus({ window = "address:0x1" })'
);
assert.equal(
  dispatchCompat.commandsToBatchPayload(["keyword input:follow_mouse 0", "keyword cursor:no_warps 1", "keyword cursor:warp_on_change_workspace 0", "workspace 3"]).startsWith("eval hl.config({ input = { follow_mouse = 0 } }); eval hl.config({ cursor = { no_warps = true } }); eval hl.config({ cursor = { warp_on_change_workspace = false } }); dispatch "),
  true
);
assert.equal(
  dispatchCompat.commandsToBatchPayload(["keyword input:follow_mouse 0", "keyword cursor:no_warps 1", "keyword cursor:warp_on_change_workspace 0", "workspace 3"]).includes("input.follow_mouse"),
  false
);
assert.equal(
  dispatchCompat.commandsToBatchPayload(["keyword input:follow_mouse 0", "keyword cursor:no_warps 1", "keyword cursor:warp_on_change_workspace 0", "workspace 3"]).includes("cursor.no_warps"),
  false
);
const guardedFocusPayload = dispatchCompat.commandsToBatchPayload(["keyword input:follow_mouse 0", "keyword cursor:no_warps 1", "keyword cursor:warp_on_change_workspace 0", "keyword cursor:warp_on_toggle_special 0", "keyword misc:always_follow_on_dnd 0", "focuswindow address:0x1", "movecursor 10 20"]);
assert.equal(guardedFocusPayload.startsWith("eval hl.config({ input = { follow_mouse = 0 } }); eval hl.config({ cursor = { no_warps = true } }); eval hl.config({ cursor = { warp_on_change_workspace = false } }); eval hl.config({ cursor = { warp_on_toggle_special = false } }); eval hl.config({ misc = { always_follow_on_dnd = false } }); dispatch "), true);
assert.equal(guardedFocusPayload.includes('dispatch hl.dsp.focus({ window = "address:0x1" }); dispatch hl.dsp.cursor.move({ x = 10, y = 20 })'), true);
assert.equal(guardedFocusPayload.includes("dispatch hl.dsp.cursor.move({ x = 10, y = 20 })"), true);
assert.equal(guardedFocusPayload.includes("follow_mouse = 1"), false);
assert.equal(guardedFocusPayload.includes("no_warps = false"), false);

const guardedLayoutPayload = dispatchCompat.commandsToBatchPayload(["keyword input:follow_mouse 0", "keyword cursor:no_warps 1", "keyword cursor:warp_on_change_workspace 0", "keyword cursor:warp_on_toggle_special 0", "keyword misc:always_follow_on_dnd 0", "workspace 3", "movecursor 10 20", "keyword general:layout scroll", "workspace 1", "movecursor 10 20"]);
assert.equal(guardedLayoutPayload.startsWith("eval hl.config({ input = { follow_mouse = 0 } }); eval hl.config({ cursor = { no_warps = true } }); eval hl.config({ cursor = { warp_on_change_workspace = false } }); eval hl.config({ cursor = { warp_on_toggle_special = false } }); eval hl.config({ misc = { always_follow_on_dnd = false } }); dispatch "), true);
assert.equal(guardedLayoutPayload.includes('eval hl.config({ general = { layout = "scroll" } })'), true);
assert.equal(guardedLayoutPayload.includes('dispatch hl.dsp.focus({ workspace = "3" }); dispatch hl.dsp.cursor.move({ x = 10, y = 20 })'), true);
assert.equal(guardedLayoutPayload.includes('dispatch hl.dsp.focus({ workspace = "1" }); dispatch hl.dsp.cursor.move({ x = 10, y = 20 })'), true);
assert.equal(guardedLayoutPayload.includes("warp_on_change_workspace = true"), false);
assert.equal(/dispatch workspace\s/.test(guardedLayoutPayload), false);

assert.equal(
  intent.resolve({
    windowAddress: "0x1",
    currentWorkspaceId: 1,
    targetWorkspace: 2,
    sourceMonitorId: 0,
    targetMonitorId: 1,
    enableCrossMonitorDrag: false,
  }).status,
  "cross-monitor-disabled"
);

assert.equal(
  intent.resolve({
    windowAddress: "0x1",
    currentWorkspaceId: 1,
    targetWorkspace: 1,
    isFullscreen: true,
  }).status,
  "unsupported-source-state"
);

process.stdout.write("pure helper checks passed\n");
