# Treat Window groups as grouped units

Overview represents Hyprland grouped/tabbed windows as one grouped preview with a mini tab strip. Tabs can be clicked or scrolled to focus a member, but Window relocation and Retiling operate on the whole group; Overview does not edit group membership or drag individual tabs out of the group. This matches Hyprland’s group movement behavior and avoids making small Overview tabs responsible for finicky drag semantics.
