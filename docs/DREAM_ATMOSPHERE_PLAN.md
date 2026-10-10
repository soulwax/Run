# Dream atmosphere: overlapping memory architecture

Direction updated 2026-10-10. This is an implementation plan for the current playable dream. The earlier staged flashback scenes and their optional asset pack were removed. Memory will return as architecture that appears within the live winter route: forest, house, lighthouse and impossible interior share the same snow, light and camera. The player never leaves the walk for a separate flashback level.

## What the dream should do

Begin with an ordinary, cold walk and a woman who needs time to speak. Let each later place make one of her images physically difficult to dismiss. The geometry should express guarded distance, freezing, remembered danger and the effort of asking for help; it should not reenact the assault or expose Mathilda's face. The ending still gives a warning about the man with the axe, with enough uncertainty that Ophelia and Mathilda's later chapters retain their own discoveries.

The route remains linear and freely traversable. Running, stopping, turning around and returning to a cue must all make sense. Dialogue stays subtitle driven, one speaker and one reply at a time. The world may change around a conversation, but Mathilda, the player's footing, the selected reply and the words above her head must remain readable. A bad wakeup can follow a pressured conversation or missed clue; visual effects must not secretly decide it.

## The visual rule: one place, two dimensions

Each memory fragment has a mundane close reading and an impossible wider reading. A pine trunk passes through a plaster wall whose edge becomes bark. Snow falls through a ceiling that still casts a room-shaped shadow. A corridor seems to fit between two trees, yet its far window is much farther away than their separation allows. A lighthouse stair appears to turn behind its own first landing. These are world-anchored objects with believable local scale and depth. Their contradictions emerge through walking, looking back and parallax.

Use **one dominant impossibility per view**. Give the eye stable trees, tracks, Mathilda and the open route before introducing a second form. Keep a minimum of two quiet intervals between the strongest images. No fragment gains collision on the walking line, changes the player's controls, hides an answer, or makes a side path look like a required exit. The present-day route always has a visible way forward and back.

| Route position | Player action and story cue | Architecture that overlaps the forest | Emotional purpose |
| --- | --- | --- | --- |
| **0–14 m: threshold** | Enter the snow; hear the first ordinary lines. | The house light and cut trees read naturally. One doorway-shaped gap subtly repeats farther ahead at the wrong scale. | Give the player a trustworthy baseline and a reason to notice the first discrepancy. |
| **15–27 m: sisters / delayed steps** | Hear the sisters image; stop or follow Mathilda. | Three tree gaps suggest doors; one contains a short stretch of floorboard under snow. A second set of steps arrives late from the gap the player just crossed. The dark patch at 14 m absorbs the room tone afterward. | Make freezing and choosing distance felt in space, without grading the player's movement. |
| **31–42 m: thread / lighthouse** | Hear the Ariadne line while Mathilda looks away; continue along the known path. | A narrow stair and railing exist only between trunks. Near them, the steps are credible; from the path, they curve toward a partial lighthouse gallery that cannot fit within the grove. Its slow beam crosses snow, branches and Mathilda in the same world, then meets a window at an impossible bearing. The dark patch at 42 m returns to near silence. | Turn a metaphor about finding a way out into a spatial question. The lighthouse is a witness, not a destination or objective. |
| **46–58 m: warm window** | Hear Mathilda's clearest clue and, when offered, speak with her. | A domestic wall and lit sill briefly occupy the trees. Floorboards sink into drifts; snow continues inside. The axe appears only as a fleeting shadow or partial outline outside the warm light. The room never closes around the player. | Let the warning become specific without staging violence or demanding disclosure. Keep her chosen distance visible. |
| **58–67 m: clearing / answer** | Reach the clearing, answer or remain quiet, and hear the ending. | The existing folded snow path, a repeated threshold and the lighthouse beam align for one impossible wide view. The room edge recedes as Mathilda speaks. On a repaired exchange, the route regains depth; on an unresolved or ruptured exchange, the light loses its bearing, but the exit stays legible. | Make the conversation, not the spectacle, the climax. Let the world settle before wakeup. |

The existing dark patches at 14, 27, 42 and 58 m and the folded path beside the clearing provide the rhythm. Introduce architecture at those measured positions rather than scattering details everywhere. The lighthouse and domestic wall should never appear as fully explorable buildings; their fragments are enough to imply a larger past.

## Timing, shading and sound

- **Reveal in layers.** Hold a fragment at low contrast as the player approaches. Reveal its contradiction during the associated Mathilda line, sustain it through the reply, then leave a faint afterimage until the next dark patch. Avoid abrupt spawning in the camera or repeating a reveal on backtrack.
- **Make the join visible.** Use shared snow accumulation, light spill and world-space edge breakup where plaster meets bark or boards meet drifts. Keep the core geometry opaque enough for depth and shadow to read. Use the existing localized `dream_warp.gdshader` only for brief perception pulses; the architecture must still look impossible with `screen_effects = 0`.
- **Reserve the strongest color shift.** Cold blue remains the base. The lighthouse beam is pale and slow; the warm window owns the first sustained amber. Avoid strobing, broad chromatic splits, or bright effects behind subtitles and choice labels.
- **Score absence.** Extend `DreamSoundscape` with a quiet interior room tone that leaks into the snow near each fragment, one distant wood creak, and a low lighthouse resonance. The existing delayed snow steps keep their sparse timing. Drop wind and room tone near the dark patches and just before Mathilda's apology. No spoken lines or loud shock cue.
- **Keep Mathilda intentional.** Her look toward the stair and window, measured steps, disappearance and return should coincide with the memory's rise and fall. When she rambles, she may look into the architecture; when she asks or answers directly, restore eye contact and hold the image still.

## Runtime and content contract

`DreamRoute` already emits `cue_requested(cue_id, at)` at the three story offsets in `assets/dialogue/dream.json`. That signal currently fires as the player crosses an offset, before a queued subtitle may be shown. Use it to locate or prepare a fragment. Let `DreamExperience._show_next_story_line()` trigger its visible reveal when Mathilda actually says the associated line and records the journal entry. This prevents a sprinting player from seeing the warm-window image long before hearing its clue.

Add one dream-only `DreamMemoryArchitecture` helper under `DreamExperience`. It receives a route transform and a cue ID, builds off-path fragments using `Trail.frame_at()` and `Trail.on_ground()`, and tracks `dormant → anticipating → revealed → afterimage → quiet`. Each cue is idempotent; backtracking can expose the remaining architecture without replaying dialogue or duplicating nodes. Pause and journal hold the current state so a player does not miss a reveal while reading. The route's collision and the three existing outcomes remain owned by their current systems.

Keep the first cue specifications in one small map keyed by `sisters`, `thread` and `window`, with art-directable dimensions, side offsets, reveal distances, light strengths and fade times. If these controls later move into `dream.json`, update both `scripts/world/dream_story.gd` and `tools/studio/dream_story.py` in the same slice; Story Studio currently drops unknown fields. Source any replacement art with verified redistribution rights. The removed `requested_dream` pack is not an implementation dependency, and procedural forms must provide the same composition when optional meshes are absent.

The visual response to dialogue is restrained. Respecting Mathilda's stated distance lets the light and route hold steady; pressure can make the room edge withdraw. Repair restores the same place without magically erasing what happened. The warm-window clue and another cue still govern the resolved warning; no architecture view is required for a journal unlock or an ending.

## Implementation slices

Each slice has one owner and a reviewable result. Capture the **normal player camera** as well as the composed review camera. Run the focused visual review after slices 2, 4 and 6, as requested for every other slice.

| Slice | Work and primary files | Reviewable result |
| --- | --- | --- |
| **1. Baseline and cue contract** | Record entry, 15/31/46 m, clearing and lookback from the current build. Define the fragment state and cue-to-subtitle handshake in `dream_experience.gd` and a small new helper interface. | A route map and image baseline; cue order survives sprinting and backtracking with no new geometry. |
| **2. Threshold and corridor** | Build the repeated threshold and short impossible corridor in `dream_memory_architecture.gd`; add one shared edge material. Keep all geometry outside the walkable strip. | At 15 and 31 m, close views look plausible and a lookback shows one unmistakable contradiction. **Visual review 1:** clipping, readability and route clarity in full and lean graphics. |
| **3. Lighthouse and warm window** | Add the partial stair/gallery, slow beam, room edge, floorboards and window glow, anchored by `DreamRoute`. Tie the window's strongest reveal to its subtitle. | Three different compositions, with a clear warm-window clue and no graphic reenactment. |
| **4. Clearing and dialogue response** | Compose the existing folded path with repeated threshold and light bearing. Match Mathilda's gaze, apparition and reply timing; keep outcome rules intact. | Completed, unresolved and ruptured wakeups share a readable exit and have distinct afterimages. **Visual review 2:** every reply, journal and pause over the memory layer. |
| **5. Sound and restraint** | Extend `dream_soundscape.gd`; tune local warp, fog, snowfall and amber spill against the quiet intervals. | The dream reads with audio muted and with screen effects disabled; sound adds tension without carrying a required clue. |
| **6. Playability and final composition** | Update `tools/dream_view.gd` to capture player view at each cue and lookback, then walk the entire route slowly, sprinting and backtracking on full and lean settings. | **Visual review 3:** no pop-in, unwanted geometry intersections, hidden subtitles, route blockage or event overlap; the last image settles before wakeup. |

## Acceptance gates

1. A player can describe one ordinary detail, one impossible spatial relationship, and why the warm window matters. They can still complete the dream after ignoring every architectural fragment.
2. The first strong contradiction waits until after the opening. Each major view has one dominant anomaly, and at least one is discovered by player movement or looking back without a camera cut.
3. Mathilda's line, journal clue and visible fragment appear in the intended order even if the player runs through multiple cue offsets. Captions and choices never overlap or disappear behind geometry.
4. The same route supports stopping, sprinting, backtracking, pause, journal, reduced screen effects, muted audio, keyboard and controller. Full and lean graphics retain the same architecture and ending clues.
5. The visual treatment suggests aftermath and danger without showing the assault, making Mathilda disclose details, or turning the warning into a hunt. The three current wakeup outcomes and saved dream memory remain valid.
