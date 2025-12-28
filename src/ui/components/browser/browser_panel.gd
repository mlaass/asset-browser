extends VBoxContainer

## Browser panel with toolbar and asset grid.

@onready var grid_view_button: Button = %GridViewButton
@onready var list_view_button: Button = %ListViewButton
@onready var sort_dropdown: OptionButton = %SortDropdown
@onready var filter_dropdown: OptionButton = %FilterDropdown
@onready var search_box: LineEdit = %SearchBox
@onready var status_label: Label = %StatusLabel
@onready var asset_grid: GridContainer = %AssetGrid

var _current_folder: String = ""
var _current_assets: Array[AssetMeta] = []
var _selected_assets: Array[AssetMeta] = []
var _search_timer: Timer


func _ready() -> void:
	_setup_toolbar()
	_setup_search_timer()

	EventBus.folder_selected.connect(_on_folder_selected)
	EventBus.thumbnail_ready.connect(_on_thumbnail_ready)
	EventBus.tag_filter_changed.connect(_on_tag_filter_changed)


func _setup_toolbar() -> void:
	# View toggle
	grid_view_button.toggled.connect(_on_grid_view_toggled)
	list_view_button.toggled.connect(_on_list_view_toggled)

	# Sort options
	sort_dropdown.add_item("Name", 0)
	sort_dropdown.add_item("Date Modified", 1)
	sort_dropdown.add_item("Size", 2)
	sort_dropdown.add_item("Type", 3)
	sort_dropdown.item_selected.connect(_on_sort_changed)

	# Filter options
	filter_dropdown.add_item("All Types", 0)
	filter_dropdown.add_item("Images", 1)
	filter_dropdown.add_item("Audio", 2)
	filter_dropdown.add_item("3D Models", 3)
	filter_dropdown.item_selected.connect(_on_filter_changed)

	# Search
	search_box.text_changed.connect(_on_search_text_changed)


func _setup_search_timer() -> void:
	_search_timer = Timer.new()
	_search_timer.one_shot = true
	_search_timer.wait_time = 0.3
	_search_timer.timeout.connect(_on_search_timeout)
	add_child(_search_timer)


func load_folder(path: String) -> void:
	_current_folder = path
	_clear_grid()

	if not DirAccess.dir_exists_absolute(path):
		status_label.text = "Folder not found"
		return

	# Get assets from database for this folder
	if ProjectManager.current_project:
		_current_assets = AssetMeta.for_folder(ProjectManager.current_project.id, path)

	# If no indexed assets, scan the folder directly
	if _current_assets.is_empty():
		_scan_folder(path)
	else:
		_display_assets(_current_assets)


func _scan_folder(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		status_label.text = "Cannot open folder"
		return

	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and AssetRegistry.is_supported(file_name):
			files.append(path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

	files.sort()

	# Create temporary AssetMeta objects for display
	_current_assets.clear()
	for file_path in files:
		var asset := AssetMeta.new()
		asset.file_path = file_path
		_current_assets.append(asset)

	_display_assets(_current_assets)


func _display_assets(assets: Array[AssetMeta]) -> void:
	_clear_grid()

	for asset in assets:
		var item := _create_grid_item(asset)
		asset_grid.add_child(item)

	status_label.text = "%d items" % assets.size()


func _create_grid_item(asset: AssetMeta) -> Control:
	var item := VBoxContainer.new()
	item.custom_minimum_size = Vector2(120, 140)

	# Thumbnail container
	var thumb_container := PanelContainer.new()
	thumb_container.custom_minimum_size = Vector2(100, 100)

	var texture_rect := TextureRect.new()
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.custom_minimum_size = Vector2(100, 100)

	# Get thumbnail
	var thumbnail := ThumbnailCache.get_thumbnail(asset)
	texture_rect.texture = thumbnail

	# Store asset reference
	texture_rect.set_meta("asset", asset)

	thumb_container.add_child(texture_rect)
	item.add_child(thumb_container)

	# Filename label
	var label := Label.new()
	label.text = asset.get_filename()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2(100, 0)
	item.add_child(label)

	# Make clickable
	item.gui_input.connect(_on_grid_item_input.bind(asset, item))

	return item


func _clear_grid() -> void:
	for child in asset_grid.get_children():
		child.queue_free()
	_current_assets.clear()
	_selected_assets.clear()


func _select_asset(asset: AssetMeta, item: Control) -> void:
	# Clear previous selection
	for child in asset_grid.get_children():
		if child.has_meta("selected") and child.get_meta("selected"):
			child.modulate = Color.WHITE
			child.set_meta("selected", false)

	# Select new
	_selected_assets = [asset]
	item.modulate = Color(0.7, 0.85, 1.0)
	item.set_meta("selected", true)

	EventBus.asset_selected.emit(asset)
	EventBus.preview_requested.emit(asset)


# Event handlers

func _on_folder_selected(path: String) -> void:
	load_folder(path)


func _on_grid_item_input(event: InputEvent, asset: AssetMeta, item: Control) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_select_asset(asset, item)


func _on_thumbnail_ready(asset_id: int, texture: Texture2D) -> void:
	# Find and update the grid item for this asset
	for child in asset_grid.get_children():
		var thumb_container := child.get_child(0)
		if thumb_container and thumb_container.get_child_count() > 0:
			var texture_rect := thumb_container.get_child(0) as TextureRect
			if texture_rect and texture_rect.has_meta("asset"):
				var asset: AssetMeta = texture_rect.get_meta("asset")
				if asset.id == asset_id:
					texture_rect.texture = texture
					break


func _on_grid_view_toggled(pressed: bool) -> void:
	if pressed:
		list_view_button.button_pressed = false
		EventBus.view_mode_changed.emit("grid")


func _on_list_view_toggled(pressed: bool) -> void:
	if pressed:
		grid_view_button.button_pressed = false
		EventBus.view_mode_changed.emit("list")


func _on_sort_changed(index: int) -> void:
	var fields := ["name", "date", "size", "type"]
	if index >= 0 and index < fields.size():
		EventBus.sort_changed.emit(fields[index], true)


func _on_filter_changed(_index: int) -> void:
	# TODO: Implement type filtering
	pass


func _on_search_text_changed(_text: String) -> void:
	_search_timer.start()


func _on_search_timeout() -> void:
	var query := search_box.text
	EventBus.search_changed.emit(query)

	if query.is_empty():
		_display_assets(_current_assets)
	else:
		var filtered := _current_assets.filter(
			func(a: AssetMeta) -> bool:
				return a.get_filename().to_lower().contains(query.to_lower())
		)
		_display_assets(filtered)


func _on_tag_filter_changed(tags: Array) -> void:
	if tags.is_empty():
		_display_assets(_current_assets)
		return

	# Filter by tags
	if ProjectManager.current_project:
		var tag: Tag = tags[0]
		var filtered := AssetMeta.with_tag(ProjectManager.current_project.id, tag.id)
		_display_assets(filtered)
