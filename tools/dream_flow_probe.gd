extends Node

## Drives the live dream from the trail's end to the final choice at sprint pace.
## No memory is selected, so this probe never writes the player's dream save.
const MAIN := preload("res://scenes/main.tscn")
const EXPECTED_MARKERS := ["tree_line", "sisters", "footsteps", "thread", "lantern", "window", "empty_path"]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.dream_mode = true
	Game.character_selected = true
	var main := MAIN.instantiate()
	get_tree().root.add_child(main)
	for _frame in 2400:
		if Game.trail and Game.player and Game.phase == Game.Phase.DREAM:
			break
		await get_tree().process_frame
	assert(Game.phase == Game.Phase.DREAM, "dream must enter the playable phase")
	var route := main.find_child("DreamRoute", true, false)
	var experience: Node = route.get_parent() if route else null
	assert(experience != null, "live dream experience must exist")
	experience.set("_camera_choreography_enabled", false)
	var destination := Game.trail.frame_at(Game.trail.player_start_offset + 67.0)
	Game.player.global_position = Game.trail.on_ground(destination.origin) + Vector3.UP * 0.15
	Game.player.velocity = Vector3.ZERO
	Game.player.reset_physics_interpolation()
	var story: Dictionary = experience.get("_story")
	var beats: Array = story.get("beats", [])
	var events: Array = story.get("events", [])
	var seen_markers: Array[String] = []
	var seen_stations: Array[int] = []
	var last_stage := 0
	var last_event := 0
	var journal_and_pause_checked := false
	for _frame in 3600:
		await get_tree().process_frame
		var stage: int = experience.get("_stage")
		var event_index: int = experience.get("_story_event_cue_index")
		if stage > last_stage:
			seen_markers.append(str(beats[stage - 1].get("id", "")))
			last_stage = stage
		if event_index > last_event:
			seen_markers.append(str(events[event_index - 1].get("id", "")))
			last_event = event_index
		if experience.get("_story_line_active"):
			if not journal_and_pause_checked:
				experience.call("_open_dream_journal")
				assert(experience.get("_dream_journal_open") and Game.player.dialogue_locked, "journal must hold the dream and player")
				experience.call("_close_dream_journal")
				assert(not Game.player.dialogue_locked, "closing the journal must restore free walking")
				Game.toggle_pause()
				assert(Game.phase == Game.Phase.PAUSED, "pause must interrupt the dream")
				Game.toggle_pause()
				assert(Game.phase == Game.Phase.DREAM, "resume must restore the dream")
				journal_and_pause_checked = true
			experience.set("_caption_time", 100.0)
			var speech := experience.get("_speech_sprite") as Sprite3D
			speech.modulate.a = 0.0
		if experience.get("_story_gap_remaining") > 0.0:
			experience.set("_story_gap_remaining", 0.0)
		if experience.get("_station_dialogue_active"):
			var round_index: int = experience.get("_station_round_index")
			if not seen_stations.has(round_index):
				seen_stations.append(round_index)
				assert(experience.get("_choice_buttons").size() == story["small_talk"][round_index]["choices"].size(), "station choices must match their own round")
				experience.call("_choose_small_talk", 0)
				assert(experience.get("_conversation_response") == story["small_talk"][round_index]["choices"][0]["response"], "station must use the displayed response")
			if experience.get("_conversation_response_pending"):
				experience.call("_reveal_conversation_response")
		if experience.get("_station_dialogue_active") and experience.get("_conversation_response_ready"):
			experience.call("_continue_station_dialogue")
		if experience.get("_conversation_intro_waiting"):
			experience.set("_conversation_intro_waiting", false)
			experience.call("_build_small_talk_choices")
		if experience.get("_answer_open") and not experience.get("_station_dialogue_active") and experience.get("_conversation_round") < story["small_talk"].size() and not experience.get("_conversation_waiting"):
			experience.call("_choose_small_talk", 0)
		if experience.get("_answer_open") and not experience.get("_station_dialogue_active") and experience.get("_conversation_response_pending"):
			experience.call("_reveal_conversation_response")
		if experience.get("_answer_open") and not experience.get("_station_dialogue_active") and experience.get("_conversation_response_ready"):
			experience.set("_conversation_response_ready", false)
			experience.set("_conversation_waiting", false)
			experience.set("_conversation_round", int(experience.get("_conversation_round")) + 1)
			experience.call("_build_small_talk_choices")
		if experience.get("_answer_open") and experience.get("_choice_buttons").size() == story["branches"].size() and experience.get("_conversation_round") >= story["small_talk"].size():
			break
	assert(seen_markers == EXPECTED_MARKERS, "sprinting must preserve beat and event order: %s" % [seen_markers])
	assert(seen_stations == [0, 1], "station replies must follow their associated cue: %s" % [seen_stations])
	assert(experience.get("_story_line_queue").is_empty(), "no story line may be discarded")
	assert(experience.get("_answer_open"), "the final choice must become available")
	assert(journal_and_pause_checked, "journal and pause must be exercised on a line")
	_exercise_endings(experience)
	print("Dream flow checked: seven ordered cues, two station replies, journal/pause, all endings reachable")
	get_tree().quit()


func _exercise_endings(experience: Node) -> void:
	experience.set("_conversation_strain", 0)
	experience.set("_seen_story_cues", {"window": true, "sisters": true})
	experience.call("_ending_text")
	assert(experience.get("_dream_outcome") == "complete", "remembering the window and another cue must reach the complete ending")
	experience.set("_seen_story_cues", {})
	experience.call("_ending_text")
	assert(experience.get("_dream_outcome") == "unresolved", "missing the memory clues must reach the unresolved ending")
	experience.set("_conversation_strain", 4)
	experience.call("_ending_text")
	assert(experience.get("_dream_outcome") == "ruptured", "high conversation strain must reach the ruptured ending")
