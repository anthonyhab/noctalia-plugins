# Fix Filter Vertical Alignment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix the vertical alignment of the theme filter label in the Omarchy panel so it is visually centered.

**Architecture:** 
- Ensure the filter button container (`Rectangle`) has an integer height using `Math.round()`.
- Apply a vertical offset to the `NText` label using `anchors.verticalCenterOffset` to compensate for font metrics that cause it to sit too low.

**Tech Stack:** QML (Quickshell)

### Task 1: Update Omarchy Panel Filter Styling

**Files:**
- Modify: `omarchy/Panel.qml:143-157`

**Step 1: Apply fixes to Panel.qml**

- Change `Layout.preferredHeight` to use `Math.round()`.
- Add `anchors.verticalCenterOffset: -1` to the `NText` component.

**Step 2: Verify visually (if possible) or by code inspection**

Check that `Layout.preferredHeight` is now an integer and the offset is applied.

**Step 3: Commit**

```bash
git add omarchy/Panel.qml
git commit -m "fix(omarchy): improve vertical alignment of theme filter label"
```
