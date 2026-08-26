# Overview

The Overview context names the user-facing concepts for the workspace overview experience.

## Language

**Overview**:
A transient workspace-selection surface that shows workspaces together so the user can understand, switch between, and organize them.
_Avoid_: Hypr Overview, Workspace Overview when used as the primary user-facing label

**Workspace**:
A focusable place where windows live. An **Overview** shows many **Workspaces** at once.
_Avoid_: Desktop, space

**Window relocation**:
Moving a window from one **Workspace** to another, including Workspaces associated with another monitor, while preserving the Overview’s role as a workspace organizer.
_Avoid_: Retiling when the window changes Workspace

**Retiling**:
Changing the tiled arrangement of windows inside a **Workspace** through split or swap intent during a drag, including converting a floating window into the tiled arrangement.
_Avoid_: Window relocation, layout switching

**Preview style**:
The way windows are visually represented inside the **Overview**. The canonical styles are Live, Pixelated, Dithered, and Flat; Pixelated is the default.
_Avoid_: Visual mode, shader preset, preview effect

**Grid geometry**:
The configured row-and-column shape of the **Overview**. The default Grid geometry is 3×3, but the user may change it.
_Avoid_: Fixed grid, workspace count

**Workspace group**:
The consecutive numeric Workspaces shown by the current **Grid geometry**; it starts at Workspace 1 unless the focused Workspace falls outside that group. If a Scratchpad Workspace is focused, the last numeric Workspace group remains active when known. PageUp/PageDown can change the active Workspace group while Overview is open; the focused Workspace stays focused if still visible, otherwise the first Workspace in the new group becomes focused. All Overview surfaces show the same Workspace group, while each monitor’s surface shows only the windows assigned to that monitor and marks that monitor’s active Workspace.
_Avoid_: Page, workspace bank

**Scratchpad Workspace**:
A non-numeric Workspace used for temporary or hidden windows. When enabled, active or occupied Scratchpad Workspaces occupy trailing slots in the Overview.
_Avoid_: Special workspace in user-facing labels

**Title strip**:
A compact label on a window preview that identifies the represented window when visual recognition is not enough.
_Avoid_: Title bar, caption bar

**Window icon**:
An application icon shown on a window preview. Window icons are optional supporting labels, not the primary Overview structure.
_Avoid_: App badge

**Urgent indication**:
A minimal visual cue that a window inside a Workspace is asking for attention.
_Avoid_: Floating badge, fullscreen badge, monitor badge

**Window group**:
A Hyprland grouped/tabbed set of windows represented as one unit in the **Overview** with a mini tab strip. Window relocation and **Retiling** move the entire Window group; clicking a tab or scrolling over the group focuses a member.
_Avoid_: Separate loose windows when they belong to a group, group-membership editing

## Example dialogue

Designer: “When the user opens the Overview, what should they see first?”
Developer: “A flat grid of Workspaces, with the focused Workspace clearly indicated.”
Designer: “So the button can just say Overview?”
Developer: “Yes. In this context, Overview means the workspace overview, not a generic settings or system overview.”
Designer: “If they drag a window to another Workspace, is that retile behavior?”
Developer: “No. That is Window relocation. Retiling only changes the tiled arrangement inside a Workspace.”
Designer: “Can users still choose the old pixelated look?”
Developer: “Yes. That is a Preview style, alongside Live, Dithered, and Flat.”
Designer: “Is the 3×3 shape mandatory?”
Developer: “No. 3×3 is the default Grid geometry; users can still choose a different row-and-column shape.”
Designer: “What does a 3×3 Overview show when Workspace 10 is focused?”
Developer: “All monitors show the Workspace group 10–18, but each monitor only shows its own windows in those Workspaces.”
Designer: “How do they see the next Workspace group without leaving Overview?”
Developer: “PageUp and PageDown change the active Workspace group. If the focused Workspace is no longer visible, the first Workspace in the new group becomes focused.”
Designer: “Where do Scratchpad Workspaces go when enabled?”
Developer: “They use trailing slots so numeric Workspaces keep their normal reading order.”
Designer: “Do Title strips and Window icons make the grid too busy?”
Developer: “Title strips are on by default in auto mode; Window icons are available but off by default.”
Designer: “Should every window state get a badge?”
Developer: “No. Only Urgent indication survives; floating, fullscreen, and monitor badges are outside the minimal chrome.”
Designer: “What about grouped or tabbed windows?”
Developer: “A Window group should show mini tabs. Clicking a tab or scrolling over the group focuses a member, but dragging the grouped preview moves or Retiles the whole group.”
