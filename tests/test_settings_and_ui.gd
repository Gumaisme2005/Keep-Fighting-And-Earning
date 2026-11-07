extends Node2D

const SettingsManagerScript = preload("res://Scene/SettingsManager.gd")
const SettingsModalScript = preload("res://Scene/UI/SettingsModal.gd")
const MainMenuScript = preload("res://Menu/main menu/main_menu.gd")
const PauseMenuScript = preload("res://Menu/pause menu/pause_menu.gd")
const CharacterSelectScene = preload("res://Scene/UI/CharacterSelect.tscn")
const GameUIScene = preload("res://Scene/UI/GameUI.tscn")

var total_tests := 0
var passed_tests := 0
var failed_tests := 0

func _assert_test(condition: bool, test_name: String, detail: String = "") -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		print("  [FAIL] %s - %s" % [test_name, detail])

func _ready() -> void:
	print("==================================================================")
	print("  TEST SUITE: SETTINGS MANAGER, FPS/RES CONFIG & UI VERIFICATION")
	print("==================================================================")

	test_settings_manager_singleton()
	test_fps_modes_and_limits()
	test_resolution_and_window_modes()
	test_audio_settings()
	test_persistence_load_save()
	test_settings_modal_component()
	test_main_menu_settings_integration()
	test_pause_menu_layout_and_settings()
	test_character_select_margins_and_settings()
	test_game_ui_modal_and_tab_highlighting()

	print("\n------------------------------------------------------------------")
	print("RESULT: %d/%d PASSED (%d FAILED)" % [passed_tests, total_tests, failed_tests])
	print("==================================================================")

	if failed_tests > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func test_settings_manager_singleton() -> void:
	print("\n[TEST 1] Testing SettingsManager Autoload Singleton...")
	var sm = get_node_or_null("/root/SettingsManager")
	_assert_test(sm != null, "SettingsManager autoload is registered in tree")
	if sm == null:
		return

	_assert_test(SettingsManagerScript.RESOLUTIONS.size() == 6, "SettingsManager has 6 resolution presets (720p to 4K)")
	_assert_test(SettingsManagerScript.WINDOW_MODES.size() == 3, "SettingsManager has 3 window modes (Windowed, Borderless, Fullscreen)")
	_assert_test(SettingsManagerScript.VSYNC_MODES.size() == 3, "SettingsManager has 3 VSync modes (Disabled, Enabled, Adaptive)")

func test_fps_modes_and_limits() -> void:
	print("\n[TEST 2] Testing FPS Limit Configurations...")
	var sm = get_node_or_null("/root/SettingsManager")
	if sm == null:
		return

	# Preset: 30 FPS
	sm.set_fps_mode("30")
	_assert_test(sm.fps_mode == "30", "FPS Mode set to 30")
	_assert_test(Engine.max_fps == 30, "Engine.max_fps capped at 30")

	# Preset: 60 FPS
	sm.set_fps_mode("60")
	_assert_test(sm.fps_mode == "60", "FPS Mode set to 60")
	_assert_test(Engine.max_fps == 60, "Engine.max_fps capped at 60")

	# Preset: 120 FPS
	sm.set_fps_mode("120")
	_assert_test(sm.fps_mode == "120", "FPS Mode set to 120")
	_assert_test(Engine.max_fps == 120, "Engine.max_fps capped at 120")

	# Preset: 144 FPS
	sm.set_fps_mode("144")
	_assert_test(sm.fps_mode == "144", "FPS Mode set to 144")
	_assert_test(Engine.max_fps == 144, "Engine.max_fps capped at 144")

	# Preset: Unlimited (0)
	sm.set_fps_mode("unlimited")
	_assert_test(sm.fps_mode == "unlimited", "FPS Mode set to unlimited")
	_assert_test(Engine.max_fps == 0, "Engine.max_fps set to 0 (unlimited)")

	# Custom FPS: 165
	sm.set_fps_mode("custom", 165)
	_assert_test(sm.fps_mode == "custom" and sm.custom_fps == 165, "FPS Mode set to custom 165")
	_assert_test(Engine.max_fps == 165, "Engine.max_fps set to 165")

	# Custom FPS Clamping (min 20, max 360)
	sm.set_fps_mode("custom", 10)
	_assert_test(sm.custom_fps == 20 and Engine.max_fps == 20, "Custom FPS clamped to minimum 20")

	sm.set_fps_mode("custom", 500)
	_assert_test(sm.custom_fps == 360 and Engine.max_fps == 360, "Custom FPS clamped to maximum 360")

	# Reset to 60 for consistency
	sm.set_fps_mode("60")

func test_resolution_and_window_modes() -> void:
	print("\n[TEST 3] Testing Resolutions, Window Modes & VSync...")
	var sm = get_node_or_null("/root/SettingsManager")
	if sm == null:
		return

	# Resolution selection
	sm.set_resolution_index(3) # 1920x1080
	_assert_test(sm.resolution_index == 3, "Resolution set to index 3 (1080p)")
	var curr_res: Vector2i = sm.get_current_resolution()
	_assert_test(curr_res == Vector2i(1920, 1080), "Current resolution is 1920x1080")

	# Out of bounds safety
	sm.set_resolution_index(999)
	_assert_test(sm.resolution_index == 5, "Resolution index clamped to maximum preset (4K)")
	sm.set_resolution_index(-5)
	_assert_test(sm.resolution_index == 0, "Resolution index clamped to minimum preset (720p)")

	# Window Modes
	sm.set_window_mode(0) # Windowed
	_assert_test(sm.window_mode_index == 0, "Window mode set to Windowed (0)")
	sm.set_window_mode(1) # Borderless
	_assert_test(sm.window_mode_index == 1, "Window mode set to Borderless (1)")
	sm.set_window_mode(2) # Fullscreen
	_assert_test(sm.window_mode_index == 2, "Window mode set to Fullscreen (2)")
	sm.set_window_mode(0)

	# VSync Modes
	sm.set_vsync_mode(0) # Disabled
	_assert_test(sm.vsync_mode_index == 0, "VSync mode set to Disabled (0)")
	sm.set_vsync_mode(1) # Enabled
	_assert_test(sm.vsync_mode_index == 1, "VSync mode set to Enabled (1)")
	sm.set_vsync_mode(2) # Adaptive
	_assert_test(sm.vsync_mode_index == 2, "VSync mode set to Adaptive (2)")

func test_audio_settings() -> void:
	print("\n[TEST 4] Testing Audio Volume and Mute Controls...")
	var sm = get_node_or_null("/root/SettingsManager")
	if sm == null:
		return

	sm.set_audio_volumes(0.75, 0.50, 0.85, false)
	_assert_test(is_equal_approx(sm.master_volume, 0.75), "Master volume updated to 0.75")
	_assert_test(is_equal_approx(sm.bgm_volume, 0.50), "BGM volume updated to 0.50")
	_assert_test(is_equal_approx(sm.sfx_volume, 0.85), "SFX volume updated to 0.85")
	_assert_test(sm.is_muted == false, "Mute flag is false")

	sm.set_audio_volumes(1.5, -0.2, 0.9, true)
	_assert_test(is_equal_approx(sm.master_volume, 1.0), "Master volume clamped to 1.0")
	_assert_test(is_equal_approx(sm.bgm_volume, 0.0), "BGM volume clamped to 0.0")
	_assert_test(sm.is_muted == true, "Mute flag is true")

	# Reset
	sm.set_audio_volumes(1.0, 0.8, 0.9, false)

func test_persistence_load_save() -> void:
	print("\n[TEST 5] Testing Configuration Persistence (user://settings.cfg)...")
	var sm = get_node_or_null("/root/SettingsManager")
	if sm == null:
		return

	# Apply custom settings
	sm.set_fps_mode("144")
	sm.set_resolution_index(3) # 1080p
	sm.set_window_mode(1)
	sm.set_vsync_mode(0)
	sm.set_audio_volumes(0.85, 0.65, 0.95, false)
	sm.save_settings()

	# Alter state in-memory
	sm.fps_mode = "30"
	sm.resolution_index = 0
	sm.window_mode_index = 0
	sm.vsync_mode_index = 1
	sm.master_volume = 0.2
	sm.bgm_volume = 0.2
	sm.sfx_volume = 0.2

	# Reload from disk
	sm.load_settings()
	_assert_test(sm.fps_mode == "144", "Persisted FPS mode reloaded accurately (144)")
	_assert_test(sm.resolution_index == 3, "Persisted resolution index reloaded accurately (1080p)")
	_assert_test(sm.window_mode_index == 1, "Persisted window mode reloaded accurately (Borderless)")
	_assert_test(sm.vsync_mode_index == 0, "Persisted vsync mode reloaded accurately (Disabled)")
	_assert_test(is_equal_approx(sm.master_volume, 0.85), "Persisted master volume reloaded accurately (0.85)")
	_assert_test(is_equal_approx(sm.bgm_volume, 0.65), "Persisted BGM volume reloaded accurately (0.65)")
	_assert_test(is_equal_approx(sm.sfx_volume, 0.95), "Persisted SFX volume reloaded accurately (0.95)")

	# Reset to defaults and save
	sm.reset_to_defaults()
	sm.save_settings()
	_assert_test(sm.fps_mode == "60", "Defaults restored successfully (60 FPS)")

func test_settings_modal_component() -> void:
	print("\n[TEST 6] Testing SettingsModal UI Component...")
	var modal = SettingsModalScript.new()
	add_child(modal)

	_assert_test(modal.backdrop != null, "SettingsModal includes click-blocking backdrop")
	_assert_test(modal.fps_buttons.has("30") and modal.fps_buttons.has("60") and modal.fps_buttons.has("120") and modal.fps_buttons.has("144") and modal.fps_buttons.has("unlimited") and modal.fps_buttons.has("custom"), "SettingsModal has buttons for 30, 60, 120, 144, unlimited, custom")
	_assert_test(modal.res_option_button != null and modal.res_option_button.item_count == 6, "SettingsModal has resolution dropdown with 6 options")
	_assert_test(modal.window_mode_buttons.size() == 3, "SettingsModal has 3 window mode toggles")
	_assert_test(modal.vsync_buttons.size() == 3, "SettingsModal has 3 vsync toggles")
	_assert_test(modal.master_slider != null and modal.bgm_slider != null and modal.sfx_slider != null, "SettingsModal has volume sliders")

	modal.show_modal()
	_assert_test(modal.visible == true, "SettingsModal visible after show_modal()")

	modal.hide_modal()
	_assert_test(modal.visible == false, "SettingsModal hidden after hide_modal()")

	modal.queue_free()

func test_main_menu_settings_integration() -> void:
	print("\n[TEST 7] Testing MainMenu UI Integration...")
	var menu_scene = preload("res://Menu/main menu/main_menu.tscn")
	var menu = menu_scene.instantiate()
	add_child(menu)

	_assert_test(menu.modal_backdrop != null, "MainMenu has modal_backdrop")
	_assert_test(menu.settings_modal != null, "MainMenu has settings_modal instance")

	# Test opening settings modal
	menu._open_settings_modal()
	_assert_test(menu.modal_backdrop.visible == true, "MainMenu backdrop shown when modal opened")
	_assert_test(menu.settings_modal.visible == true, "MainMenu settings_modal shown")

	menu._close_all_modals()
	_assert_test(menu.modal_backdrop.visible == false, "MainMenu backdrop hidden after _close_all_modals")
	_assert_test(menu.settings_modal.visible == false, "MainMenu settings_modal hidden after _close_all_modals")

	menu.queue_free()

func test_pause_menu_layout_and_settings() -> void:
	print("\n[TEST 8] Testing PauseMenu 2-Column Layout & Settings...")
	var pause_scene = preload("res://Menu/pause menu/pause_menu.tscn")
	var pause = pause_scene.instantiate()
	add_child(pause)

	_assert_test(pause.settings_modal != null, "PauseMenu has settings_modal instance")
	_assert_test(pause.card_panel != null, "PauseMenu has unified card_panel container (prevents title overlap)")
	_assert_test(pause.guide_backdrop != null, "PauseMenu has guide_backdrop click blocker")

	pause.settings_modal.show_modal()
	_assert_test(pause.settings_modal.visible == true, "PauseMenu settings modal opens cleanly")

	pause._close_all_submodals()
	_assert_test(pause.settings_modal.visible == false, "PauseMenu submodals close cleanly")

	# Test Pause Guide / Lore modal
	pause._show_pause_guide("lore")
	_assert_test(pause.guide_modal.visible == true, "PauseMenu lore modal opens cleanly")
	_assert_test(pause.guide_backdrop.visible == true, "PauseMenu lore modal darkens backdrop")
	_assert_test(pause.guide_body_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "PauseMenu lore text has word smart wrap enabled")

	pause._close_all_submodals()
	_assert_test(pause.guide_modal.visible == false and pause.guide_backdrop.visible == false, "PauseMenu lore modal closes cleanly")

	pause.queue_free()

func test_character_select_margins_and_settings() -> void:
	print("\n[TEST 9] Testing CharacterSelect Layout Margins, Fixed Box & Word Wrap...")
	var cs = CharacterSelectScene.instantiate()
	add_child(cs)

	_assert_test(cs.settings_modal != null, "CharacterSelect has settings_modal instance")
	var margin_container = cs.get_node_or_null("PanelContainer/MarginContainer") as MarginContainer
	_assert_test(margin_container != null, "CharacterSelect MarginContainer exists")
	if margin_container != null:
		var top_m = margin_container.get_theme_constant("margin_top")
		var bot_m = margin_container.get_theme_constant("margin_bottom")
		_assert_test(top_m <= 16 and bot_m <= 16, "CharacterSelect margins tightened to <= 16px to prevent 720p vertical clipping")

	_assert_test(cs.dossier_scroll != null, "CharacterSelect has fixed dossier_scroll container")
	_assert_test(cs.dossier_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "dossier_scroll disables horizontal scroll to prevent horizontal text overflow")

	_assert_test(cs.skill_q_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "skill_q_label has AUTOWRAP_WORD_SMART")
	_assert_test(cs.skill_rmb_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "skill_rmb_label has AUTOWRAP_WORD_SMART")
	_assert_test(cs.hero_controls_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "hero_controls_label has AUTOWRAP_WORD_SMART")
	_assert_test(cs.hero_tactics_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "hero_tactics_label has AUTOWRAP_WORD_SMART")
	_assert_test(cs.hero_lore_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "hero_lore_label has AUTOWRAP_WORD_SMART")
	_assert_test(cs.hero_origin_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "hero_origin_label has AUTOWRAP_WORD_SMART")

	# Test selecting hero 7 (Luong Tho) with extensive text
	cs.selected_index = 7
	cs._update_hero_info_display()
	_assert_test(cs.hero_name_label.text.contains("LUONG THO") or cs.hero_name_label.text.contains("LƯƠNG THƠ"), "Hero 7 details displayed")
	_assert_test(cs.dossier_scroll.scroll_vertical == 0, "dossier_scroll resets scroll position to top upon hero selection")

	cs.queue_free()

func test_game_ui_modal_and_tab_highlighting() -> void:
	print("\n[TEST 10] Testing GameUI SettingsModal & Guide Tab Highlighting...")
	var gui = GameUIScene.instantiate()
	add_child(gui)

	_assert_test(gui.settings_modal != null, "GameUI has settings_modal instance")
	_assert_test(gui.modal_dimmer != null, "GameUI has modal_dimmer click blocker")
	_assert_test(gui.guide_tab_buttons.size() == 3, "GameUI has 3 guide tab buttons (controls, hero, lore)")

	# Toggle guide modal
	gui.toggle_guide_modal()
	_assert_test(gui.guide_modal.visible == true, "GameUI guide_modal visible after toggle")
	_assert_test(gui.modal_dimmer.visible == true, "GameUI modal_dimmer visible when guide modal is open")

	# Test tab switching & highlighting
	gui._update_guide_modal_content("hero")
	_assert_test(gui.guide_active_tab == "hero", "Guide active tab switched to hero")
	gui._update_guide_modal_content("lore")
	_assert_test(gui.guide_active_tab == "lore", "Guide active tab switched to lore")
	gui._update_guide_modal_content("controls")
	_assert_test(gui.guide_active_tab == "controls", "Guide active tab switched to controls")

	# Toggle inventory modal: should close guide modal and open inventory
	gui.toggle_inventory_modal()
	_assert_test(gui.inventory_modal.visible == true, "GameUI inventory_modal visible")
	_assert_test(gui.guide_modal.visible == false, "GameUI guide_modal closed when inventory toggled")
	_assert_test(gui.modal_dimmer.visible == true, "GameUI modal_dimmer remains visible while inventory is open")

	# Toggle settings modal: should close inventory and open settings
	gui.toggle_settings_modal()
	_assert_test(gui.settings_modal.visible == true, "GameUI settings_modal visible")
	_assert_test(gui.inventory_modal.visible == false, "GameUI inventory_modal closed when settings toggled")
	_assert_test(gui.modal_dimmer.visible == true, "GameUI modal_dimmer visible for settings")

	# Close all modals
	gui._close_all_in_game_modals()
	_assert_test(gui.settings_modal.visible == false, "settings_modal closed")
	_assert_test(gui.inventory_modal.visible == false, "inventory_modal closed")
	_assert_test(gui.guide_modal.visible == false, "guide_modal closed")
	_assert_test(gui.modal_dimmer.visible == false, "modal_dimmer hidden when all modals closed")

	gui.queue_free()
