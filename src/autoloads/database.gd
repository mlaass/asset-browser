extends Node

## SQLite database wrapper.
## Provides connection management and query helpers.

const Schema := preload("res://src/database/schema.gd")

var db: SQLite
var _is_open := false


func _ready() -> void:
	db = SQLite.new()
	db.path = AppConfig.get_database_path()
	db.verbosity_level = SQLite.QUIET

	if not open():
		push_error("Failed to open database at: " + db.path)
		return

	_initialize_database()


func _exit_tree() -> void:
	close()


func open() -> bool:
	if _is_open:
		return true

	_is_open = db.open_db()
	if _is_open:
		# Enable WAL mode for better concurrency
		db.query("PRAGMA journal_mode=WAL;")
		db.query("PRAGMA foreign_keys=ON;")
	return _is_open


func close() -> void:
	if _is_open:
		db.close_db()
		_is_open = false


func is_open() -> bool:
	return _is_open


func execute(sql: String, params: Array = []) -> bool:
	if not _is_open:
		push_error("Database not open")
		return false

	if params.is_empty():
		return db.query(sql)
	else:
		return db.query_with_bindings(sql, params)


func query(sql: String, params: Array = []) -> Array:
	if not _is_open:
		push_error("Database not open")
		return []

	if params.is_empty():
		db.query(sql)
	else:
		db.query_with_bindings(sql, params)

	return db.query_result


func query_one(sql: String, params: Array = []):
	var results := query(sql, params)
	if results.is_empty():
		return null
	return results[0]


func get_last_insert_id() -> int:
	var result := query("SELECT last_insert_rowid() as id")
	if result.is_empty():
		return -1
	return result[0]["id"]


func begin_transaction() -> bool:
	return execute("BEGIN TRANSACTION")


func commit() -> bool:
	return execute("COMMIT")


func rollback() -> bool:
	return execute("ROLLBACK")


func _initialize_database() -> void:
	var version := _get_schema_version()

	if version == 0:
		# Fresh install - create all tables
		_create_all_tables()
		_set_schema_version(Schema.SCHEMA_VERSION)
		print("Database initialized with schema version ", Schema.SCHEMA_VERSION)
	elif version < Schema.SCHEMA_VERSION:
		# Run migrations
		_run_migrations(version, Schema.SCHEMA_VERSION)
		_set_schema_version(Schema.SCHEMA_VERSION)
		print("Database migrated from version ", version, " to ", Schema.SCHEMA_VERSION)
	else:
		print("Database schema up to date (version ", version, ")")


func _get_schema_version() -> int:
	# Check if schema_version table exists
	var result := query(
		"SELECT name FROM sqlite_master WHERE type='table' AND name='schema_version'"
	)
	if result.is_empty():
		return 0

	var version_result := query("SELECT version FROM schema_version LIMIT 1")
	if version_result.is_empty():
		return 0

	return version_result[0]["version"]


func _set_schema_version(version: int) -> void:
	execute("DELETE FROM schema_version")
	execute("INSERT INTO schema_version (version) VALUES (?)", [version])


func _create_all_tables() -> void:
	for sql in Schema.CREATE_TABLES:
		if not execute(sql):
			push_error("Failed to create table: " + sql)

	for sql in Schema.CREATE_INDEXES:
		if not execute(sql):
			push_error("Failed to create index: " + sql)


func _run_migrations(from_version: int, to_version: int) -> void:
	for v in range(from_version + 1, to_version + 1):
		if Schema.MIGRATIONS.has(v):
			print("Running migration to version ", v)
			for sql in Schema.MIGRATIONS[v]:
				if not execute(sql):
					push_error("Migration failed at version ", v, ": ", sql)
					return
