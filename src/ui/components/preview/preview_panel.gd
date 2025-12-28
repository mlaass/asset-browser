extends PanelContainer

## Preview panel with image display and metadata bar.

@onready var image_preview: TextureRect = %ImagePreview
@onready var no_preview_label: Label = %NoPreviewLabel
@onready var metadata_bar: HBoxContainer = %MetadataBar
@onready var tags_container: HBoxContainer = %TagsContainer
@onready var favorite_button: Button = %FavoriteButton
@onready var notes_edit: LineEdit = %NotesEdit
@onready var file_info_label: Label = %FileInfoLabel

var _current_asset: AssetMeta = null
var _zoom_level: float = 1.0
var _pan_offset: Vector2 = Vector2.ZERO
var _is_panning := false
var _pan_start: Vector2 = Vector2.ZERO


func _ready() -> void:
	EventBus.preview_requested.connect(_on_preview_requested)
	EventBus.asset_favorited.connect(_on_asset_favorited)

	favorite_button.toggled.connect(_on_favorite_toggled)
	notes_edit.text_changed.connect(_on_notes_changed)

	_clear_preview()


func _clear_preview() -> void:
	_current_asset = null
	image_preview.texture = null
	image_preview.visible = false
	no_preview_label.visible = true

	# Clear metadata
	for child in tags_container.get_children():
		child.queue_free()
	favorite_button.button_pressed = false
	notes_edit.text = ""
	file_info_label.text = "No file selected"

	_zoom_level = 1.0
	_pan_offset = Vector2.ZERO


func show_preview(asset: AssetMeta) -> void:
	_current_asset = asset

	# Check if file exists
	if not asset.file_exists():
		_show_no_preview("File not found")
		return

	# Get handler
	var handler = AssetRegistry.get_handler_for_file(asset.file_path)
	if handler == null:
		_show_no_preview("Unsupported file type")
		return

	# Load image for preview
	if handler is ImageHandler:
		_load_image_preview(asset.file_path)
	else:
		_show_no_preview("Preview not available")

	# Update metadata
	_update_metadata(asset)


func _load_image_preview(path: String) -> void:
	var image := Image.load_from_file(path)
	if image == null:
		_show_no_preview("Failed to load image")
		return

	var texture := ImageTexture.create_from_image(image)
	image_preview.texture = texture
	image_preview.visible = true
	no_preview_label.visible = false

	# Reset zoom/pan
	_zoom_level = 1.0
	_pan_offset = Vector2.ZERO
	_apply_transform()


func _show_no_preview(message: String) -> void:
	image_preview.visible = false
	no_preview_label.text = message
	no_preview_label.visible = true


func _update_metadata(asset: AssetMeta) -> void:
	# Tags
	for child in tags_container.get_children():
		child.queue_free()

	for tag in asset.get_tags():
		var tag_label := Label.new()
		tag_label.text = tag.name

		var style := StyleBoxFlat.new()
		style.bg_color = tag.get_color()
		style.set_corner_radius_all(4)
		style.set_content_margin_all(4)

		var container := PanelContainer.new()
		container.add_theme_stylebox_override("panel", style)
		container.add_child(tag_label)
		tags_container.add_child(container)

	# Favorite
	favorite_button.button_pressed = asset.is_favorite

	# Notes
	notes_edit.text = asset.notes

	# File info
	var file := FileAccess.open(asset.file_path, FileAccess.READ)
	if file:
		var size := file.get_length()
		var size_str := _format_file_size(size)

		if AssetRegistry.get_handler_for_file(asset.file_path) is ImageHandler:
			var image := Image.load_from_file(asset.file_path)
			if image:
				file_info_label.text = "%s | %dx%d | %s" % [
					asset.get_filename(),
					image.get_width(),
					image.get_height(),
					size_str
				]
			else:
				file_info_label.text = "%s | %s" % [asset.get_filename(), size_str]
		else:
			file_info_label.text = "%s | %s" % [asset.get_filename(), size_str]
	else:
		file_info_label.text = asset.get_filename()


func _format_file_size(bytes: int) -> String:
	if bytes < 1024:
		return "%d B" % bytes
	elif bytes < 1024 * 1024:
		return "%.1f KB" % (bytes / 1024.0)
	elif bytes < 1024 * 1024 * 1024:
		return "%.1f MB" % (bytes / (1024.0 * 1024.0))
	else:
		return "%.1f GB" % (bytes / (1024.0 * 1024.0 * 1024.0))


func _apply_transform() -> void:
	image_preview.pivot_offset = image_preview.size / 2
	image_preview.scale = Vector2.ONE * _zoom_level
	image_preview.position = _pan_offset


# Input handling for pan/zoom

func _gui_input(event: InputEvent) -> void:
	if _current_asset == null or not image_preview.visible:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_level = minf(_zoom_level * 1.1, 10.0)
			_apply_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_level = maxf(_zoom_level / 1.1, 0.1)
			_apply_transform()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_panning = true
				_pan_start = event.position
			else:
				_is_panning = false

	elif event is InputEventMouseMotion:
		if _is_panning:
			_pan_offset += event.position - _pan_start
			_pan_start = event.position
			_apply_transform()


# Event handlers

func _on_preview_requested(asset: AssetMeta) -> void:
	show_preview(asset)


func _on_favorite_toggled(pressed: bool) -> void:
	if _current_asset and _current_asset.id >= 0:
		_current_asset.set_favorite(pressed)
		EventBus.asset_favorited.emit(_current_asset.id, pressed)


func _on_notes_changed(new_text: String) -> void:
	if _current_asset and _current_asset.id >= 0:
		_current_asset.set_notes(new_text)
		EventBus.asset_notes_updated.emit(_current_asset.id, new_text)


func _on_asset_favorited(asset_id: int, is_favorite: bool) -> void:
	if _current_asset and _current_asset.id == asset_id:
		favorite_button.button_pressed = is_favorite
