extends "res://scripts/sanctuary_runtime_v4.gd"

const APP_VERSION = "1.0.0-production-candidate"
const PRIVACY_SUMMARY = "Hippo OS stores sanctuary progress locally on this device. The launch build has no ads, no analytics, no account requirement, and no personal-data transmission."
const CREDITS_SUMMARY = "Animal audio\n• Hippo field recording: toadie, Freesound, CC0 1.0\n• Pig grunt: erdie, CC BY 3.0\n• Dog natural recording: soerena, Public Domain\n• Dog bark: Edo.pt2, CC0 1.0\n\nProduction tooling\n• anyCreature procedural creature compiler, MIT License, pinned at build time\n• Mochi, Truffle and Bao model specifications are original Hippo OS assets.\n\nOriginal Hippo OS audio\n• Footsteps, splashes, mud, eating, drinking, UI and sanctuary ambience are generated specifically for Hippo OS."

var about_overlay
var credits_overlay
var onboarding_overlay
var reset_dialog
var text_scale_slider
var ambience_player
var ui_click_player

func _ready():
    super()
    _build_launch_extras()
    _build_release_audio()
    _wire_button_sounds(ui_layer)
    _apply_text_scale()
    if not bool(sanctuary.settings.get("onboarding_complete", false)):
        onboarding_overlay.visible = true

func _notification(what):
    if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _save_sanctuary()
    elif what == NOTIFICATION_WM_CLOSE_REQUEST:
        _save_sanctuary()
        get_tree().quit()
    elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
        if credits_overlay != null and credits_overlay.visible:
            credits_overlay.visible = false
        elif about_overlay != null and about_overlay.visible:
            about_overlay.visible = false
        elif settings_overlay != null and settings_overlay.visible:
            settings_overlay.visible = false
        elif journal_overlay != null and journal_overlay.visible:
            journal_overlay.visible = false
        else:
            _save_sanctuary()
            get_tree().quit()

func _build_launch_extras():
    _add_about_button()
    _upgrade_settings_card()
    _build_about_overlay()
    _build_credits_overlay()
    _build_onboarding_overlay()
    _build_reset_dialog()

func _build_release_audio():
    ambience_player = AudioStreamPlayer.new()
    ambience_player.name = "SanctuaryAmbience"
    ambience_player.bus = "Ambience"
    var ambience_path = "res://assets/audio/sanctuary_ambience.wav"
    if ResourceLoader.exists(ambience_path):
        ambience_player.stream = load(ambience_path)
        ambience_player.finished.connect(_restart_ambience)
        add_child(ambience_player)
        ambience_player.play()
    else:
        push_error("Production sanctuary ambience missing")

    ui_click_player = AudioStreamPlayer.new()
    ui_click_player.name = "UIAudio"
    ui_click_player.bus = "UI"
    var click_path = "res://assets/audio/ui_click.wav"
    if ResourceLoader.exists(click_path):
        ui_click_player.stream = load(click_path)
    else:
        push_error("Production UI audio missing")
    add_child(ui_click_player)

func _restart_ambience():
    if ambience_player != null and ambience_player.stream != null:
        ambience_player.play()

func _wire_button_sounds(node):
    if node is BaseButton:
        node.pressed.connect(_play_ui_click)
    for child in node.get_children():
        _wire_button_sounds(child)

func _play_ui_click():
    if ui_click_player != null and ui_click_player.stream != null:
        ui_click_player.pitch_scale = randf_range(0.98, 1.02)
        ui_click_player.play()

func _add_about_button():
    var button = Button.new()
    button.text = "ABOUT"
    button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    button.offset_left = -335
    button.offset_top = 30
    button.offset_right = -185
    button.offset_bottom = 88
    button.pressed.connect(_toggle_about)
    info_panel.add_child(button)

func _upgrade_settings_card():
    if settings_overlay == null or settings_overlay.get_child_count() == 0:
        return
    var card = settings_overlay.get_child(0)
    if card is Control:
        card.offset_top = -335
        card.offset_bottom = 335
    for child in card.get_children():
        if child is Label and "development build" in str(child.text):
            child.text = "Hippo OS %s\nPrivate offline sanctuary • no ads • no account required" % APP_VERSION
    var row = HBoxContainer.new()
    var label = Label.new()
    label.text = "Text size"
    label.custom_minimum_size = Vector2(200, 0)
    row.add_child(label)
    text_scale_slider = HSlider.new()
    text_scale_slider.min_value = 0.90
    text_scale_slider.max_value = 1.30
    text_scale_slider.step = 0.05
    text_scale_slider.value = float(sanctuary.settings.get("text_scale", 1.0))
    text_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    text_scale_slider.value_changed.connect(_on_text_scale)
    row.add_child(text_scale_slider)
    card.add_child(row)
    var privacy_button = Button.new()
    privacy_button.text = "ABOUT & PRIVACY"
    privacy_button.pressed.connect(_toggle_about)
    card.add_child(privacy_button)
    var credits_button = Button.new()
    credits_button.text = "CREDITS & LICENSES"
    credits_button.pressed.connect(_toggle_credits)
    card.add_child(credits_button)
    var reset_button = Button.new()
    reset_button.text = "RESET SANCTUARY DATA"
    reset_button.pressed.connect(_request_reset)
    card.add_child(reset_button)

func _build_about_overlay():
    about_overlay = ColorRect.new()
    about_overlay.color = Color(0.008, 0.015, 0.013, 0.985)
    about_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    about_overlay.visible = false
    ui_layer.add_child(about_overlay)
    var card = VBoxContainer.new()
    card.set_anchors_preset(Control.PRESET_CENTER)
    card.offset_left = -360
    card.offset_top = -260
    card.offset_right = 360
    card.offset_bottom = 260
    card.add_theme_constant_override("separation", 18)
    about_overlay.add_child(card)
    var title = Label.new()
    title.text = "HIPPO OS"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 34)
    card.add_child(title)
    var version = Label.new()
    version.text = "Version %s" % APP_VERSION
    version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card.add_child(version)
    var description = Label.new()
    description.text = "A private living sanctuary for a baby pygmy hippo, pig, and Chinese Shar-Pei. Each animal has species-specific behaviour, needs, memory, preferences, and an evolving relationship with you."
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card.add_child(description)
    var privacy_title = Label.new()
    privacy_title.text = "Privacy"
    privacy_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    privacy_title.add_theme_font_size_override("font_size", 22)
    card.add_child(privacy_title)
    var privacy = Label.new()
    privacy.text = PRIVACY_SUMMARY
    privacy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    privacy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card.add_child(privacy)
    var close = Button.new()
    close.text = "BACK TO SANCTUARY"
    close.custom_minimum_size = Vector2(0, 60)
    close.pressed.connect(_toggle_about)
    card.add_child(close)

func _build_credits_overlay():
    credits_overlay = ColorRect.new()
    credits_overlay.color = Color(0.008, 0.015, 0.013, 0.99)
    credits_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    credits_overlay.visible = false
    ui_layer.add_child(credits_overlay)
    var panel = VBoxContainer.new()
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.offset_left = -430
    panel.offset_top = -300
    panel.offset_right = 430
    panel.offset_bottom = 300
    panel.add_theme_constant_override("separation", 14)
    credits_overlay.add_child(panel)
    var title = Label.new()
    title.text = "CREDITS & LICENSES"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    panel.add_child(title)
    var credits = Label.new()
    credits.text = CREDITS_SUMMARY
    credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    credits.add_theme_font_size_override("font_size", 16)
    panel.add_child(credits)
    var close = Button.new()
    close.text = "BACK"
    close.custom_minimum_size = Vector2(0, 58)
    close.pressed.connect(_toggle_credits)
    panel.add_child(close)

func _build_onboarding_overlay():
    onboarding_overlay = ColorRect.new()
    onboarding_overlay.color = Color(0.012, 0.028, 0.023, 0.995)
    onboarding_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    onboarding_overlay.visible = false
    ui_layer.add_child(onboarding_overlay)
    var card = VBoxContainer.new()
    card.set_anchors_preset(Control.PRESET_CENTER)
    card.offset_left = -390
    card.offset_top = -250
    card.offset_right = 390
    card.offset_bottom = 250
    card.add_theme_constant_override("separation", 20)
    onboarding_overlay.add_child(card)
    var title = Label.new()
    title.text = "WELCOME TO HIPPO OS"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 38)
    card.add_child(title)
    var subtitle = Label.new()
    subtitle.text = "Your private living sanctuary"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 22)
    card.add_child(subtitle)
    var body = Label.new()
    body.text = "Mochi, Truffle and Bao are not three versions of the same pet. Their species biology, temperament, needs and memories influence what they choose to do. Feed them, spend time with them, watch their routines develop, and respect when they choose space."
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card.add_child(body)
    var note = Label.new()
    note.text = "No account • No ads • Local private progress"
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card.add_child(note)
    var start = Button.new()
    start.text = "ENTER SANCTUARY"
    start.custom_minimum_size = Vector2(0, 70)
    start.add_theme_font_size_override("font_size", 22)
    start.pressed.connect(_complete_onboarding)
    card.add_child(start)

func _build_reset_dialog():
    reset_dialog = ConfirmationDialog.new()
    reset_dialog.title = "Reset sanctuary?"
    reset_dialog.dialog_text = "This permanently clears animal names, bond, learned preferences, journal history, and sanctuary settings on this device. This cannot be undone."
    reset_dialog.ok_button_text = "RESET EVERYTHING"
    reset_dialog.cancel_button_text = "CANCEL"
    reset_dialog.confirmed.connect(_reset_sanctuary)
    ui_layer.add_child(reset_dialog)

func _toggle_about():
    about_overlay.visible = not about_overlay.visible
    if about_overlay.visible and settings_overlay != null:
        settings_overlay.visible = false

func _toggle_credits():
    credits_overlay.visible = not credits_overlay.visible
    if credits_overlay.visible and settings_overlay != null:
        settings_overlay.visible = false

func _complete_onboarding():
    sanctuary.settings["onboarding_complete"] = true
    onboarding_overlay.visible = false
    sanctuary.add_journal_event("system", "sanctuary", "The sanctuary story began.", 1.0)
    _save_sanctuary()

func _request_reset():
    if reset_dialog != null:
        reset_dialog.popup_centered(Vector2i(620, 260))

func _reset_sanctuary():
    _save_sanctuary()
    if FileAccess.file_exists("user://sanctuary_save.json"):
        DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sanctuary_save.json"))
    get_tree().reload_current_scene()

func _on_text_scale(value):
    sanctuary.settings["text_scale"] = clamp(float(value), 0.90, 1.30)
    _apply_text_scale()
    _save_sanctuary()

func _apply_text_scale():
    if ui_layer == null:
        return
    var scale_value = clamp(float(sanctuary.settings.get("text_scale", 1.0)), 0.90, 1.30)
    _scale_text_recursive(ui_layer, scale_value)

func _scale_text_recursive(node, scale_value):
    if node is Label or node is BaseButton or node is LineEdit:
        if not node.has_meta("hippo_base_font_size"):
            node.set_meta("hippo_base_font_size", node.get_theme_font_size("font_size"))
        var base_size = int(node.get_meta("hippo_base_font_size"))
        node.add_theme_font_size_override("font_size", max(12, int(round(base_size * scale_value))))
    for child in node.get_children():
        _scale_text_recursive(child, scale_value)
