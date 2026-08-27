extends Node

# Runtime-safe portrait presentation authority for the Android build.
# This deliberately avoids adding new shaders or high-density geometry. It fixes the
# phone evidence problems by correcting camera framing, companion staging, intrusive
# prototype props and oversized HUD chrome while preserving the proven sanctuary world.

const HERO_HOME := Vector3(-0.30, 0.80, 0.00)
const PIG_HOME := Vector3(-3.15, 0.72, 1.45)
const DOG_HOME := Vector3(-3.35, 0.75, -1.45)

var scene_root: Node3D
var roster: Node
var camera: Camera3D
var hud: Node
var hippo: CharacterBody3D
var pig: CharacterBody3D
var dog: CharacterBody3D
var ready_for_finish := false
var ui_timer := 0.0
var stage_timer := 0.0
var smoothed_focus := Vector3.ZERO
var focus_initialized := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    process_priority = 2000000
    set_process(false)
    call_deferred("_bind_when_ready")

func _bind_when_ready() -> void:
    for _attempt in range(540):
        var candidate := get_tree().current_scene
        var roster_candidate := get_node_or_null("/root/CompanionRoster")
        var hud_candidate := get_node_or_null("/root/SanctuaryHUD")
        if candidate is Node3D and roster_candidate != null and hud_candidate != null:
            scene_root = candidate as Node3D
            roster = roster_candidate
            hud = hud_candidate
            camera = _find_camera(scene_root)
            hippo = scene_root.find_child("BabyHippo", true, false) as CharacterBody3D
            pig = scene_root.find_child("PorkyPig", true, false) as CharacterBody3D
            dog = scene_root.find_child("BaoSharPei", true, false) as CharacterBody3D
            if camera != null and hippo != null and pig != null and dog != null:
                break
        await get_tree().process_frame

    if scene_root == null or roster == null or camera == null or hippo == null:
        push_warning("PortraitSanctuaryV2 could not bind to the live sanctuary")
        return

    # Let all asynchronous visual helpers finish before the final presentation pass.
    for _frame in range(42):
        await get_tree().process_frame

    _stage_companions(true)
    _hide_intrusive_prototype_geometry()
    _apply_stage_palette()
    _apply_compact_hud()
    ready_for_finish = true
    set_process(true)

func _process(delta: float) -> void:
    if not ready_for_finish or scene_root == null:
        return

    if camera == null or not is_instance_valid(camera):
        camera = _find_camera(scene_root)
        if camera == null:
            return

    _apply_camera_frame(delta)

    ui_timer -= delta
    if ui_timer <= 0.0:
        ui_timer = 0.35
        _apply_compact_hud()

    stage_timer -= delta
    if stage_timer <= 0.0:
        stage_timer = 0.45
        _stage_companions(false)
        _hide_intrusive_prototype_geometry()
        _apply_stage_palette()

func _apply_camera_frame(delta: float) -> void:
    if hud != null and bool(hud.get("bodycam_mode")):
        focus_initialized = false
        return

    var selected := _selected_node()
    if selected == null:
        selected = hippo
    if selected == null:
        return

    var desired_focus := selected.global_position + Vector3(0.0, 0.62, 0.0)
    if not focus_initialized:
        smoothed_focus = desired_focus
        focus_initialized = true
    else:
        smoothed_focus = smoothed_focus.lerp(desired_focus, clampf(delta * 7.5, 0.0, 1.0))

    # Procedural companion faces are authored toward +X. Moving the camera much closer
    # and above the subject produces a face-first wildlife portrait with the horizon in
    # the upper third instead of a screen dominated by empty sky.
    var desired_camera := smoothed_focus + Vector3(5.55, 2.05, 0.20)
    camera.global_position = camera.global_position.lerp(desired_camera, clampf(delta * 9.0, 0.0, 1.0))
    camera.look_at(smoothed_focus + Vector3(0.0, -0.10, 0.0), Vector3.UP)
    camera.fov = lerpf(camera.fov, 41.0, clampf(delta * 8.0, 0.0, 1.0))

    # Other camera helpers read these values. Keeping them aligned prevents a visible
    # jump when an interaction temporarily hands camera control back to the scene.
    scene_root.set("orbit_yaw", 1.52)
    scene_root.set("orbit_pitch", -0.20)
    scene_root.set("orbit_distance", 5.90)

func _stage_companions(initial: bool) -> void:
    if hippo == null:
        return

    if initial:
        hippo.position = HERO_HOME
        if pig != null:
            pig.position = PIG_HOME
            pig.velocity = Vector3.ZERO
        if dog != null:
            dog.position = DOG_HOME
            dog.velocity = Vector3.ZERO
        return

    # Supporting companions stay inside the narrow portrait camera cone while their
    # autonomous action, sound and animation systems remain active.
    if pig != null and pig.position.distance_to(PIG_HOME) > 1.20:
        pig.position = pig.position.lerp(PIG_HOME, 0.20)
    if dog != null and dog.position.distance_to(DOG_HOME) > 1.20:
        dog.position = dog.position.lerp(DOG_HOME, 0.20)
    if Vector2(hippo.position.x - HERO_HOME.x, hippo.position.z - HERO_HOME.z).length() > 1.55:
        hippo.position.x = lerpf(hippo.position.x, HERO_HOME.x, 0.12)
        hippo.position.z = lerpf(hippo.position.z, HERO_HOME.z, 0.12)

func _hide_intrusive_prototype_geometry() -> void:
    if scene_root == null:
        return
    _hide_intrusive_recursive(scene_root)

func _hide_intrusive_recursive(node: Node) -> void:
    if _belongs_to_animal(node):
        return

    if node is MeshInstance3D:
        var visual := node as MeshInstance3D
        if visual.mesh is CylinderMesh:
            var cylinder := visual.mesh as CylinderMesh
            var vertical_extent := cylinder.height * absf(visual.global_transform.basis.y.length())
            var radius := maxf(cylinder.top_radius, cylinder.bottom_radius)
            var horizontal_scale := maxf(visual.global_transform.basis.x.length(), visual.global_transform.basis.z.length())
            var horizontal_extent := radius * horizontal_scale
            if vertical_extent > 0.80 and horizontal_extent < 0.24:
                visual.visible = false

    for child in node.get_children():
        _hide_intrusive_recursive(child)

func _apply_stage_palette() -> void:
    if scene_root == null:
        return

    _tint_named_mesh("CleanGround", Color(0.105, 0.235, 0.075), 0.96)
    _tint_named_mesh("CleanHeroMudBank", Color(0.26, 0.18, 0.095), 0.94)
    _tint_named_mesh("CleanShallowWater", Color(0.055, 0.28, 0.30), 0.34)

    var ridges := scene_root.find_children("CleanDistantRidge", "MeshInstance3D", true, false)
    for i in range(ridges.size()):
        var ridge := ridges[i] as MeshInstance3D
        if ridge != null:
            var material := StandardMaterial3D.new()
            material.albedo_color = Color(0.16 + float(i % 2) * 0.025, 0.26 + float(i % 3) * 0.018, 0.11)
            material.roughness = 0.98
            ridge.material_override = material

func _tint_named_mesh(node_name: String, color: Color, roughness: float) -> void:
    var mesh := scene_root.find_child(node_name, true, false) as MeshInstance3D
    if mesh == null:
        return
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    mesh.material_override = material

func _apply_compact_hud() -> void:
    if hud == null:
        return

    var viewport := get_viewport().get_visible_rect()
    var safe := _safe_rect(viewport)
    if safe.size.y < safe.size.x:
        return

    var w := safe.size.x
    var h := safe.size.y
    var left := safe.position.x
    var top := safe.position.y
    var right := safe.end.x
    var bottom := safe.end.y
    var margin := maxf(12.0, w * 0.022)

    var companion_panel := hud.get("companion_panel") as Control
    var avatar_panel := hud.get("avatar_panel") as Control
    var avatar_label := hud.get("avatar_label") as Control
    var name_label := hud.get("name_label") as Control
    var species_label := hud.get("species_label") as Control
    var bond_bar := hud.get("bond_bar") as Control
    var hunger_bar := hud.get("hunger_bar") as Control
    var energy_bar := hud.get("energy_bar") as Control
    var brand_label := hud.get("brand_label") as Control
    var brand_subtitle := hud.get("brand_subtitle") as Control
    var status_panel := hud.get("status_panel") as Control
    var time_label := hud.get("time_label") as Control
    var weather_label := hud.get("weather_label") as Control
    var menu_button := hud.get("menu_button") as Control
    var minimap_panel := hud.get("minimap_panel") as Control
    var minimap := hud.get("minimap") as Control
    var location_label := hud.get("location_label") as Control
    var action_rail := hud.get("action_rail") as Control
    var orbit_panel := hud.get("orbit_panel") as Control
    var orbit_pad := hud.get("orbit_pad") as Control
    var bottom_chevron := hud.get("bottom_chevron") as Control
    var bottom_panel := hud.get("bottom_panel") as Control
    var bottom_nav := hud.get("bottom_nav") as Control

    if companion_panel != null:
        companion_panel.position = Vector2(left + margin, top + margin)
        companion_panel.size = Vector2(minf(242.0, w * 0.35), 124.0)
    if avatar_panel != null:
        avatar_panel.position = Vector2(12, 13)
        avatar_panel.size = Vector2(56, 56)
    if avatar_label != null:
        avatar_label.position = Vector2(0, 7)
        avatar_label.size = Vector2(56, 42)
    if name_label != null and companion_panel != null:
        name_label.position = Vector2(82, 10)
        name_label.size = Vector2(companion_panel.size.x - 92, 28)
    if species_label != null and companion_panel != null:
        species_label.position = Vector2(82, 36)
        species_label.size = Vector2(companion_panel.size.x - 92, 20)

    if companion_panel != null:
        var bar_width := maxf(84.0, companion_panel.size.x - 94.0)
        _set_control_rect(bond_bar, Vector2(82, 63), Vector2(bar_width, 11))
        _set_control_rect(hunger_bar, Vector2(82, 82), Vector2(bar_width, 11))
        _set_control_rect(energy_bar, Vector2(82, 101), Vector2(bar_width, 11))

    _set_control_rect(brand_label, Vector2(left + w * 0.5 - 88.0, top + margin), Vector2(176, 31))
    _set_control_rect(brand_subtitle, Vector2(left + w * 0.5 - 88.0, top + margin + 29.0), Vector2(176, 21))

    _set_control_rect(status_panel, Vector2(right - 146.0 - margin, top + margin), Vector2(146, 66))
    _set_control_rect(time_label, Vector2(12, 8), Vector2(80, 23))
    _set_control_rect(weather_label, Vector2(12, 33), Vector2(88, 18))
    _set_control_rect(menu_button, Vector2(102, 11), Vector2(34, 42))

    var map_size := minf(146.0, w * 0.215)
    _set_control_rect(minimap_panel, Vector2(right - map_size - margin, top + 90.0), Vector2(map_size, map_size))
    if minimap != null:
        minimap.position = Vector2(7, 7)
        minimap.size = Vector2(map_size - 14.0, map_size - 14.0)
    _set_control_rect(location_label, Vector2(right - map_size - margin - 2.0, top + 90.0 + map_size + 5.0), Vector2(map_size + 4.0, 38))

    if action_rail != null:
        action_rail.position = Vector2(right - 66.0 - margin, top + h * 0.47)
        action_rail.size = Vector2(66, 266)
        for child in action_rail.get_children():
            if child is Button:
                (child as Button).custom_minimum_size = Vector2(66, 56)

    if orbit_panel != null:
        var orbit_size := minf(108.0, w * 0.165)
        orbit_panel.size = Vector2(orbit_size, orbit_size)
        orbit_panel.position = Vector2(left + margin, bottom - orbit_size - 87.0)
    if orbit_pad != null and orbit_panel != null:
        orbit_pad.position = Vector2(8, 8)
        orbit_pad.size = orbit_panel.size - Vector2(16, 16)
        var cell := maxf(25.0, (orbit_pad.size.x - 8.0) / 3.0)
        for child in orbit_pad.get_children():
            if child is Button:
                (child as Button).custom_minimum_size = Vector2(cell, cell)

    if bottom_chevron != null:
        bottom_chevron.visible = false

    _set_control_rect(bottom_panel, Vector2(left + margin, bottom - 76.0), Vector2(w - margin * 2.0, 66.0))
    if bottom_nav != null and bottom_panel != null:
        bottom_nav.position = Vector2(6, 6)
        bottom_nav.size = bottom_panel.size - Vector2(12, 12)
        var nav_width := maxf(60.0, (bottom_nav.size.x - 12.0) / 5.0)
        for child in bottom_nav.get_children():
            if child is Button:
                (child as Button).custom_minimum_size = Vector2(nav_width, 52)

func _set_control_rect(control: Control, position: Vector2, size: Vector2) -> void:
    if control == null:
        return
    control.position = position
    control.size = size

func _selected_node() -> Node3D:
    if roster == null:
        return null
    var companions_variant: Variant = roster.get("companions")
    if typeof(companions_variant) != TYPE_DICTIONARY:
        return null
    var companions := companions_variant as Dictionary
    var species := str(roster.get("selected_species"))
    var data_variant: Variant = companions.get(species, {})
    if typeof(data_variant) != TYPE_DICTIONARY:
        return null
    var node := (data_variant as Dictionary).get("node") as Node3D
    return node if node != null and is_instance_valid(node) else null

func _belongs_to_animal(node: Node) -> bool:
    for animal in [hippo, pig, dog]:
        if animal != null and (node == animal or animal.is_ancestor_of(node)):
            return true
    return false

func _safe_rect(visible: Rect2) -> Rect2:
    var screen_size := DisplayServer.screen_get_size()
    var system_safe := DisplayServer.get_display_safe_area()
    if screen_size.x <= 0 or screen_size.y <= 0 or system_safe.size.x <= 0 or system_safe.size.y <= 0:
        return visible
    var scale := Vector2(visible.size.x / float(screen_size.x), visible.size.y / float(screen_size.y))
    return Rect2(Vector2(system_safe.position) * scale, Vector2(system_safe.size) * scale)

func _find_camera(node: Node) -> Camera3D:
    if node is Camera3D and (node as Camera3D).current:
        return node as Camera3D
    for child in node.get_children():
        var found := _find_camera(child)
        if found != null:
            return found
    return null
