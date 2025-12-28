extends Node

## Application configuration and platform-specific paths.
## Handles data directory, cache directory, and ensures they exist on startup.

var _data_path: String
var _cache_path: String
var _thumbnail_path: String


func _ready() -> void:
	_data_path = _get_platform_data_path()
	_cache_path = _get_platform_cache_path()
	_thumbnail_path = _cache_path.path_join("thumbnails")
	ensure_directories_exist()


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
