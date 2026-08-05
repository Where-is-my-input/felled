extends Node

# Strictly more than this fraction of connected players must have an active
# respawn vote (player.gd's has_voted_respawn, cast via the "respawn" input
# action and worn off after VOTE_RESPAWN_DURATION) for a respawn to trigger.
const VOTE_FRACTION_REQUIRED: float = 0.5

# After a respawn triggers, ignore the vote tally for this long — votes worn
# off or cleared this frame take a moment to replicate to every peer, so
# without this a majority that's still draining out of the tally could
# re-trigger a respawn one or two frames later.
const RETRIGGER_COOLDOWN: float = 1.0

var _has_checkpoint: bool = false
var _checkpoint_position: Vector2 = Vector2.ZERO
var _cooldown_timer: float = 0.0

func _ready() -> void:
	add_to_group("respawn_manager")

# Called (via RPC from checkpoint.gd) whenever any player reaches a
# checkpoint. "any_peer, call_local" so every peer's own copy of this node —
# there's no networked identity here beyond this node existing identically in
# every peer's copy of the level scene — ends up agreeing on the same target
# without needing a server round-trip.
@rpc("any_peer", "call_local", "reliable")
func record_checkpoint(checkpoint_position: Vector2) -> void:
	_checkpoint_position = checkpoint_position
	_has_checkpoint = true

# Runs independently on every peer, tallying the same replicated
# has_voted_respawn flags everyone else sees, so every peer reaches the same
# conclusion at roughly the same time without any central authority — each
# peer then only ever moves the one player it actually has authority over.
func _physics_process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		return

	var players: Array = get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return

	var vote_count: int = 0
	for player in players:
		if player.has_voted_respawn:
			vote_count += 1

	if vote_count <= players.size() * VOTE_FRACTION_REQUIRED:
		return

	_cooldown_timer = RETRIGGER_COOLDOWN
	for player in players:
		if not player.is_multiplayer_authority():
			continue
		player.respawn_to(_checkpoint_position if _has_checkpoint else player.find_spawn_position())
