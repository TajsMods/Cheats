extends RefCounted

const LOG_NAME := "TajemnikTV-Cheats:Cheats"

const CHEATS := [
    ["Money", "money", "res://textures/icons/money.png", false],
    ["Research", "research", "res://textures/icons/research.png", false],
    ["Corp Data", "corporation_data", "res://textures/icons/data.png", false],
    ["Gov Data", "government_data", "res://textures/icons/eye_ball.png", false],
    ["Hack Points", "hack_points", "res://textures/icons/star.png", true],
    ["Optimization", "optimization", "res://textures/icons/work.png", true],
    ["Application", "application", "res://textures/icons/bracket.png", true]
]

const MIN_AMOUNTS := {
    "money": 1000.0,
    "research": 100.0,
    "corporation_data": 100.0,
    "government_data": 100.0
}

const FIXED_VALUES := [1, 3, 5, 10]

var _core = null
var _economy = null

func setup(core) -> void:
    _core = core
    if _core != null and _core.has_method("get"):
        _economy = _core.get("economy_helpers")
    _log("Cheat manager initialized")

func build_cheats_tab(parent: Control) -> void:
    var warn := Label.new()
    warn.text = "WARNING: Cheats may affect game balance."
    warn.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
    warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    warn.autowrap_mode = TextServer.AUTOWRAP_WORD
    parent.add_child(warn)

    for cheat in CHEATS:
        _add_cheat_row(parent, cheat[0], cheat[1], cheat[2], cheat[3])

func _add_cheat_row(parent: Control, label_text: String, type: String, icon_path: String, is_attribute: bool) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    parent.add_child(row)

    var icon := TextureRect.new()
    if ResourceLoader.exists(icon_path):
        icon.texture = load(icon_path)
    icon.custom_minimum_size = Vector2(32, 32)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    row.add_child(icon)

    var label := Label.new()
    label.text = label_text
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.add_theme_font_size_override("font_size", 28)
    row.add_child(label)

    var cheat_type := type

    var btn_zero := Button.new()
    btn_zero.text = "Set 0"
    btn_zero.theme_type_variation = "TabButton"
    btn_zero.custom_minimum_size = Vector2(70, 50)
    btn_zero.pressed.connect(func(): set_to_zero(cheat_type, is_attribute))
    row.add_child(btn_zero)

    if is_attribute:
        for val in FIXED_VALUES:
            var btn := Button.new()
            btn.text = "+%d" % val
            btn.theme_type_variation = "TabButton"
            btn.custom_minimum_size = Vector2(70, 50)
            var v: int = val
            btn.pressed.connect(func(): add_fixed(cheat_type, v))
            row.add_child(btn)
    else:
        for pct in [-0.1, 0.1, 0.3, 0.5]:
            var btn := Button.new()
            btn.text = "%+d%%" % int(pct * 100)
            btn.theme_type_variation = "TabButton"
            btn.custom_minimum_size = Vector2(80, 50)
            var p: float = pct
            btn.pressed.connect(func(): modify_percent(cheat_type, p))
            row.add_child(btn)

func add_fixed(type: String, amount: int) -> void:
    var ok := false
    if _economy != null and _economy.has_method("add_attribute"):
        ok = _economy.add_attribute(type, amount)
    elif Attributes != null and Attributes.attributes.has(type):
        Attributes.attributes[type].add(amount, 0, 0, 0)
        _refresh_globals()
        ok = true

    if not ok:
        _log_warn("Attribute type not found: " + type)
        return

    var label = type.replace("_", " ").capitalize()
    _notify("check", "%s +%d" % [label, amount])
    _play_sound("click")

func modify_percent(type: String, percent: float) -> void:
    var ok := false
    var current_value: Variant = _get_currency(type)
    if current_value == null:
        _log_warn("Currency type not found: " + type)
        return

    var current: float = float(current_value)
    var amount_to_change := current * percent
    var min_amount_value: Variant = MIN_AMOUNTS.get(type, 1.0)
    var min_amount: float = float(min_amount_value)
    if percent > 0.0 and abs(amount_to_change) < min_amount:
        amount_to_change = min_amount

    if _economy != null and _economy.has_method("add_currency"):
        _economy.add_currency(type, amount_to_change, true)
        ok = true
    else:
        var new_value := float(current) + amount_to_change
        if new_value < 0.0:
            new_value = 0.0
        Globals.currencies[type] = new_value
        if type == "money":
            Globals.max_money = max(Globals.max_money, new_value)
        elif type == "research":
            Globals.max_research = max(Globals.max_research, new_value)
        _refresh_globals()
        ok = true

    if not ok:
        return

    var sign_str := "+" if percent > 0 else ""
    var label := type.replace("_", " ").capitalize()
    _notify("check", "%s %s%d%%" % [label, sign_str, int(percent * 100)])
    _play_sound("click")

func set_to_zero(type: String, is_attribute: bool = false) -> void:
    var ok := false
    if is_attribute:
        if _economy != null and _economy.has_method("set_attribute"):
            ok = _economy.set_attribute(type, 0.0)
        elif Attributes != null and Attributes.attributes.has(type):
            var current = Attributes.get_attribute(type)
            Attributes.attributes[type].add(-current, 0, 0, 0)
            _refresh_globals()
            ok = true
    else:
        if _economy != null and _economy.has_method("set_currency"):
            ok = _economy.set_currency(type, 0.0, true)
        elif Globals != null and Globals.currencies.has(type):
            Globals.currencies[type] = 0.0
            _refresh_globals()
            ok = true

    if not ok:
        _log_warn("%s type not found: %s" % ["Attribute" if is_attribute else "Currency", type])
        return

    var label := type.replace("_", " ").capitalize()
    _notify("check", "%s set to 0" % label)
    _play_sound("click")

func _get_currency(type: String) -> Variant:
    if _economy != null and _economy.has_method("get_currency"):
        if _economy.has_method("has_currency") and not _economy.has_currency(type):
            return null
        return _economy.get_currency(type, 0.0)
    if Globals != null and Globals.currencies.has(type):
        return Globals.currencies[type]
    return null

func _refresh_globals() -> void:
    if Globals != null and Globals.has_method("process"):
        Globals.process(0)

func _notify(icon: String, message: String) -> void:
    if _core != null and _core.has_method("notify"):
        _core.notify(icon, message)
        return
    var signals = _get_autoload("Signals")
    if signals != null and signals.has_signal("notify"):
        signals.emit_signal("notify", icon, message)

func _play_sound(sound_id: String) -> void:
    if _core != null and _core.has_method("play_sound"):
        _core.play_sound(sound_id)
        return
    var sound = _get_autoload("Sound")
    if sound != null and sound.has_method("play"):
        sound.play(sound_id)

func _get_autoload(name: String) -> Object:
    if Engine.has_singleton(name):
        return Engine.get_singleton(name)
    if Engine.get_main_loop() == null:
        return null
    var root = Engine.get_main_loop().root
    if root == null:
        return null
    return root.get_node_or_null(name)

func _log(message: String) -> void:
    if _core != null and _core.has_method("logi"):
        _core.logi("cheats", message)
    elif _has_global_class("ModLoaderLog"):
        ModLoaderLog.info(message, LOG_NAME)
    else:
        print("%s %s" % [LOG_NAME, message])

func _log_warn(message: String) -> void:
    if _core != null and _core.has_method("logw"):
        _core.logw("cheats", message)
    elif _has_global_class("ModLoaderLog"):
        ModLoaderLog.warning(message, LOG_NAME)
    else:
        print("%s %s" % [LOG_NAME, message])

func _has_global_class(class_name_str: String) -> bool:
    for entry in ProjectSettings.get_global_class_list():
        if entry.get("class", "") == class_name_str:
            return true
    return false
