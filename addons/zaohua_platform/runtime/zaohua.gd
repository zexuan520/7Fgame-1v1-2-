extends Node

signal current_user_received(user: Dictionary)
signal storage_value_received(key: String, value: Variant)
signal storage_value_saved(key: String)
signal platform_error(operation: String, message: String, error_code: String, reason_code: String)
signal rooms_available_received(available: bool)
signal rooms_listed(rooms: Array, current_room: Variant)
signal current_room_received(seat: Variant)
signal room_joined(room_id: String, player_id: String, is_host: bool)
signal room_occupied(room_id: String, game_status: Variant, reason: String)
signal room_left(room_id: String)
signal room_updated(room: Dictionary)
signal game_initialized(state: Variant)
signal game_updated(state: Variant)
signal game_over(result: Variant)
signal room_disconnected(info: Variant)

const ROOMS_UNAVAILABLE := "PlatformClient.rooms is unavailable: multiplayer needs a host runtime (published bundle or builder preview)"

var _bridge: JavaScriptObject
var _lifecycle_callback: JavaScriptObject
var _event_callback: JavaScriptObject
var _platform_paused := false
var _tree_was_paused := false
var _master_was_muted := false
var _local_storage: Dictionary = {}


func _emit_platform_error(operation: String, message: String, event: Dictionary = {}) -> void:
	platform_error.emit(operation, message, str(event.get("error_code", "")), str(event.get("reason_code", "")))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		return
	_bridge = JavaScriptBridge.get_interface("ZaohuaGodotBridge")
	if _bridge == null:
		push_error("ZaohuaGodotBridge was not injected into this Web export.")
		return
	_lifecycle_callback = JavaScriptBridge.create_callback(_on_lifecycle_request)
	_event_callback = JavaScriptBridge.create_callback(_on_bridge_event)
	_bridge.bind_lifecycle(_lifecycle_callback)
	_bridge.bind_events(_event_callback)


func _exit_tree() -> void:
	if _platform_paused:
		_apply_platform_pause(false)
	if _bridge != null:
		_bridge.unbind()
	_lifecycle_callback = null
	_event_callback = null


## Report that the main scene is initialized and the game is actually playable.
func game_loaded() -> void:
	if _bridge != null:
		_bridge.game_loaded()


## Fetch the current platform user. Emits current_user_received on success.
func get_current_user() -> void:
	if _bridge != null:
		_bridge.get_current_user()
	else:
		current_user_received.emit({"id": "local-user", "name": "Local Player"})


## Fetch a cloud value. Emits storage_value_received on success.
func storage_get(key: String) -> void:
	if _bridge != null:
		_bridge.storage_get(key)
	else:
		storage_value_received.emit(key, _local_storage.get(key))


## Save a cloud value. Emits storage_value_saved on success.
func storage_set(key: String, value: Variant) -> void:
	if _bridge != null:
		_bridge.storage_set(key, JSON.stringify(value))
	else:
		_local_storage[key] = value
		storage_value_saved.emit(key)


## Send a structured Studio log. Level must be debug, info, warn, or error.
func log_message(level: String, message: String, detail: Variant = null) -> void:
	if _bridge != null:
		_bridge.log_message(level, message, JSON.stringify(detail))
	else:
		print_rich("[Zaohua/%s] %s %s" % [level, message, str(detail)])


func rooms_is_available() -> void:
	if _bridge != null:
		_bridge.rooms_is_available()
	else:
		rooms_available_received.emit(false)


func rooms_list() -> void:
	if _bridge != null:
		_bridge.rooms_list()
	else:
		_emit_platform_error("rooms.list", ROOMS_UNAVAILABLE)


func rooms_peek_current() -> void:
	if _bridge != null:
		_bridge.rooms_peek_current()
	else:
		_emit_platform_error("rooms.peek", ROOMS_UNAVAILABLE)


func rooms_restore_current(options: Dictionary = {}) -> void:
	if _bridge != null:
		_bridge.rooms_restore_current(JSON.stringify(options))
	else:
		_emit_platform_error("rooms.restore", ROOMS_UNAVAILABLE)


func rooms_create(options: Dictionary = {}) -> void:
	if _bridge != null:
		_bridge.rooms_create(JSON.stringify(options))
	else:
		_emit_platform_error("rooms.create", ROOMS_UNAVAILABLE)


func rooms_join(room_id: String, options: Dictionary = {}) -> void:
	if _bridge != null:
		_bridge.rooms_join(room_id, JSON.stringify(options))
	else:
		_emit_platform_error("rooms.join", ROOMS_UNAVAILABLE)


func rooms_leave(room_id: String) -> void:
	if _bridge != null:
		_bridge.rooms_leave(room_id)
	else:
		_emit_platform_error("rooms.leave", ROOMS_UNAVAILABLE)


func rooms_handle_errors(codes = "*") -> void:
	if _bridge == null:
		return
	if typeof(codes) == TYPE_STRING:
		_bridge.rooms_handle_errors(codes)
	else:
		_bridge.rooms_handle_errors(JSON.stringify(codes))


func rooms_host_shows_platform_errors() -> bool:
	if _bridge == null:
		return false
	return bool(_bridge.rooms_host_shows_platform_errors())


func start_game() -> void:
	if _bridge != null:
		_bridge.room_start_game()
	else:
		_emit_platform_error("room.start", ROOMS_UNAVAILABLE)


func send_action(input: Variant) -> void:
	if _bridge != null:
		_bridge.room_send_action(JSON.stringify(input))
	else:
		_emit_platform_error("room.send_action", ROOMS_UNAVAILABLE)


func disconnect_room() -> void:
	if _bridge != null:
		_bridge.room_disconnect()
	else:
		_emit_platform_error("room.disconnect", ROOMS_UNAVAILABLE)


func is_platform_paused() -> bool:
	return _platform_paused


func _on_lifecycle_request(arguments: Array) -> void:
	if arguments.size() < 2:
		return
	var paused := bool(arguments[0])
	var request_id := int(arguments[1])
	_apply_platform_pause(paused)
	_bridge.lifecycle_applied(request_id, _platform_paused)


func _apply_platform_pause(paused: bool) -> void:
	if paused == _platform_paused:
		return
	var master_bus := AudioServer.get_bus_index("Master")
	if paused:
		_tree_was_paused = get_tree().paused
		_master_was_muted = master_bus >= 0 and AudioServer.is_bus_mute(master_bus)
		get_tree().paused = true
		if master_bus >= 0:
			AudioServer.set_bus_mute(master_bus, true)
	else:
		get_tree().paused = _tree_was_paused
		if master_bus >= 0:
			AudioServer.set_bus_mute(master_bus, _master_was_muted)
	_platform_paused = paused


func _on_bridge_event(arguments: Array) -> void:
	if arguments.is_empty():
		return
	var event = JSON.parse_string(str(arguments[0]))
	if not event is Dictionary:
		_emit_platform_error("bridge", "Received an invalid bridge event.")
		return
	match event.get("type", ""):
		"user.current":
			current_user_received.emit(event.get("user", {}))
		"storage.get":
			storage_value_received.emit(str(event.get("key", "")), event.get("value"))
		"storage.set":
			storage_value_saved.emit(str(event.get("key", "")))
		"rooms.available":
			rooms_available_received.emit(bool(event.get("available", false)))
		"rooms.list":
			rooms_listed.emit(event.get("rooms", []), event.get("currentRoom"))
		"rooms.current":
			current_room_received.emit(event.get("seat"))
		"rooms.joined":
			room_joined.emit(
				str(event.get("roomId", "")),
				str(event.get("playerId", "")),
				bool(event.get("isHost", false)),
			)
		"rooms.occupied":
			room_occupied.emit(
				str(event.get("roomId", "")),
				event.get("gameStatus"),
				str(event.get("reason", "")),
			)
		"rooms.left":
			room_left.emit(str(event.get("roomId", "")))
		"room.update":
			room_updated.emit(event.get("room", {}))
		"game.init":
			game_initialized.emit(event.get("state"))
		"game.update":
			game_updated.emit(event.get("state"))
		"game.over":
			game_over.emit(event.get("result"))
		"room.disconnected":
			room_disconnected.emit(event.get("info"))
		"room.error":
			_emit_platform_error("room.error", str(event.get("message", "Unknown room error")), event)
			push_error("Zaohua room.error failed: %s" % str(event.get("message", "Unknown room error")))
		"error":
			var operation := str(event.get("operation", "unknown"))
			var message := str(event.get("message", "Unknown platform error"))
			_emit_platform_error(operation, message, event)
			push_error("Zaohua %s failed: %s" % [operation, message])
