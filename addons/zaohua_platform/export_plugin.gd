@tool
extends EditorExportPlugin

const SDK_PATH := "res://addons/zaohua_platform/runtime/zaohua-sdk.js"
const CAPABILITY_SETTINGS := {
	"game.loading": "zaohua/capabilities/game_loading",
	"game.lifecycle": "zaohua/capabilities/game_lifecycle",
	"user.current": "zaohua/capabilities/user_current",
	"storage": "zaohua/capabilities/storage",
	"studio.logging": "zaohua/capabilities/studio_logging",
	"game.multiplayer": "zaohua/capabilities/game_multiplayer",
}


func _get_name() -> String:
	return "ZaohuaPlatformWeb"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformWeb


func _get_export_options_overrides(platform: EditorExportPlatform) -> Dictionary:
	if not _supports_platform(platform):
		return {}

	var sdk_source := FileAccess.get_file_as_string(SDK_PATH)
	if sdk_source.is_empty():
		push_error("Zaohua Platform SDK runtime is missing: " + SDK_PATH)
		sdk_source = "throw new Error('Zaohua Platform SDK runtime is missing');"

	# Never allow bundled source text to terminate its containing script element.
	sdk_source = sdk_source.replace("</script", "<\\/script")
	var capabilities_json := JSON.stringify(_enabled_capabilities())
	var capabilities_literal := JSON.stringify(capabilities_json)
	var head_include := (
		"<script data-zaohua-godot-sdk>\n"
		+ sdk_source
		+ "\nwindow.ZaohuaGodotBridge.configure("
		+ capabilities_literal
		+ ");\n</script>"
	)
	return {"html/head_include": head_include}


func _enabled_capabilities() -> Array[String]:
	var capabilities: Array[String] = []
	for capability: String in CAPABILITY_SETTINGS:
		if ProjectSettings.get_setting(CAPABILITY_SETTINGS[capability], false):
			capabilities.append(capability)
	return capabilities
