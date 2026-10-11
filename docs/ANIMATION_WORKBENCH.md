# Animation Workbench

Open the in-game elf on a lightweight preview stage from the project root:

```powershell
& $env:GODOT_BIN --path . tools/animation_workbench.tscn
```

Choose a clip to play it. Pause, stop, loop, scrub, or slow it down to inspect
contacts. Middle mouse drag orbits the camera; the wheel changes distance. The
rig report checks the clip's bone tracks against the loaded skeleton and
reports missing bones in the shared animation profile.

## Portable animation contract

`scripts/player/animation_rig_profile.gd` defines `ophelia_humanoid_v1`: 22
body deformation bones, a semantic Quaternius-to-elf map, +Z source-forward,
and model scale 0.8. New body motion should target this profile, use in-place
movement, and keep root translation out of the clip. Facial, twist, helper,
hair, and clothing bones remain available for clips that specifically need
them, but aren't required for a portable locomotion or gesture animation.

The profile is an animation channel contract; the game keeps the full source
skeleton because foot locking, Grace, leap poses, breath, and attachments use
its existing names and hierarchy. This avoids breaking those systems while
keeping ordinary animation exports small and retargetable.

## Authoring loop

1. Author and bake an action onto deform bones in Blender, preserving the
   character's rest pose and hierarchy. Keep the editable control setup in the
   `.blend`; export only the evaluated animation.
2. Retarget the export to the profile, preserving the role name, effective
   clip range, loop policy, and in-place root. The current Quaternius and BVH
   retargeters share this profile.
3. Open the workbench and inspect the clip at normal speed, in slow motion,
   and across its loop seam. Confirm the rig report says `READY`.
4. Check the final clip in the gameplay animation graph as well; the workbench
   doesn't run physics, FootLock, Grace, leap, or landing modifiers.

The workbench previews the runtime Quaternius library and the separately
licensed legacy Bandai library. It doesn't merge them or change which library
the game plays. Keep their source and license records with any derived clips;
the Bandai set is CC BY-NC 4.0.
