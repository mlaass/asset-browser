class_name ImageHandler
extends AssetHandler

## Handler for image files.
## Supports PNG, JPG, JPEG, WebP, SVG, TGA, BMP.

const SUPPORTED_EXTENSIONS: Array[String] = [
	"png", "jpg", "jpeg", "webp", "svg", "tga", "bmp"
]


static func get_supported_extensions() -> Array[String]:
	return SUPPORTED_EXTENSIONS


static func get_type_name() -> String:
	return "Image"


static func get_type_icon() -> Texture2D:
	# TODO: Return actual icon from FontAwesome or theme
	return null


func generate_thumbnail(path: String, size: Vector2i) -> Image:
	var image := Image.load_from_file(path)
	if image == null:
		push_error("Failed to load image: ", path)
		return null

	# Calculate size maintaining aspect ratio
	var original_size := image.get_size()
	var scale := _calculate_fit_scale(original_size, size)
	var new_size := Vector2i(
		int(original_size.x * scale),
		int(original_size.y * scale)
	)

	# Ensure minimum size of 1x1
	new_size.x = maxi(new_size.x, 1)
	new_size.y = maxi(new_size.y, 1)

	# Resize with high-quality interpolation
	image.resize(new_size.x, new_size.y, Image.INTERPOLATE_LANCZOS)

	return image


func create_preview() -> Control:
	# Will be implemented in Step 10
	return null


func create_editor() -> Control:
	# Will be implemented in Phase 3
	return null


func get_conversion_options() -> Array[Dictionary]:
	return [
		{
			"id": "webp",
			"name": "WebP",
			"extension": "webp",
			"settings": {
				"quality": 85,
				"lossless": false,
			}
		},
		{
			"id": "png",
			"name": "PNG",
			"extension": "png",
			"settings": {}
		},
		{
			"id": "jpg",
			"name": "JPEG",
			"extension": "jpg",
			"settings": {
				"quality": 85,
			}
		},
	]


func convert(source: String, dest: String, options: Dictionary) -> Error:
	var image := Image.load_from_file(source)
	if image == null:
		return ERR_FILE_CANT_READ

	var format: String = options.get("format", "webp")
	var quality: float = options.get("quality", 85) / 100.0

	match format:
		"webp":
			var lossless: bool = options.get("lossless", false)
			if lossless:
				return image.save_webp(dest, true)
			else:
				return image.save_webp(dest, false, quality)
		"png":
			return image.save_png(dest)
		"jpg", "jpeg":
			return image.save_jpg(dest, quality)
		_:
			return ERR_INVALID_PARAMETER


## Returns the size of an image file without loading the full image.
## Returns Vector2i.ZERO if the file can't be read.
static func get_image_size(path: String) -> Vector2i:
	var image := Image.load_from_file(path)
	if image == null:
		return Vector2i.ZERO
	return image.get_size()


## Calculates the scale factor to fit source into target while maintaining aspect ratio.
func _calculate_fit_scale(source: Vector2i, target: Vector2i) -> float:
	if source.x <= 0 or source.y <= 0:
		return 1.0

	var scale_x := float(target.x) / float(source.x)
	var scale_y := float(target.y) / float(source.y)

	return minf(scale_x, scale_y)
