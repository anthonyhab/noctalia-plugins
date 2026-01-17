# Fix Header Vertical Alignment and Button Height Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ensure the theme filter button has the exact same height as the close button and both are perfectly centered vertically in the header.

**Architecture:** 
- Use `Style.toOdd(Style.baseWidgetSize * 0.8)` for `themeFilterButton` height to match `NIconButton`.
- Explicitly set `Layout.alignment: Qt.AlignVCenter` on all children of the header `RowLayout`.
- Remove the `anchors.verticalCenterOffset` and instead rely on proper container alignment and `Style.pixelAlignCenter` if needed.

**Tech Stack:** QML (Quickshell)

### Task 1: Synchronize Heights and Align Header Elements

**Files:**
- Modify: `omarchy/Panel.qml:127-174`

**Step 1: Update header elements in Panel.qml**

- Set `Layout.alignment: Qt.AlignVCenter` for `NIcon` (palette), `NText` (title), `Rectangle` (filter), and `NIconButton` (close).
- Change `themeFilterButton` height to `Style.toOdd(Style.baseWidgetSize * 0.8)`.
- Center the `filterLabel` using `Style.pixelAlignCenter` for the `y` coordinate for pixel-perfect vertical centering, or ensure `anchors.centerIn: parent` works with integer coordinates.

**Step 2: Commit**

```bash
git add omarchy/Panel.qml
git commit -m "fix(omarchy): synchronize header button heights and improve vertical centering"
```
