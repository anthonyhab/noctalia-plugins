# Polkit Auth "Modern/Mobile" Redesign Plan

> **For Claude:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Redesign the `polkit-auth` dialog to a polished "Modern/Mobile" card layout with connection flow animations, collapsible details, and improved micro-interactions.

**Architecture:** 
- **Component-based:** Reuse existing QML components (`NBox`, `NButton`, `NIcon`) from `qs.Widgets`.
- **Single File (Mostly):** Primarily refactoring `AuthContent.qml` into sub-components (inline or separated) for clarity.
- **State-Driven:** Use states (`"auth"`, `"success"`) for high-level transitions.
- **Color System:** Use `Color.mPrimary` for CTA/Identity and `Color.mSecondary` for the connection flow.

**Tech Stack:** 
- Qt Quick / QML (Noctalia/Quickshell ecosystem)
- `qs.Commons` (Style/Color singletons)
- `qs.Widgets` (Standard UI components)

---

### Task 1: Refactor Structure & Implement Top "Connection Flow" Card

**Files:**
- Modify: `polkit-auth/AuthContent.qml`

**Context:** Replace the current "1Password" row with the new vertically stacked card design.

**Step 1: Define New Metrics & Color Palette (Secondary Accent)**

Update `AuthContent.qml` properties:
- Define `colorFlowLine`: `Qt.alpha(Color.mSecondary, 0.2)`
- Define `colorFlowActive`: `Color.mSecondary`
- Define `cardRadius`: `Style.radiusL` (More rounded for "Mobile" feel)

**Step 2: Create "Connection Flow" Animation Component**

Create inline `component ConnectionFlow : Item { ... }` inside `AuthContent`:
- **Visuals:** 
    - Left Icon: Requestor App (Large)
    - Right Icon: System Lock
    - Center: Dashed/Solid line connecting them
- **Animation:** 
    - `Rectangle` (the "pulse") moving left-to-right along the center line.
    - Loop animation (`SequentialAnimation` with `PauseAnimation`).
    - Use `Color.mSecondary` for the pulse.

**Step 3: Update Header Section**

Replace `ColumnLayout` (lines 193-268) with:
- `ConnectionFlow` component (new) centered at top.
- "Allow **App** to..." text centered below it.
- Use `opacity` transition for entrance.

**Step 4: Verify**

Run `qs-preview` or check in shell (visual verification required).

**Step 5: Commit**

```bash
git add polkit-auth/AuthContent.qml
git commit -m "feat(polkit): implement modern connection flow header"
```

---

### Task 2: Implement Collapsible "Details" Section

**Files:**
- Modify: `polkit-auth/AuthContent.qml`

**Context:** The command path and user details are technical noise. Hide them behind a "Details" toggle.

**Step 1: Create Expandable Container**

Add `property bool showDetails: false` to `root`.

Create `ColumnLayout` for details:
- **Toggle Button:** Small text/icon button "Details ▾" (rotates on toggle).
- **Content:** The existing `Context Details Card` content (User, Path, Cmdline).
    - Wrap in `Item` with `clip: true`.
    - Animate `height` and `opacity` based on `showDetails`.

**Step 2: Style the Technical Data**

- Use `NBox` with `Color.mSurfaceVariant` (lighter/flat) for the details area.
- Use monospace font for paths (existing).
- Ensure smooth height animation (use `Behavior on height { NumberAnimation { ... } }`).

**Step 3: Verify**

Check animation smoothness and layout stability (`stableHeight` logic might need tweaking to account for dynamic expansion).

**Step 4: Commit**

```bash
git add polkit-auth/AuthContent.qml
git commit -m "feat(polkit): add collapsible details section"
```

---

### Task 3: Polish Input & Action Micro-interactions

**Files:**
- Modify: `polkit-auth/AuthContent.qml`

**Context:** The input field and button need "top tier" feel (focus glow, spinner state, shake).

**Step 1: Input Field Polish**

- Increase `radius` to `Style.radiusL` (Pill shape).
- **Focus Animation:** 
    - Add `Behavior on border.color { ColorAnimation { duration: 150 } }`.
    - Add `Behavior on border.width { NumberAnimation { duration: 150 } }` (1px -> 2px).
- **Icon Integration:** Ensure the "eye" icon and "caps lock" warning sit cleanly inside the pill.

**Step 2: Action Button Polish**

- **Busy State:**
    - Morph text "Authenticate" -> "" (fade out).
    - Scale up/fade in `NIcon` (loader) in center.
    - Disable click but keep visual "pressed" state or distinct "busy" opacity.
- **Style:** Match Input Field radius (`Style.radiusL`).

**Step 3: Refine Shake Animation**

- Replace `SequentialAnimation` (linear shake) with `SpringAnimation`:
    - Property: `anchors.horizontalCenterOffset` (or a translation `x` transform).
    - Spring: `damping: 0.2`, `epsilon: 0.25`.
    - Trigger: On error.

**Step 4: Commit**

```bash
git add polkit-auth/AuthContent.qml
git commit -m "style(polkit): improve input and button micro-interactions"
```

---

### Task 4: Success State Morph & Final Layout Assembly

**Files:**
- Modify: `polkit-auth/AuthContent.qml`

**Context:** The success state should feel like a celebration, morphing the whole card.

**Step 1: Define States**

Add `states: [ State { name: "auth" }, State { name: "success" } ]` to `root`.

**Step 2: Layout Transitions**

- Wrap Main Content (Flow + Input + Button) in an `Item` (id: `authLayer`).
- Wrap Success Content (Checkmark) in an `Item` (id: `successLayer`).
- **Success Layer:**
    - Centered large green checkmark.
    - Scale 0 -> 1 with overshoot (pop effect).
    - Opacity 0 -> 1.
- **Auth Layer:**
    - Scale 1 -> 0.9.
    - Opacity 1 -> 0.

**Step 3: Final Polish Check**

- Check `stableHeight` behavior during transitions.
- Ensure the floating "Close" button remains accessible and z-ordered correctly.
- Verify `Color.mSecondary` flow animation loops correctly.

**Step 4: Commit**

```bash
git add polkit-auth/AuthContent.qml
git commit -m "feat(polkit): add success state morph animation"
```
