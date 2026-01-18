# Enhanced Authentication Branding Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Improve GPG and password manager authentication UI by providing branded cards, parsed GPG metadata, and a robust "Show Details" section with copy capabilities.

**Architecture:** 
- **Deterministic Branding:** Use a central `contextModel` in `AuthContent.qml` to resolve app identities based on `actionId`, `exe`, and `displayName`.
- **Hybrid Iconography:** Always render a stable-color fallback tile with an optional internal icon glyph (`lock`, `key`) to guarantee zero "broken" states.
- **Scrollable Technical Data:** Rework the Details section with `Flickable` and `maxHeight` to prevent layout overflow.

**Tech Stack:** QML (Qt6), Quickshell, JavaScript, Wayland Clipboard (`wl-copy`).

---

### Task 1: Data Model & App Branding
**Files:**
- Modify: `polkit-auth/AuthContent.qml`
- Modify: `polkit-auth/i18n/en.json`

**Step 1: Define App Profiles**
Add a `readonly property var appProfiles` mapping common IDs to branding data.
```qml
readonly property var appProfiles: ({
    "1password": { color: "#0094F5", label: "1Password", glyph: "lock" },
    "bitwarden": { color: "#175DDC", label: "Bitwarden", glyph: "lock" },
    "keepassxc": { color: "#6A9955", label: "KeePassXC", glyph: "lock" },
    "proton-pass": { color: "#6D4AFF", label: "Proton Pass", glyph: "lock" },
    "gpg": { color: Color.mPrimary, label: "GPG", glyph: "key" },
    "git": { color: "#F05032", label: "Git", glyph: "brand-git" }
})
```

**Step 2: Implement `contextModel`**
Implement logic to resolve `currentProfile`.
- Check `request.actionId` (e.g. `com.1password.1Password.unlock`).
- Check `request.requestor.displayName` or `request.subject.exe`.
- Fallback to generic `shield` glyph.

**Step 3: Add Translation Keys**
Add `"actions": { "copy-details": "Copy Details" }` to `en.json`.

**Step 4: Commit**
`git commit -m "feat(polkit): add request classification and app branding profiles"`

---

### Task 2: GPG Metadata Parsing
**Files:**
- Modify: `polkit-auth/AuthContent.qml`

**Step 1: Implement GPG Parser**
Add `readonly property var gpgInfo` that extracts identity and key info from `request.description` using regex.
- `identity`: `"anthonyhab (github) <...>"`.
- `keyId`: `ID EB9E690ACE02B41A`.
- `isGithub`: `fullDesc.includes("github")`.

**Step 2: Commit**
`git commit -m "feat(polkit): implement GPG metadata parser"`

---

### Task 3: Connection Flow & Icon Fallbacks
**Files:**
- Modify: `polkit-auth/AuthContent.qml`

**Step 1: Update `ConnectionFlow`**
- Always render `FallbackIcon` (the colored square).
- Overlay `NIcon` only if `contextModel.glyph` is set.
- Use `contextModel.accentColor` for the pulse line.

**Step 2: Commit**
`git commit -m "style(polkit): update connection flow with brand colors and glyph overlays"`

---

### Task 4: Context Card UI
**Files:**
- Modify: `polkit-auth/AuthContent.qml`

**Step 1: Add Info Card**
Insert a new `NBox` above the password input.
- Show `gpgInfo` details (Identity, Key ID, Date) if it's a GPG request.
- Show Branded App Name + "Unlock vault" if it's a password manager.
- Match `Style.radiusL` and `Color.mSurfaceVariant`.

**Step 2: Commit**
`git commit -m "feat(polkit): implement branded context card above input"`

---

### Task 5: Scrollable Details & Clipboard
**Files:**
- Modify: `polkit-auth/AuthContent.qml`

**Step 1: Rework Details Expander**
- Wrap the details `ColumnLayout` in a `Flickable` inside an `Item` with `Layout.maximumHeight: 200 * Style.uiScaleRatio`.
- Set `wrapMode: Text.Wrap` for all monospace labels.

**Step 2: Add Copy Button**
Add an `NIconButton` or `NButton` inside the details card.
- `onClicked: copyProcess.start()`
- Update `copyProcess.command`: `["wl-copy", (request.message + "\n" + request.description + "\n" + request.subject.cmdline)]`.

**Step 3: Commit**
`git commit -m "feat(polkit): make details scrollable and add copy button"`

---

### Task 6: Validation & Cleanup
**Step 1: Run Linters**
Run: `qmlformat -i polkit-auth/AuthContent.qml`
Run: `qmllint polkit-auth/AuthContent.qml`

**Step 2: Final Verification**
- Visual check: GPG identity parsing.
- Visual check: 1Password blue branding.
- Visual check: Details scrollbar visibility.

**Step 3: Commit**
`git commit -m "chore(polkit): lint and final polish"`
