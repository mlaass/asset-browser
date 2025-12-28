class_name FileHasher
extends RefCounted

## Computes file hashes for identity and change detection.

const CHUNK_SIZE := 65536  # 64KB chunks for large files


## Computes MD5 hash of a file.
## Returns empty string on error.
static func hash_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open file for hashing: ", path)
		return ""

	var ctx := HashingContext.new()
	if ctx.start(HashingContext.HASH_MD5) != OK:
		return ""

	while not file.eof_reached():
		var chunk := file.get_buffer(CHUNK_SIZE)
		if chunk.size() > 0:
			ctx.update(chunk)

	var result := ctx.finish()
	return result.hex_encode()


## Computes a quick hash based on file size and first/last bytes.
## Much faster than full hash, useful for initial duplicate detection.
static func quick_hash(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""

	var size := file.get_length()
	if size == 0:
		return "empty"

	# Read first 1KB
	var first_chunk := file.get_buffer(mini(1024, size))

	# Read last 1KB if file is large enough
	var last_chunk := PackedByteArray()
	if size > 2048:
		file.seek(size - 1024)
		last_chunk = file.get_buffer(1024)

	# Combine size + first + last into hash
	var combined := PackedByteArray()
	combined.append_array(str(size).to_utf8_buffer())
	combined.append_array(first_chunk)
	combined.append_array(last_chunk)

	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(combined)
	return ctx.finish().hex_encode()


## Returns file modification time as Unix timestamp.
static func get_modification_time(path: String) -> int:
	return FileAccess.get_modified_time(path)


## Checks if a file has changed since the given timestamp.
static func has_file_changed(path: String, last_modified: int) -> bool:
	var current_time := get_modification_time(path)
	return current_time != last_modified
