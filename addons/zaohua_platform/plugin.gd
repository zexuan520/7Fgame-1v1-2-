@tool
extends EditorPlugin

const AUTOLOAD_NAME := "Zaohua"
const AUTOLOAD_PATH := "res://addons/zaohua_platform/runtime/zaohua.gd"
const ExportPluginScript := preload("res://addons/zaohua_platform/export_plugin.gd")
const CAPABILITY_DEFAULTS := {
	"game_loading": false,
	"game_lifecycle": false,
	"user_current": false,
	"storage": false,
	"studio_logging": false,
	"game_multiplayer": false,
}

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_register_project_settings()
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	_export_plugin = ExportPluginScript.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null
	var autoload_setting := "autoload/" + AUTOLOAD_NAME
	if ProjectSettings.get_setting(autoload_setting, "") == "*" + AUTOLOAD_PATH:
		remove_autoload_singleton(AUTOLOAD_NAME)


func _register_project_settings() -> void:
	for setting_name: String in CAPABILITY_DEFAULTS:
		var full_name := "zaohua/capabilities/" + setting_name
		var default_value: bool = CAPABILITY_DEFAULTS[setting_name]
		if not ProjectSettings.has_setting(full_name):
			ProjectSettings.set_setting(full_name, default_value)
		ProjectSettings.set_initial_value(full_name, default_value)
		ProjectSettings.add_property_info({
			"name": full_name,
			"type": TYPE_BOOL,
		})
	ProjectSettings.save()
