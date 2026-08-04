# Project Rules

- Placeholder sprites: whenever a new node needs a visual and no real art exists yet, use the default Godot icon (`res://icon.svg`) on a `Sprite2D`, with `modulate` set to a random color at runtime (e.g. `modulate = Color(randf(), randf(), randf())` in `_ready()`) so multiple placeholder instances are visually distinguishable from each other.
