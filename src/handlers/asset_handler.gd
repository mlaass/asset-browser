class_name AssetHandler
extends RefCounted

## Base class for asset type handlers.
## Subclasses implement support for specific asset types (images, audio, 3D models, etc.)


## Returns the list of file extensions this handler supports.
static func get_supported_extensions() -> Array[String]:
	return []


## Returns the human-readable name of this asset type.
static func get_type_name() -> String:
	return "Unknown"


## Returns the icon for this asset type.
static func get_type_icon() -> Texture2D:
	return null


## Generates a thumbnail image for the given file.
## Returns null if thumbnail generation fails.
func generate_thumbnail(path: String, size: Vector2i) -> Image:
	return null


## Creates a preview control for this asset type.
## The control is added to the preview panel when an asset is selected.
func create_preview() -> Control:
	return null


## Creates an editor control for this asset type (if editing is supported).
## Returns null if this asset type doesn't support editing.
func create_editor() -> Control:
	return null


## Returns conversion options for the Copy Assistant.
func get_conversion_options() -> Array[Dictionary]:
	return []


## Converts an asset to a different format.
## Returns OK on success, or an error code on failure.
func convert(source: String, dest: String, options: Dictionary) -> Error:
	return ERR_METHOD_NOT_FOUND
