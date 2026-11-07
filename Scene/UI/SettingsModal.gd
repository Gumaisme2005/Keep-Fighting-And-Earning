class_name SettingsModal
extends Control

const UITheme = preload("res://Scene/UI/UITheme.gd")

signal closed()

var backdrop: ColorRect = null
var panel_container: PanelContainer = null

# FPS Controls
var fps_buttons: Dictionary = {} # mode -> Button
var fps_status_label: Label = null
var custom_fps_container: HBoxContainer = null
var custom_fps_slider: HSlider = null
var custom_fps_input: SpinBox = null

# Resolution & Window Controls
var res_option_button: OptionButton = null
var window_mode_buttons: Array[Button] = []
var vsync_buttons: Array[Button] = []

# Audio Controls
var master_slider: HSlider = null
var master_val_label: Label = null
var bgm_slider: HSlider = null
var bgm_val_label: Label = null
var sfx_slider: HSlider = null
var sfx_val_label: Label = null
var mute_toggle_btn: Button = null

# Temporary editing state before apply
var temp_fps_mode: String = "60"
var temp_custom_fps: int = 60
var temp_res_index: int = 0
var temp_window_mode: int = 0
var temp_vsync_mode: int = 1
var temp_master_vol: float = 1.0
var temp_bgm_vol: float = 0.8
var temp_sfx_vol: float = 0.9
var temp_is_muted: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_sync_from_manager()
	visible = false

func _process(_delta: float) -> void:
	if visible and fps_status_label != null:
		var curr_fps: int = Engine.get_frames_per_second()
		var cap_str: String = "Unlimited" if temp_fps_mode == "unlimited" else ("%d FPS" % (temp_custom_fps if temp_fps_mode == "custom" else int(temp_fps_mode)))
		fps_status_label.text = "Current Engine: %d FPS  |  Configured Target: %s" % [curr_fps, cap_str]

func _build_ui() -> void:
	# 1. Dark Backdrop to block click-throughs
	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.06, 0.85)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	# 2. Centered Modal Box
	panel_container = PanelContainer.new()
	panel_container.anchor_left = 0.5
	panel_container.anchor_right = 0.5
	panel_container.anchor_top = 0.5
	panel_container.anchor_bottom = 0.5
	panel_container.offset_left = -380.0
	panel_container.offset_right = 380.0
	panel_container.offset_top = -260.0
	panel_container.offset_bottom = 260.0
	panel_container.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_PANEL, UITheme.COLOR_GOLD_BORDER, 2, 6, 18, 14))
	add_child(panel_container)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	panel_container.add_child(main_vbox)

	# Header Row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	main_vbox.add_child(header)

	var title_lbl := Label.new()
	title_lbl.text = "SYSTEM CONFIGURATION: FPS, RESOLUTION & AUDIO"
	UITheme.style_header_label(title_lbl, 15, UITheme.COLOR_TEXT_GOLD)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	var close_btn := UITheme.create_danger_button("Close", "", Vector2(76, 28), 12)
	close_btn.pressed.connect(hide_modal)
	header.add_child(close_btn)

	# Scroll Container for Sections
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(content_vbox)

	# ==========================================
	# SECTION 1: FRAME RATE (FPS) CONFIGURATION
	# ==========================================
	var fps_card := PanelContainer.new()
	fps_card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER_MUTED, 1, 4, 12, 10))
	content_vbox.add_child(fps_card)

	var fps_vbox := VBoxContainer.new()
	fps_vbox.add_theme_constant_override("separation", 8)
	fps_card.add_child(fps_vbox)

	var fps_hdr := Label.new()
	fps_hdr.text = "1. FRAME RATE LIMIT (FPS CAP):"
	UITheme.style_header_label(fps_hdr, 13, UITheme.COLOR_TEXT_GOLD)
	fps_vbox.add_child(fps_hdr)

	# Buttons Row: 30, 60, 120, 144, Unlimited, Custom
	var fps_btn_row := HBoxContainer.new()
	fps_btn_row.add_theme_constant_override("separation", 6)
	fps_vbox.add_child(fps_btn_row)

	var modes: Array[String] = ["30", "60", "120", "144", "unlimited", "custom"]
	var mode_titles: Array[String] = ["30 FPS", "60 FPS", "120 FPS", "144 FPS", "UNLIMITED", "CUSTOM"]
	for i in range(modes.size()):
		var m: String = modes[i]
		var btn := UITheme.create_button(mode_titles[i], "", Vector2(0, 32), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 11)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func(): _select_fps_mode(m))
		fps_btn_row.add_child(btn)
		fps_buttons[m] = btn

	# Custom FPS slider & spinbox row
	custom_fps_container = HBoxContainer.new()
	custom_fps_container.add_theme_constant_override("separation", 8)
	fps_vbox.add_child(custom_fps_container)

	var c_lbl := Label.new()
	c_lbl.text = "Custom Cap:"
	c_lbl.add_theme_font_size_override("font_size", 12)
	c_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	custom_fps_container.add_child(c_lbl)

	custom_fps_slider = HSlider.new()
	custom_fps_slider.min_value = 20
	custom_fps_slider.max_value = 360
	custom_fps_slider.step = 1
	custom_fps_slider.value = 60
	custom_fps_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_fps_slider.value_changed.connect(func(val: float):
		if custom_fps_input != null and custom_fps_input.value != val:
			custom_fps_input.value = val
		temp_custom_fps = int(val)
	)
	custom_fps_container.add_child(custom_fps_slider)

	custom_fps_input = SpinBox.new()
	custom_fps_input.min_value = 20
	custom_fps_input.max_value = 360
	custom_fps_input.step = 1
	custom_fps_input.value = 60
	custom_fps_input.custom_minimum_size = Vector2(80, 28)
	custom_fps_input.value_changed.connect(func(val: float):
		if custom_fps_slider != null and custom_fps_slider.value != val:
			custom_fps_slider.value = val
		temp_custom_fps = int(val)
	)
	custom_fps_container.add_child(custom_fps_input)

	fps_status_label = Label.new()
	fps_status_label.add_theme_font_size_override("font_size", 11)
	fps_status_label.add_theme_color_override("font_color", Color(0.65, 0.90, 1.0))
	fps_vbox.add_child(fps_status_label)

	# ==========================================
	# SECTION 2: RESOLUTION & DISPLAY MODE
	# ==========================================
	var res_card := PanelContainer.new()
	res_card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER_MUTED, 1, 4, 12, 10))
	content_vbox.add_child(res_card)

	var res_vbox := VBoxContainer.new()
	res_vbox.add_theme_constant_override("separation", 8)
	res_card.add_child(res_vbox)

	var res_hdr := Label.new()
	res_hdr.text = "2. RESOLUTION & WINDOW MODE:"
	UITheme.style_header_label(res_hdr, 13, UITheme.COLOR_TEXT_GOLD)
	res_vbox.add_child(res_hdr)

	# Resolution Dropdown
	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 10)
	res_vbox.add_child(res_row)

	var res_lbl := Label.new()
	res_lbl.text = "Screen Resolution:"
	res_lbl.add_theme_font_size_override("font_size", 12)
	res_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	res_row.add_child(res_lbl)

	res_option_button = OptionButton.new()
	res_option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_option_button.custom_minimum_size = Vector2(240, 32)
	if get_node_or_null("/root/SettingsManager") != null:
		var labels: Array[String] = SettingsManager.RESOLUTION_LABELS
		for i in range(labels.size()):
			res_option_button.add_item(labels[i], i)
	else:
		res_option_button.add_item("1280 x 720 (720p HD)", 0)
		res_option_button.add_item("1920 x 1080 (1080p FHD)", 1)
	res_option_button.item_selected.connect(func(idx: int): temp_res_index = idx)
	res_row.add_child(res_option_button)

	# Window Mode Toggle Row
	var win_row := HBoxContainer.new()
	win_row.add_theme_constant_override("separation", 8)
	res_vbox.add_child(win_row)

	var win_lbl := Label.new()
	win_lbl.text = "Display Mode:"
	win_lbl.add_theme_font_size_override("font_size", 12)
	win_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	win_row.add_child(win_lbl)

	var w_titles: Array[String] = ["Windowed", "Borderless", "Fullscreen"]
	for i in range(w_titles.size()):
		var idx: int = i
		var btn := UITheme.create_button(w_titles[i], "", Vector2(0, 30), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 11)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func(): _select_window_mode(idx))
		win_row.add_child(btn)
		window_mode_buttons.append(btn)

	# V-Sync Toggle Row
	var vsync_row := HBoxContainer.new()
	vsync_row.add_theme_constant_override("separation", 8)
	res_vbox.add_child(vsync_row)

	var vsync_lbl := Label.new()
	vsync_lbl.text = "Vertical Sync (V-Sync):"
	vsync_lbl.add_theme_font_size_override("font_size", 12)
	vsync_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	vsync_row.add_child(vsync_lbl)

	var v_titles: Array[String] = ["Disabled", "Enabled", "Adaptive"]
	for i in range(v_titles.size()):
		var idx: int = i
		var btn := UITheme.create_button(v_titles[i], "", Vector2(0, 30), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 11)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func(): _select_vsync_mode(idx))
		vsync_row.add_child(btn)
		vsync_buttons.append(btn)

	# ==========================================
	# SECTION 3: AUDIO VOLUMES
	# ==========================================
	var audio_card := PanelContainer.new()
	audio_card.add_theme_stylebox_override("panel", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER_MUTED, 1, 4, 12, 10))
	content_vbox.add_child(audio_card)

	var audio_vbox := VBoxContainer.new()
	audio_vbox.add_theme_constant_override("separation", 8)
	audio_card.add_child(audio_vbox)

	var aud_hdr := Label.new()
	aud_hdr.text = "3. AUDIO & VOLUME CONTROL:"
	UITheme.style_header_label(aud_hdr, 13, UITheme.COLOR_TEXT_GOLD)
	audio_vbox.add_child(aud_hdr)

	# Master Volume
	var m_row := HBoxContainer.new()
	m_row.add_theme_constant_override("separation", 8)
	audio_vbox.add_child(m_row)

	var m_lbl := Label.new()
	m_lbl.text = "Master Volume:"
	m_lbl.custom_minimum_size = Vector2(100, 0)
	m_lbl.add_theme_font_size_override("font_size", 12)
	m_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	m_row.add_child(m_lbl)

	master_slider = HSlider.new()
	master_slider.min_value = 0.0
	master_slider.max_value = 1.0
	master_slider.step = 0.05
	master_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	master_slider.value_changed.connect(func(val: float):
		temp_master_vol = val
		master_val_label.text = "%d%%" % int(val * 100)
	)
	m_row.add_child(master_slider)

	master_val_label = Label.new()
	master_val_label.custom_minimum_size = Vector2(45, 0)
	master_val_label.add_theme_font_size_override("font_size", 12)
	master_val_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	m_row.add_child(master_val_label)

	# BGM Volume
	var bgm_row := HBoxContainer.new()
	bgm_row.add_theme_constant_override("separation", 8)
	audio_vbox.add_child(bgm_row)

	var b_lbl := Label.new()
	b_lbl.text = "Music (BGM):"
	b_lbl.custom_minimum_size = Vector2(100, 0)
	b_lbl.add_theme_font_size_override("font_size", 12)
	b_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	bgm_row.add_child(b_lbl)

	bgm_slider = HSlider.new()
	bgm_slider.min_value = 0.0
	bgm_slider.max_value = 1.0
	bgm_slider.step = 0.05
	bgm_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bgm_slider.value_changed.connect(func(val: float):
		temp_bgm_vol = val
		bgm_val_label.text = "%d%%" % int(val * 100)
	)
	bgm_row.add_child(bgm_slider)

	bgm_val_label = Label.new()
	bgm_val_label.custom_minimum_size = Vector2(45, 0)
	bgm_val_label.add_theme_font_size_override("font_size", 12)
	bgm_val_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	bgm_row.add_child(bgm_val_label)

	# SFX Volume
	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 8)
	audio_vbox.add_child(sfx_row)

	var s_lbl := Label.new()
	s_lbl.text = "Sound Effects:"
	s_lbl.custom_minimum_size = Vector2(100, 0)
	s_lbl.add_theme_font_size_override("font_size", 12)
	s_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
	sfx_row.add_child(s_lbl)

	sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_slider.value_changed.connect(func(val: float):
		temp_sfx_vol = val
		sfx_val_label.text = "%d%%" % int(val * 100)
	)
	sfx_row.add_child(sfx_slider)

	sfx_val_label = Label.new()
	sfx_val_label.custom_minimum_size = Vector2(45, 0)
	sfx_val_label.add_theme_font_size_override("font_size", 12)
	sfx_val_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	sfx_row.add_child(sfx_val_label)

	# Mute Button Row
	var mute_row := HBoxContainer.new()
	mute_row.add_theme_constant_override("separation", 8)
	audio_vbox.add_child(mute_row)

	mute_toggle_btn = UITheme.create_button("Audio: Active", "", Vector2(160, 30), UITheme.COLOR_GOLD_BORDER, UITheme.COLOR_BG_DARK, 11)
	mute_toggle_btn.pressed.connect(func():
		temp_is_muted = not temp_is_muted
		_update_mute_button_label()
	)
	mute_row.add_child(mute_toggle_btn)

	# ==========================================
	# SECTION 4: FOOTER ACTIONS
	# ==========================================
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	main_vbox.add_child(footer)

	var reset_btn := UITheme.create_button("Reset Defaults", "", Vector2(130, 34), Color(0.65, 0.65, 0.65), UITheme.COLOR_BG_DARK, 12)
	reset_btn.pressed.connect(_on_reset_defaults_pressed)
	footer.add_child(reset_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	var apply_btn := UITheme.create_button("APPLY & SAVE SETTINGS", "", Vector2(210, 36), Color(0.35, 0.85, 0.45), Color(0.08, 0.22, 0.12, 0.95), 13)
	apply_btn.pressed.connect(_on_apply_pressed)
	footer.add_child(apply_btn)

	var cancel_btn := UITheme.create_danger_button("Close", "", Vector2(90, 36), 12)
	cancel_btn.pressed.connect(hide_modal)
	footer.add_child(cancel_btn)

# --- SELECTION HIGHLIGHTS ---

func _select_fps_mode(mode: String) -> void:
	temp_fps_mode = mode
	for k in fps_buttons.keys():
		var b: Button = fps_buttons[k]
		if k == mode:
			b.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
			b.add_theme_stylebox_override("normal", UITheme.make_panel_style(Color(0.20, 0.16, 0.08, 0.95), UITheme.COLOR_GOLD_BORDER_HOVER, 2, 4, 8, 4))
		else:
			b.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
			b.add_theme_stylebox_override("normal", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER, 1, 4, 8, 4))
	if custom_fps_container != null:
		custom_fps_container.visible = (mode == "custom")

func _select_window_mode(idx: int) -> void:
	temp_window_mode = idx
	for i in range(window_mode_buttons.size()):
		var b := window_mode_buttons[i]
		if i == idx:
			b.add_theme_color_override("font_color", Color(0.60, 0.90, 1.0))
			b.add_theme_stylebox_override("normal", UITheme.make_panel_style(Color(0.08, 0.16, 0.24, 0.95), Color(0.45, 0.75, 1.0), 2, 4, 8, 4))
		else:
			b.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
			b.add_theme_stylebox_override("normal", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER, 1, 4, 8, 4))

func _select_vsync_mode(idx: int) -> void:
	temp_vsync_mode = idx
	for i in range(vsync_buttons.size()):
		var b := vsync_buttons[i]
		if i == idx:
			b.add_theme_color_override("font_color", Color(0.60, 0.90, 1.0))
			b.add_theme_stylebox_override("normal", UITheme.make_panel_style(Color(0.08, 0.16, 0.24, 0.95), Color(0.45, 0.75, 1.0), 2, 4, 8, 4))
		else:
			b.add_theme_color_override("font_color", UITheme.COLOR_TEXT_PRIMARY)
			b.add_theme_stylebox_override("normal", UITheme.make_panel_style(UITheme.COLOR_BG_DARK, UITheme.COLOR_GOLD_BORDER, 1, 4, 8, 4))

func _update_mute_button_label() -> void:
	if mute_toggle_btn != null:
		if temp_is_muted:
			mute_toggle_btn.text = "Audio: MUTED"
			mute_toggle_btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		else:
			mute_toggle_btn.text = "Audio: ACTIVE"
			mute_toggle_btn.add_theme_color_override("font_color", Color(0.45, 1.0, 0.65))

# --- SYNC DATA ---

func _sync_from_manager() -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm != null:
		temp_fps_mode = sm.fps_mode
		temp_custom_fps = sm.custom_fps
		temp_res_index = sm.resolution_index
		temp_window_mode = sm.window_mode_index
		temp_vsync_mode = sm.vsync_mode_index
		temp_master_vol = sm.master_volume
		temp_bgm_vol = sm.bgm_volume
		temp_sfx_vol = sm.sfx_volume
		temp_is_muted = sm.is_muted
	else:
		temp_fps_mode = "60"
		temp_custom_fps = 60
		temp_res_index = 0
		temp_window_mode = 0
		temp_vsync_mode = 1
		temp_master_vol = 1.0
		temp_bgm_vol = 0.8
		temp_sfx_vol = 0.9
		temp_is_muted = false

	_select_fps_mode(temp_fps_mode)
	if custom_fps_slider != null: custom_fps_slider.value = temp_custom_fps
	if custom_fps_input != null: custom_fps_input.value = temp_custom_fps

	if res_option_button != null:
		res_option_button.selected = temp_res_index

	_select_window_mode(temp_window_mode)
	_select_vsync_mode(temp_vsync_mode)

	if master_slider != null: master_slider.value = temp_master_vol
	if master_val_label != null: master_val_label.text = "%d%%" % int(temp_master_vol * 100)

	if bgm_slider != null: bgm_slider.value = temp_bgm_vol
	if bgm_val_label != null: bgm_val_label.text = "%d%%" % int(temp_bgm_vol * 100)

	if sfx_slider != null: sfx_slider.value = temp_sfx_vol
	if sfx_val_label != null: sfx_val_label.text = "%d%%" % int(temp_sfx_vol * 100)

	_update_mute_button_label()

# --- ACTIONS ---

func _on_apply_pressed() -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm != null:
		sm.set_fps_mode(temp_fps_mode, temp_custom_fps)
		sm.set_resolution_index(temp_res_index)
		sm.set_window_mode(temp_window_mode)
		sm.set_vsync_mode(temp_vsync_mode)
		sm.set_audio_volumes(temp_master_vol, temp_bgm_vol, temp_sfx_vol, temp_is_muted)
	hide_modal()

func _on_reset_defaults_pressed() -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm != null:
		sm.reset_to_defaults()
	_sync_from_manager()

func show_modal() -> void:
	_sync_from_manager()
	visible = true
	move_to_front()

func hide_modal() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			hide_modal()
			get_viewport().set_input_as_handled()
