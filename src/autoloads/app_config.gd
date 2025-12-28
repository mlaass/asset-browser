extends Node

## Application configuration and platform-specific paths.
## Handles data directory, cache directory, and ensures they exist on startup.

var _data_path: String
var _cache_path: String
var _thumbnail_path: String

# User settings with defaults
var _settings: Dictionary = {
	"ui/accent_color": "#3498db",
	"ui/font_size": 14,
	"thumbnails/size": 100,
	"general/show_hidden_files": false,
	"general/confirm_delete": true,
}


func _ready() -> void:
	_data_path = _get_platform_data_path()
	_cache_path = _get_platform_cache_path()
	_thumbnail_path = _cache_path.path_join("thumbnails")
	ensure_directories_exist()
	_load_settings()


func get_data_path() -> String:
	return _data_path


func get_cache_path() -> String:
	return _cache_path


func get_thumbnail_path() -> String:
	return _thumbnail_path


func get_database_path() -> String:
	return _data_path.path_join("data.db")


func ensure_directories_exist() -> void:
	DirAccess.make_dir_recursive_absolute(_data_path)
	DirAccess.make_dir_recursive_absolute(_cache_path)
	DirAccess.make_dir_recursive_absolute(_thumbnail_path)


func _get_platform_data_path() -> String:
	match OS.get_name():
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			var xdg := OS.get_environment("XDG_DATA_HOME")
			if xdg.is_empty():
				xdg = OS.get_environment("HOME").path_join(".local/share")
			return xdg.path_join("asset-browser")
		"macOS":
			return OS.get_environment("HOME").path_join("Library/Application Support/AssetBrowser")
		"Windows":
			var appdata := OS.get_environment("APPDATA")
			if appdata.is_empty():
				return OS.get_user_data_dir()
			return appdata.path_join("AssetBrowser")
		_:
			return OS.get_user_data_dir()


func _get_platform_cache_path() -> String:
	match OS.get_name():
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			var xdg := OS.get_environment("XDG_CACHE_HOME")
			if xdg.is_empty():
				xdg = OS.get_environment("HOME").path_join(".cache")
			return xdg.path_join("asset-browser")
		"macOS":
			return OS.get_environment("HOME").path_join("Library/Caches/AssetBrowser")
		"Windows":
			var localappdata := OS.get_environment("LOCALAPPDATA")
			if localappdata.is_empty():
				return OS.get_user_data_dir().path_join("cache")
			return localappdata.path_join("AssetBrowser/Cache")
		_:
			return OS.get_user_data_dir().path_join("cache")


# Settings management

func _load_settings() -> void:
	var settings_path := _data_path.path_join("settings.json")
	if not FileAccess.file_exists(settings_path):
		return

	var file := FileAccess.open(settings_path, FileAccess.READ)
	if file == null:
		return

	var json_text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(json_text)
	if parsed is Dictionary:
		# Merge loaded settings with defaults (keeps defaults for missing keys)
		for key in parsed:
			_settings[key] = parsed[key]


func save_settings() -> void:
	var settings_path := _data_path.path_join("settings.json")
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to save settings: " + settings_path)
		return

	file.store_string(JSON.stringify(_settings, "\t"))
	file.close()


func get_setting(key: String, default = null):
	return _settings.get(key, default)


func set_setting(key: String, value) -> void:
	_settings[key] = value
	save_settings()


func get_all_settings() -> Dictionary:
	return _settings.duplicate()


# Convenience getters for common settings

func get_accent_color() -> Color:
	return Color.html(_settings.get("ui/accent_color", "#3498db"))


func get_font_size() -> int:
	return _settings.get("ui/font_size", 14)


func get_thumbnail_size() -> int:
	return _settings.get("thumbnails/size", 100)


func get_show_hidden_files() -> bool:
	return _settings.get("general/show_hidden_files", false)


func get_confirm_delete() -> bool:
	return _settings.get("general/confirm_delete", true)
