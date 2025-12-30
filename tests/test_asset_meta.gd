extends GutTest

## Tests for AssetMeta model class.


func test_from_row_creates_valid_asset():
	var row := {
		"id": 1,
		"project_id": 2,
		"file_path": "/home/user/images/photo.png",
		"file_hash": "abc123",
		"is_favorite": 1,
		"notes": "Test notes",
		"thumbnail_path": "/cache/thumb.png",
		"last_modified": 1234567890,
		"edits_json": "",
	}

	var asset := AssetMeta.from_row(row)

	assert_eq(asset.id, 1, "ID should be set from row")
	assert_eq(asset.project_id, 2, "Project ID should be set from row")
	assert_eq(asset.file_path, "/home/user/images/photo.png", "File path should be set")
	assert_eq(asset.file_hash, "abc123", "File hash should be set")
	assert_true(asset.is_favorite, "is_favorite should be true when row value is 1")
	assert_eq(asset.notes, "Test notes", "Notes should be set")


func test_from_row_handles_defaults():
	var row := {}

	var asset := AssetMeta.from_row(row)

	assert_eq(asset.id, -1, "ID should default to -1")
	assert_eq(asset.project_id, -1, "Project ID should default to -1")
	assert_eq(asset.file_path, "", "File path should default to empty")
	assert_false(asset.is_favorite, "is_favorite should default to false")


func test_get_filename_returns_file_name():
	var asset := AssetMeta.new()
	asset.file_path = "/home/user/documents/my-file.txt"

	assert_eq(asset.get_filename(), "my-file.txt", "get_filename should return just the filename")


func test_get_filename_handles_nested_paths():
	var asset := AssetMeta.new()
	asset.file_path = "/a/b/c/d/image.png"

	assert_eq(asset.get_filename(), "image.png", "get_filename should work with deeply nested paths")


func test_get_extension_returns_lowercase():
	var asset := AssetMeta.new()
	asset.file_path = "/path/to/IMAGE.PNG"

	assert_eq(asset.get_extension(), "png", "get_extension should return lowercase extension")


func test_get_extension_handles_multiple_dots():
	var asset := AssetMeta.new()
	asset.file_path = "/path/to/archive.tar.gz"

	assert_eq(asset.get_extension(), "gz", "get_extension should return last extension")


func test_get_extension_handles_no_extension():
	var asset := AssetMeta.new()
	asset.file_path = "/path/to/Makefile"

	assert_eq(asset.get_extension(), "", "get_extension should return empty for files without extension")


func test_to_dict_round_trip():
	var asset := AssetMeta.new()
	asset.id = 5
	asset.project_id = 10
	asset.file_path = "/test/path.jpg"
	asset.file_hash = "hash123"
	asset.is_favorite = true
	asset.notes = "Some notes"

	var dict := asset.to_dict()

	assert_eq(dict["id"], 5, "to_dict should include id")
	assert_eq(dict["project_id"], 10, "to_dict should include project_id")
	assert_eq(dict["file_path"], "/test/path.jpg", "to_dict should include file_path")
	assert_eq(dict["is_favorite"], 1, "to_dict should convert boolean to int")
	assert_eq(dict["notes"], "Some notes", "to_dict should include notes")
