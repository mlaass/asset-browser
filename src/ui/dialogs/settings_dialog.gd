extends Window

## Settings dialog with tabs for General, Appearance, and Cache settings.

signal settings_changed()

@onready var tab_container: TabContainer = %TabContainer

# General tab
@onready var show_hidden_check: CheckBox = %ShowHiddenCheck
@onready var confirm_delete_check: CheckBox = %ConfirmDeleteCheck

# Appearance tab
@onready var accent_color_picker: ColorPickerButton = %AccentColorPicker
@onready var font_size_slider: HSlider = %FontSizeSlider
@onready var font_size_label: Label = %FontSizeLabel

# Cache tab
@onready var cache_size_label: Label = %CacheSizeLabel
@onready var cache_count_label: Label = %CacheCountLabel
@onready var thumbnail_size_slider: HSlider = %ThumbnailSizeSlider
@onready var thumbnail_size_label: Label = %ThumbnailSizeLabel
@onready var clear_cache_button: Button = %ClearCacheButton

@onready var save_button: Button = %SaveButton
@onready var cancel_button: Button = %CancelButton


func _ready() -> void:
	_load_current_settings()
	_update_cache_info()

	# Connect signals
	font_size_slider.value_changed.connect(_on_font_size_changed)
	thumbnail_size_slider.value_changed.connect(_on_thumbnail_size_changed)
	clear_cache_button.pressed.connect(_on_clear_cache_pressed)
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	close_requested.connect(_on_cancel_pressed)


func _load_current_settings() -> void:
	# General
	show_hidden_check.button_pressed = AppConfig.get_show_hidden_files()
	confirm_delete_check.button_pressed = AppConfig.get_confirm_delete()

	# Appearance
	accent_color_picker.color = AppConfig.get_accent_color()
	font_size_slider.value = AppConfig.get_font_size()
	font_size_label.text = "%d px" % int(font_size_slider.value)

	# Cache
	thumbnail_size_slider.value = AppConfig.get_thumbnail_size()
	thumbnail_size_label.text = "%d px" % int(thumbnail_size_slider.value)


func _update_cache_info() -> void:
	var size_bytes := ThumbnailCache.get_disk_cache_size()
	var count := ThumbnailCache.get_disk_cache_count()

	# Format size nicely
	var size_str: String
	if size_bytes < 1024:
		size_str = "%d B" % size_bytes
	elif size_bytes < 1024 * 1024:
		size_str = "%.1f KB" % (size_bytes / 1024.0)
	else:
		size_str = "%.1f MB" % (size_bytes / (1024.0 * 1024.0))

	cache_size_label.text = "Cache size: %s" % size_str
	cache_count_label.text = "%d cached thumbnails" % count


func _on_font_size_changed(value: float) -> void:
	font_size_label.text = "%d px" % int(value)


func _on_thumbnail_size_changed(value: float) -> void:
	thumbnail_size_label.text = "%d px" % int(value)


func _on_clear_cache_pressed() -> void:
	ThumbnailCache.clear_all_cache()
	_update_cache_info()


func _on_save_pressed() -> void:
	# Save all settings
	AppConfig.set_setting("general/show_hidden_files", show_hidden_check.button_pressed)
	AppConfig.set_setting("general/confirm_delete", confirm_delete_check.button_pressed)
	AppConfig.set_setting("ui/accent_color", accent_color_picker.color.to_html())
	AppConfig.set_setting("ui/font_size", int(font_size_slider.value))
	AppConfig.set_setting("thumbnails/size", int(thumbnail_size_slider.value))

	settings_changed.emit()
	EventBus.settings_changed.emit()
	hide()
	queue_free()


func _on_cancel_pressed() -> void:
	hide()
	queue_free()
