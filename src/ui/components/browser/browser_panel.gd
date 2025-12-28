extends VBoxContainer

## Browser panel with toolbar and asset grid.

const TYPE_EXTENSIONS := {
	"Images": ["png", "jpg", "jpeg", "webp", "svg", "tga", "bmp"],
	"Audio": ["wav", "mp3", "ogg", "flac", "aiff"],
	"3D Models": ["gltf", "glb", "obj", "fbx", "dae"],
}

@onready var grid_view_button: Button = %GridViewButton
@onready var list_view_button: Button = %ListViewButton
@onready var sort_dropdown: OptionButton = %SortDropdown
@onready var filter_dropdown: OptionButton = %FilterDropdown
@onready var search_box: LineEdit = %SearchBox
@onready var status_label: Label = %StatusLabel
@onready var empty_state: CenterContainer = %EmptyState
@onready var asset_grid: GridContainer = %AssetGrid
@onready var asset_list: VBoxContainer = %AssetList
@onready var grid_scroll: ScrollContainer = $ContentStack/ScrollContainer
@onready var list_scroll: ScrollContainer = $ContentStack/ListScrollContainer

var _current_folder: String = ""
var _current_assets: Array[AssetMeta] = []
var _selected_assets: Array[AssetMeta] = []
var _search_timer: Timer
var _current_type_filter: String = "All Types"
var _view_mode: String = "grid"


func _ready() -> void:
	_setup_toolbar()
	_setup_search_timer()

	EventBus.folder_selected.connect(_on_folder_selected)
	EventBus.thumbnail_ready.connect(_on_thumbnail_ready)
	EventBus.tag_filter_changed.connect(_on_tag_filter_changed)
	EventBus.refresh_requested.connect(_on_refresh_requested)
	EventBus.select_all_requested.connect(_on_select_all_requested)
	EventBus.deselect_all_requested.connect(_on_deselect_all_requested)
	EventBus.view_mode_changed.connect(_on_view_mode_changed)


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
	_clear_list()

	# Show/hide empty state
	var show_empty := assets.is_empty() and _current_folder.is_empty()
	empty_state.visible = show_empty

	# Show correct view container
	grid_scroll.visible = not show_empty and _view_mode == "grid"
	list_scroll.visible = not show_empty and _view_mode == "list"

	if _view_mode == "grid":
		for asset in assets:
			var item := _create_grid_item(asset)
			asset_grid.add_child(item)
	else:
		for asset in assets:
			var item := _create_list_item(asset)
			asset_list.add_child(item)

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

	# Store asset reference on item for select all
	item.set_meta("asset", asset)

	# Make clickable
	item.gui_input.connect(_on_grid_item_input.bind(asset, item))

	return item


func _create_list_item(asset: AssetMeta) -> Control:
	var item := HBoxContainer.new()
	item.custom_minimum_size = Vector2(0, 32)

	# Small thumbnail
	var texture_rect := TextureRect.new()
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.custom_minimum_size = Vector2(32, 32)
	texture_rect.texture = ThumbnailCache.get_thumbnail(asset)
	texture_rect.set_meta("asset", asset)
	item.add_child(texture_rect)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(8, 0)
	item.add_child(spacer)

	# Filename
	var name_label := Label.new()
	name_label.text = asset.get_filename()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item.add_child(name_label)

	# Type label
	var ext := asset.get_extension().to_upper()
	var type_label := Label.new()
	type_label.text = ext if not ext.is_empty() else "FILE"
	type_label.custom_minimum_size = Vector2(60, 0)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	type_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	item.add_child(type_label)

	# Store asset reference on item for select all
	item.set_meta("asset", asset)

	# Make clickable
	item.gui_input.connect(_on_grid_item_input.bind(asset, item))

	return item


func _clear_grid() -> void:
	for child in asset_grid.get_children():
		child.queue_free()


func _clear_list() -> void:
	for child in asset_list.get_children():
		child.queue_free()


func _get_current_container() -> Container:
	return asset_list if _view_mode == "list" else asset_grid


func _select_asset(asset: AssetMeta, item: Control) -> void:
	# Clear previous selection in current container
	var container := _get_current_container()
	for child in container.get_children():
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


func _on_filter_changed(index: int) -> void:
	var types := ["All Types", "Images", "Audio", "3D Models"]
	if index >= 0 and index < types.size():
		_current_type_filter = types[index]
		_apply_filters()


func _on_search_text_changed(_text: String) -> void:
	_search_timer.start()


func _on_search_timeout() -> void:
	EventBus.search_changed.emit(search_box.text)
	_apply_filters()


func _apply_filters() -> void:
	var filtered := _current_assets.duplicate()

	# Apply type filter
	if _current_type_filter != "All Types":
		var valid_exts: Array = TYPE_EXTENSIONS.get(_current_type_filter, [])
		filtered = filtered.filter(
			func(a: AssetMeta) -> bool:
				var ext := a.file_path.get_extension().to_lower()
				return ext in valid_exts
		)

	# Apply search filter
	var query := search_box.text.strip_edges().to_lower()
	if not query.is_empty():
		filtered = filtered.filter(
			func(a: AssetMeta) -> bool:
				return a.get_filename().to_lower().contains(query)
		)

	_display_assets(filtered)


func _on_tag_filter_changed(tags: Array) -> void:
	if tags.is_empty():
		_apply_filters()
		return

	# Filter by multiple tags (AND logic)
	if ProjectManager.current_project:
		var tag_ids: Array[int] = []
		for tag in tags:
			tag_ids.append(tag.id)
		var filtered := AssetMeta.with_all_tags(ProjectManager.current_project.id, tag_ids)
		_display_assets(filtered)


func _on_refresh_requested() -> void:
	if not _current_folder.is_empty():
		load_folder(_current_folder)


func _on_select_all_requested() -> void:
	_selected_assets.clear()
	var container := _get_current_container()
	for child in container.get_children():
		if child.has_meta("asset"):
			child.modulate = Color(0.7, 0.85, 1.0)
			child.set_meta("selected", true)
			_selected_assets.append(child.get_meta("asset"))
	EventBus.assets_selected.emit(_selected_assets)


func _on_deselect_all_requested() -> void:
	var container := _get_current_container()
	for child in container.get_children():
		child.modulate = Color.WHITE
		child.set_meta("selected", false)
	_selected_assets.clear()
	EventBus.selection_cleared.emit()


func _on_view_mode_changed(mode: String) -> void:
	_view_mode = mode
	_apply_filters()
