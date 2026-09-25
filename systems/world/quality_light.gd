class_name QualityLight
extends DirectionalLight3D
## Sun light that adapts shadows to the Graphics Quality setting.


func _ready() -> void:
	add_to_group("quality_listeners")
	apply_quality(Settings.graphics_quality)


func apply_quality(level: int) -> void:
	match level:
		Settings.Quality.LOW:
			shadow_enabled = false
		Settings.Quality.MEDIUM:
			shadow_enabled = true
			directional_shadow_max_distance = 35.0
			directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		_:
			shadow_enabled = true
			directional_shadow_max_distance = 60.0
			directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
