extends Node3D

@export_file("*.png", "*.jpg", "*.jpeg", "*.hdr", "*.exr") var skybox_path: String = "res://assets/skyboxes_49.png"
@onready var world_environment: WorldEnvironment = $WorldEnvironment


func _ready() -> void:
	_apply_skybox()


func _apply_skybox() -> void:
	var image := Image.new()
	var error := image.load(skybox_path)
	if error != OK:
		push_error("Skybox load failed: %s (%d)" % [skybox_path, error])
		return

	var texture := ImageTexture.create_from_image(image)
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = texture

	var sky := Sky.new()
	sky.sky_material = panorama

	if world_environment.environment == null:
		world_environment.environment = Environment.new()

	world_environment.environment.background_mode = Environment.BG_SKY
	world_environment.environment.sky = sky
	world_environment.environment.fog_enabled = false
