extends Node

var host
var rain: CPUParticles3D
var environment
var current_intensity := 0.0

func _ready():
    process_priority = 70
    for i in range(12):
        await get_tree().process_frame
    host = get_parent()
    if host == null:
        return
    environment = host.get("environment")
    _build_rain()

func _process(delta):
    if host == null:
        return
    var living_world = host.get("living_world")
    if living_world == null:
        return
    var climate = living_world.get("climate")
    if typeof(climate) != TYPE_DICTIONARY:
        return
    var cloudiness = clamp(float(climate.get("cloudiness", 0.0)), 0.0, 1.0)
    var humidity = clamp(float(climate.get("humidity", 0.0)), 0.0, 1.0)
    var target = clamp((cloudiness - 0.56) * 1.55 + (humidity - 0.62) * 1.30, 0.0, 1.0)
    current_intensity = lerp(current_intensity, target, min(delta * 0.45, 1.0))
    _update_rain()
    _update_fog()

func _build_rain():
    rain = CPUParticles3D.new()
    rain.name = "LivingRain"
    rain.amount = 420
    rain.lifetime = 1.35
    rain.preprocess = 0.5
    rain.emitting = false
    rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    rain.emission_box_extents = Vector3(13.0, 1.2, 13.0)
    rain.direction = Vector3(0.0, -1.0, 0.0)
    rain.spread = 4.0
    rain.initial_velocity_min = 12.0
    rain.initial_velocity_max = 18.0
    rain.gravity = Vector3.ZERO
    rain.visibility_aabb = AABB(Vector3(-16, -18, -16), Vector3(32, 22, 32))

    var drop = BoxMesh.new()
    drop.size = Vector3(0.010, 0.32, 0.010)
    var material = StandardMaterial3D.new()
    material.albedo_color = Color(0.72, 0.84, 0.90, 0.52)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.roughness = 0.25
    drop.material = material
    rain.draw_pass_1 = drop
    host.add_child(rain)

func _update_rain():
    if rain == null:
        return
    var camera = host.get("camera")
    if camera is Camera3D:
        rain.global_position = camera.global_position + Vector3(0.0, 6.5, 0.0)
    var should_emit = current_intensity > 0.075
    rain.emitting = should_emit
    if should_emit:
        rain.amount = clamp(int(round(120.0 + current_intensity * 720.0)), 120, 840)
        rain.initial_velocity_min = lerp(10.0, 15.0, current_intensity)
        rain.initial_velocity_max = lerp(15.0, 22.0, current_intensity)

func _update_fog():
    if environment == null:
        return
    var night = false
    if host.has_method("_effective_local_hour"):
        var hour = int(host.call("_effective_local_hour"))
        night = hour >= 19 or hour < 6
    var target_density = 0.0045 + current_intensity * 0.016 + (0.003 if night else 0.0)
    environment.fog_enabled = target_density > 0.004
    environment.fog_density = lerp(environment.fog_density, target_density, 0.035)
    environment.fog_height = 1.8
    environment.fog_height_density = 0.18
    environment.fog_light_color = Color(0.55, 0.62, 0.62) if not night else Color(0.20, 0.26, 0.34)
    environment.fog_light_energy = 0.60 if not night else 0.32
