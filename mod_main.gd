# ==============================================================================
# Taj's Cheats - Main
# Author: TajemnikTV
# Description: Cheat utilities powered by Taj's Core.
# ==============================================================================
extends Node

const MOD_ID := "TajemnikTV-Cheats"
const LOG_NAME := "TajemnikTV-Cheats:Main"
const CORE_META_KEY := "TajsCore"
const CORE_MIN_VERSION := "1.1.0"
const NODE_LIMIT_SETTING_KEY := MOD_ID + ".node_limit"

const CheatManagerScript = preload("res://mods-unpacked/TajemnikTV-Cheats/extensions/scripts/cheat_manager.gd")

var _core
var _ui_manager
var _cheat_manager
var _settings_tab: VBoxContainer = null
var _hud_ready := false
var _settings_built := false
var _settings_retry_count := 0
var _node_limit_helpers = null
var _node_limit_label: Label = null
var _node_limit_slider: HSlider = null
var _node_limit_value_label: Label = null
var _node_label_update_timer := 0.0
var _node_label_last_text := ""
var _node_label_last_over := false

func _init() -> void:
	_core = _get_core()
	if _core == null:
		_log_warn("Taj's Core not found; Cheats disabled.")
		return
	if not _core.require(CORE_MIN_VERSION):
		_log_warn("Taj's Core %s+ required; Cheats disabled." % CORE_MIN_VERSION)
		return
	_register_module()
	_register_settings()
	_cheat_manager = CheatManagerScript.new()
	_cheat_manager.setup(_core)
	if _core.has_method("get"):
		_node_limit_helpers = _core.get("node_limit_helpers")
	_apply_saved_node_limit()
	_core.register_settings_tab(MOD_ID, "Cheats", "res://textures/icons/money.png")
	_register_events()

func _ready() -> void:
	call_deferred("_ensure_settings_tab")

func _process(delta: float) -> void:
	if _node_limit_label == null:
		return
	_node_label_update_timer += delta
	if _node_label_update_timer < 0.25:
		return
	_node_label_update_timer = 0.0
	_update_node_limit_label(false)

func _get_core():
	if Engine.has_meta(CORE_META_KEY):
		var core = Engine.get_meta(CORE_META_KEY)
		if core != null and core.has_method("require"):
			return core
	return null

func _register_module() -> void:
	if _core.has_method("register_module"):
		_core.register_module({
			"id": MOD_ID,
			"name": "Cheats",
			"version": _get_mod_version(),
			"min_core_version": CORE_MIN_VERSION
		})

func _register_settings() -> void:
	if _core == null or _core.settings == null:
		return
	_core.settings.register_schema(MOD_ID, {
		NODE_LIMIT_SETTING_KEY: {
			"type": "int",
			"default": Utils.MAX_WINDOW,
			"description": "Max nodes allowed (-1 for unlimited)."
		}
	})

func _register_events() -> void:
	if _core.event_bus != null:
		_core.event_bus.on("game.hud_ready", Callable(self, "_on_hud_ready"), self, true)
	call_deferred("_check_existing_hud")

func _check_existing_hud() -> void:
	if _hud_ready:
		return
	var root = get_tree().root if get_tree() != null else null
	if root == null:
		return
	var hud = root.get_node_or_null("Main/HUD")
	if hud != null:
		_on_hud_ready({})

func _on_hud_ready(_payload: Dictionary) -> void:
	if _hud_ready:
		return
	_hud_ready = true
	_ui_manager = _core.ui_manager if _core != null else null
	_ensure_settings_tab()

func _ensure_settings_tab() -> void:
	if _settings_built or _core == null:
		return
	if _ui_manager == null:
		_retry_settings_tab()
		return
	var container = _core.get_settings_tab(MOD_ID)
	if container == null:
		container = _core.register_settings_tab(MOD_ID, "Cheats", "res://textures/icons/money.png")
	if container == null:
		_retry_settings_tab()
		return
	_settings_tab = container
	_build_settings_ui(container)
	_settings_built = true

func _retry_settings_tab() -> void:
	_settings_retry_count += 1
	if _settings_retry_count > 10:
		return
	call_deferred("_ensure_settings_tab")

func _build_settings_ui(container: VBoxContainer) -> void:
	if _cheat_manager == null:
		return
	if _ui_manager != null:
		_ui_manager.add_section_header(container, "Cheats")
	_cheat_manager.build_cheats_tab(container)
	_build_node_limit_section(container)

func _build_node_limit_section(container: VBoxContainer) -> void:
	if _ui_manager != null:
		_ui_manager.add_separator(container)
		_ui_manager.add_section_header(container, "Node Limits")
	else:
		container.add_child(HSeparator.new())
		var header := Label.new()
		header.text = "Node Limits"
		header.add_theme_font_size_override("font_size", 32)
		container.add_child(header)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	container.add_child(row)

	_node_limit_label = Label.new()
	_node_limit_label.text = "Nodes: 0 / 0"
	_node_limit_label.add_theme_font_size_override("font_size", 24)
	_node_limit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_node_limit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_node_limit_label)

	var limit_box := VBoxContainer.new()
	limit_box.add_theme_constant_override("separation", 6)
	container.add_child(limit_box)

	var limit_header := HBoxContainer.new()
	limit_header.add_theme_constant_override("separation", 10)
	limit_box.add_child(limit_header)

	var limit_label := Label.new()
	limit_label.text = "Node Limit"
	limit_label.add_theme_font_size_override("font_size", 22)
	limit_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	limit_header.add_child(limit_label)

	_node_limit_value_label = Label.new()
	_node_limit_value_label.add_theme_font_size_override("font_size", 22)
	limit_header.add_child(_node_limit_value_label)

	_node_limit_slider = HSlider.new()
	_node_limit_slider.min_value = 50
	_node_limit_slider.max_value = 2050
	_node_limit_slider.step = 50
	_node_limit_slider.focus_mode = Control.FOCUS_NONE
	_node_limit_slider.value_changed.connect(func(v):
		var actual_val = -1 if v >= 2050 else int(v)
		_set_node_limit(actual_val, true)
	)
	limit_box.add_child(_node_limit_slider)

	_update_node_limit_label(true)

func _update_node_limit_label(force: bool) -> void:
	if _node_limit_label == null:
		return
	var count := 0
	var limit := _get_current_node_limit()
	var helper = _get_node_limit_helpers()
	if helper != null and helper.has_method("get_node_count"):
		count = helper.get_node_count()
	elif Globals != null and is_instance_valid(Globals):
		count = int(Globals.max_window_count)
	var limit_text := _format_limit_label(limit)
	var text := "Nodes: %d / %s" % [count, limit_text]
	if force or text != _node_label_last_text:
		_node_limit_label.text = text
		_node_label_last_text = text
	var over_limit := limit >= 0 and count >= limit
	if force or over_limit != _node_label_last_over:
		_node_label_last_over = over_limit
		var color := Color(1, 0.3, 0.3) if over_limit else Color(0.7, 0.7, 0.7)
		_node_limit_label.add_theme_color_override("font_color", color)
	_sync_node_limit_controls(limit, force)

func _apply_saved_node_limit() -> void:
	if _core == null or _core.settings == null:
		return
	var saved_limit = _core.settings.get_int(NODE_LIMIT_SETTING_KEY, Utils.MAX_WINDOW)
	_set_node_limit(saved_limit, false)

func _set_node_limit(limit: int, save: bool) -> void:
	var normalized := int(limit)
	if save and _core != null and _core.settings != null:
		_core.settings.set_value(NODE_LIMIT_SETTING_KEY, normalized)
	var helper = _get_node_limit_helpers()
	if helper != null and helper.has_method("set_node_limit"):
		helper.set_node_limit(normalized)
	_update_node_limit_label(true)

func _sync_node_limit_controls(limit: int, force: bool) -> void:
	if _node_limit_value_label != null:
		var label_text := _format_limit_label(limit)
		if force or _node_limit_value_label.text != label_text:
			_node_limit_value_label.text = label_text
	if _node_limit_slider != null:
		var slider_val = 2050.0 if limit < 0 else float(limit)
		if _node_limit_slider.has_method("set_value_no_signal"):
			if force or _node_limit_slider.value != slider_val:
				_node_limit_slider.set_value_no_signal(slider_val)
		else:
			if force or _node_limit_slider.value != slider_val:
				_node_limit_slider.value = slider_val

func _format_limit_label(limit: int) -> String:
	var helper = _get_node_limit_helpers()
	if helper != null and helper.has_method("get_limit_label"):
		return helper.get_limit_label(limit)
	return "Unlimited" if limit < 0 else str(limit)

func _get_current_node_limit() -> int:
	var helper = _get_node_limit_helpers()
	if helper != null and helper.has_method("get_node_limit"):
		return helper.get_node_limit()
	if _core != null and _core.settings != null:
		return _core.settings.get_int(NODE_LIMIT_SETTING_KEY, Utils.MAX_WINDOW)
	var globals_limit = _get_globals_custom_limit()
	if globals_limit != null:
		return int(globals_limit)
	return Utils.MAX_WINDOW

func _get_node_limit_helpers() -> Object:
	if _node_limit_helpers != null:
		return _node_limit_helpers
	if _core != null and _core.has_method("get"):
		_node_limit_helpers = _core.get("node_limit_helpers")
	return _node_limit_helpers

func _get_globals_custom_limit() -> Variant:
	if Globals == null:
		return null
	for prop in Globals.get_property_list():
		if prop is Dictionary and prop.get("name", "") == "custom_node_limit":
			return Globals.get("custom_node_limit")
	return null

func _get_mod_version() -> String:
	var manifest_path = get_script().resource_path.get_base_dir().path_join("manifest.json")
	if FileAccess.file_exists(manifest_path):
		var file := FileAccess.open(manifest_path, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var data = json.get_data()
				if data is Dictionary and data.has("version_number"):
					return str(data["version_number"])
	return "0.1.0"

func get_mod_name() -> String:
	return "Taj's Cheats"

func _log_warn(message: String) -> void:
	if _core != null and _core.has_method("logw"):
		_core.logw(MOD_ID, message)
	elif _has_global_class("ModLoaderLog"):
		ModLoaderLog.warning(message, LOG_NAME)
	else:
		print("%s %s" % [LOG_NAME, message])

static func _has_global_class(class_name_str: String) -> bool:
	for entry in ProjectSettings.get_global_class_list():
		if entry.get("class", "") == class_name_str:
			return true
	return false
