extends Node

signal startRace
signal notify
signal spawnProjectile
signal spawnMissile
signal setUsername
signal setWinner
signal checkpointHit

enum Spells{
	MISSILE,
	BOOST,
	PARRY,
	BLAST,
	BIG_BLAST,
	MORTAR,
	NAILS,
	WALL
}

enum Cards{
	MISSILE,
	BOOST,
	PARRY,
	BLAST,
	MORTAR,
	NAILS,
	WALL
}

enum CameraType {
	DEFAULT,
	EXTERIOR,
	EXTERIOR_FARTHER,
	INTERIOR,
	TOP_DOWN,
	MAX,  # Represents the size of the CameraType enum.
}

enum RearCameraType{
	SMALL,
	BIG,
	HIDDEN
}

var currentRearCamera:RearCameraType = RearCameraType.SMALL
var currentCamera:CameraType = CameraType.EXTERIOR
var username:String = "Random Username"
var player_color:Color = Color.WHITE

const PROFILE_SAVE_PATH := "user://profile.cfg"

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PROFILE_SAVE_PATH) == OK:
		username = config.get_value("profile", "username", username)
		player_color = config.get_value("profile", "player_color", player_color)

func save_username(new_username: String) -> void:
	username = new_username
	var config := ConfigFile.new()
	config.load(PROFILE_SAVE_PATH)
	config.set_value("profile", "username", username)
	config.save(PROFILE_SAVE_PATH)

func save_player_color(new_color: Color) -> void:
	player_color = new_color
	var config := ConfigFile.new()
	config.load(PROFILE_SAVE_PATH)
	config.set_value("profile", "player_color", player_color)
	config.save(PROFILE_SAVE_PATH)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_home"):
		get_tree().change_scene_to_file("res://3DScens/main_3d.tscn")
	elif event.is_action_pressed("credits"):
		get_tree().change_scene_to_file("res://credits.tscn")

@rpc("any_peer", "call_local", "reliable")
func spawnWinnerCam(peerId:int):
	setWinner.emit(peerId)

@rpc("any_peer", "call_local", "reliable")
func updateCheckpoints(peerId:int):
	checkpointHit.emit(peerId)
