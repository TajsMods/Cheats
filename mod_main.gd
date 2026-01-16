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

const CheatManagerScript = preload("res://mods-unpacked/TajemnikTV-Cheats/extensions/scripts/cheat_manager.gd")

var _core
var _ui_manager
var _cheat_manager
var _settings_tab: VBoxContainer = null
var _hud_ready := false
var _settings_built := false
var _settings_retry_count := 0

func _init() -> void:
	_core = _get_core()
	if _core == null:
		_log_warn("Taj's Core not found; Cheats disabled.")
		return
	if not _core.require(CORE_MIN_VERSION):
		_log_warn("Taj's Core %s+ required; Cheats disabled." % CORE_MIN_VERSION)
		return
	_register_module()
	_cheat_manager = CheatManagerScript.new()
	_cheat_manager.setup(_core)
	_core.register_settings_tab(MOD_ID, "Cheats", "res://textures/icons/money.png")
	_register_events()

func _ready() -> void:
	call_deferred("_ensure_settings_tab")

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
