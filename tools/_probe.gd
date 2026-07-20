extends Node

const LEVELS_TO_CAPTURE := ["worldcup_001", "worldcup_002", "worldcup_003"]


func _ready() -> void:
	await get_tree().process_frame
	var game_scene: PackedScene = load("res://src/scenes/Game.tscn")
	for level_id: String in LEVELS_TO_CAPTURE:
		LevelManager.set_pending_level(level_id)
		var game: Node = game_scene.instantiate()
		get_tree().root.add_child(game)
		await get_tree().create_timer(0.6).timeout
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("res://tools/_probe_%s.png" % level_id)
		game.queue_free()
		await get_tree().create_timer(0.2).timeout
	get_tree().quit()
