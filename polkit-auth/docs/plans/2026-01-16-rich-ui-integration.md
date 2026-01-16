# Polkit Auth Rich UI Integration Plan

> **For Claude:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Integrate rich request metadata (`requestor` GUI app, `subject` process) and normalized prompts into the `polkit-auth` plugin UI to match the 1Password-style UX.

**Architecture:** Update `AuthContent.qml` to utilize the new JSON fields. Redesign the header to show the requesting application icon (or fallback letter-square) and a clear "Allow **App** to **Action**" message.

**Tech Stack:** QML (Qt6), Quickshell, JavaScript

---

## Task 1: Add Fallback Color Helper

**Files:**
- Create: `ColorUtils.js` (or add to `AuthContent.qml`)

**Checklist:**
- [ ] Implement a stable hashing function to map `fallbackKey` to a theme-safe color.
- [ ] Define a palette of 8-12 vibrant, distinct colors that look good in both light and dark modes.

---

## Task 2: Update `AuthContent.qml` Data Logic

**Files:**
- Modify: `AuthContent.qml`

**Checklist:**
- [ ] Add `requestor` and `subject` properties.
- [ ] Update `commandPath` to use `subject.cmdline` or `subject.exe` as primary sources.
- [ ] Add a `displayAction` property that extracts the action from `request.message` (e.g., "run `/usr/bin/echo` as root" -> "run echo").

---

## Task 3: Redesign Header and Visual Identity

**Files:**
- Modify: `AuthContent.qml`

**Checklist:**
- [ ] Implement the "Requesting App Icon" component:
    - [ ] If `requestor.iconName` is valid, show the icon.
    - [ ] Else, show a colored square with `requestor.fallbackLetter`.
- [ ] Implement the "Visual Connection" graphic (App Icon -> Check -> Polkit Icon).
- [ ] Update the main instruction label to: `Allow **App** to **Action**`.

---

## Task 4: Update Context Card and Details

**Files:**
- Modify: `AuthContent.qml`

**Checklist:**
- [ ] Show the direct `subject.exe` or `subject.cmdline` in the context card.
- [ ] Improve the avatar/user display to be more consistent with the new identity-focused design.
- [ ] (Optional) Add a "Details" expander for raw Polkit details.

---

## Task 5: Verification

**Checklist:**
- [ ] Verify `pkexec` shows the requesting terminal (e.g., kitty/alacritty).
- [ ] Verify `secret-tool` shows accurate attribution.
- [ ] Verify fallback icons look good for apps without desktop entries.
- [ ] Ensure the prompt text has no trailing colon.
