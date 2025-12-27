# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Asset Browser is a cross-platform desktop application for creative professionals to browse, organize, tag, and perform light edits on creative assets. Built with Godot 4.5 and SQLite, it works with files in-place rather than importing them into a managed library.

## Technology Stack

- **Engine**: Godot 4.5 (GL Compatibility renderer)
- **Database**: SQLite via godot-sqlite GDExtension addon
- **Target Platforms**: Linux, macOS, Windows

## Running the Project

Open in Godot 4.5 editor or run via command line:
```bash
godot --path .
```

## Architecture

### Plugin System

Asset handlers follow this interface pattern (from PRD):
```gdscript
class_name AssetHandler
extends RefCounted

static func get_supported_extensions() -> Array[String]
static func get_type_name() -> String
static func get_type_icon() -> Texture2D
func generate_thumbnail(path: String, size: Vector2i) -> Image
func create_preview() -> Control
func create_editor() -> Control
func get_conversion_options() -> Array[ConversionOption]
func convert(source: String, dest: String, option: ConversionOption) -> Error
```

Built-in handlers to implement: ImageHandler, AudioHandler, Model3DHandler, GodotSceneHandler, TextHandler.

### Data Model

Core entities: Project, WatchedFolder, AssetMeta, Tag, AssetTag (junction table).

Files identified by `(project_id, file_path, file_hash)`. Hash enables detecting external file changes.

### Database Locations

- Linux: `~/.local/share/asset-browser/data.db`
- macOS: `~/Library/Application Support/AssetBrowser/data.db`
- Windows: `%APPDATA%\AssetBrowser\data.db`

### Cache Locations

Thumbnails and preview data cached at:
- Linux: `~/.cache/asset-browser/`
- macOS: `~/Library/Caches/AssetBrowser/`
- Windows: `%LOCALAPPDATA%\AssetBrowser\Cache\`

## Threading Guidelines

Use `Thread` or `WorkerThreadPool` for:
- Thumbnail generation
- Folder indexing
- File copying/conversion

## Performance Targets

- Thumbnail generation: < 100ms per image
- Folder indexing: > 1000 files/second
- UI responsiveness: < 16ms frame time during scrolling
- Preview load: < 500ms for any supported file
