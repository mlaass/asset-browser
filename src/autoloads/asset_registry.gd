extends Node

## Registry for asset handlers.
## Maps file extensions to their handlers.

const AssetHandlerClass := preload("res://src/handlers/asset_handler.gd")
const ImageHandlerClass := preload("res://src/handlers/image_handler.gd")

# Extension to handler mapping
var _handlers: Dictionary = {}  # String -> handler instance

# Handler instances (reused for performance)
var _handler_instances: Array = []


func _ready() -> void:
  _register_default_handlers()


func _register_default_handlers() -> void:
  register(ImageHandlerClass.new())
  # Future: register(AudioHandler.new())
  # Future: register(Model3DHandler.new())
  # Future: register(TextHandler.new())


## Registers an asset handler.
## The handler's supported extensions are mapped for lookup.
func register(handler) -> void:
  _handler_instances.append(handler)

  for ext in handler.get_supported_extensions():
    var lower_ext: String = ext.to_lower()
    if _handlers.has(lower_ext):
      push_warning("Extension already registered, overwriting: ", lower_ext)
    _handlers[lower_ext] = handler


## Returns the handler for a given file path.
## Returns null if no handler is registered for this file type.
func get_handler_for_file(path: String):
  var ext := path.get_extension().to_lower()
  return _handlers.get(ext, null)


## Returns the handler for a given extension.
## Returns null if no handler is registered for this extension.
func get_handler_for_extension(ext: String):
  return _handlers.get(ext.to_lower(), null)


## Returns true if a handler exists for the given file.
func is_supported(path: String) -> bool:
  return get_handler_for_file(path) != null


## Returns true if a handler exists for the given extension.
func is_extension_supported(ext: String) -> bool:
  return get_handler_for_extension(ext) != null


## Returns all supported extensions.
func get_supported_extensions() -> Array[String]:
  var extensions: Array[String] = []
  for ext in _handlers.keys():
    extensions.append(ext)
  extensions.sort()
  return extensions


## Returns all registered handlers.
func get_all_handlers() -> Array:
  return _handler_instances


## Returns the type name for a file.
## Returns "Unknown" if no handler is registered.
func get_type_name(path: String) -> String:
  var handler = get_handler_for_file(path)
  if handler:
    return handler.get_type_name()
  return "Unknown"


## Returns the type icon for a file.
## Returns null if no handler is registered.
func get_type_icon(path: String):
  var handler = get_handler_for_file(path)
  if handler:
    return handler.get_type_icon()
  return null
