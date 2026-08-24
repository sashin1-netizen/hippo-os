extends Control

# Lightweight live minimap used by the production sanctuary HUD.
# It renders the actual companion positions from CompanionRoster rather than a static image.

const WORLD_MIN := Vector2(-6.2, -4.7)
const WORLD_MAX := Vector2(6.2, 4.7)
const POND_POS := Vector3(3.7, 0.0, 2.5)
const MUD_POS := Vector3(-3.7, 0.0, 2.8)

var scene_root: Node3D
var roster: Node
var refresh_timer := 0.0

func configure(scene: Node3D, roster_node: Node) -> void:
    scene_root = scene
    roster = roster_node
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    clip_contents = true
    set_process(true)
    queue_redraw()

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)

func _process(delta: float) -> void:
    refresh_timer -= delta
    if refresh_timer <= 0.0:
        refresh_timer = 0.12
        queue_redraw()

func _draw() -> void:
    var rect := Rect2(Vector2.ZERO, size)
    draw_rect(rect, Color(0.018, 0.035, 0.032, 0.92), true)
    draw_rect(rect.grow(-1.0), Color(0.24, 0.39, 0.31, 0.62), false, 1.2)

    var inset := Rect2(Vector2(8.0, 8.0), Vector2(maxf(1.0, size.x - 16.0), maxf(1.0, size.y - 16.0)))
    draw_rect(inset, Color(0.055, 0.115, 0.072, 0.86), true)

    for fraction in [0.25, 0.50, 0.75]:
        var x := lerpf(inset.position.x, inset.end.x, float(fraction))
        var y := lerpf(inset.position.y, inset.end.y, float(fraction))
        draw_line(Vector2(x, inset.position.y), Vector2(x, inset.end.y), Color(0.60, 0.75, 0.64, 0.10), 1.0)
        draw_line(Vector2(inset.position.x, y), Vector2(inset.end.x, y), Color(0.60, 0.75, 0.64, 0.10), 1.0)

    draw_circle(_world_to_map(POND_POS), minf(size.x, size.y) * 0.095, Color(0.12, 0.49, 0.62, 0.72))
    draw_circle(_world_to_map(MUD_POS), minf(size.x, size.y) * 0.060, Color(0.30, 0.19, 0.10, 0.74))

    if roster == null or not is_instance_valid(roster):
        return
    var companions_variant: Variant = roster.get("companions")
    if typeof(companions_variant) != TYPE_DICTIONARY:
        return
    var companions: Dictionary = companions_variant as Dictionary
    var selected := str(roster.get("selected_species"))

    var colors := {
        "hippo": Color(0.86, 0.57, 0.78),
        "pig": Color(0.98, 0.64, 0.59),
        "sharpei": Color(0.91, 0.64, 0.35)
    }
    for species in ["hippo", "pig", "sharpei"]:
        if not companions.has(species):
            continue
        var data_variant: Variant = companions.get(species)
        if typeof(data_variant) != TYPE_DICTIONARY:
            continue
        var data: Dictionary = data_variant as Dictionary
        var animal := data.get("node") as Node3D
        if animal == null or not is_instance_valid(animal):
            continue
        var point := _world_to_map(animal.global_position)
        var marker_color: Color = colors.get(species, Color.WHITE)
        draw_circle(point, 5.2, marker_color)
        if species == selected:
            draw_arc(point, 8.5, 0.0, TAU, 28, Color(0.94, 1.0, 0.96, 0.96), 1.7, true)

func _world_to_map(world_position: Vector3) -> Vector2:
    var usable := Vector2(maxf(1.0, size.x - 16.0), maxf(1.0, size.y - 16.0))
    var nx := inverse_lerp(WORLD_MIN.x, WORLD_MAX.x, world_position.x)
    var nz := inverse_lerp(WORLD_MIN.y, WORLD_MAX.y, world_position.z)
    return Vector2(8.0 + clampf(nx, 0.0, 1.0) * usable.x, 8.0 + (1.0 - clampf(nz, 0.0, 1.0)) * usable.y)
