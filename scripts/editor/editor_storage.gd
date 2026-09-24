class_name EditorStorage
extends RefCounted
## Stage both files before replacing either; restore previous bytes on failure.
static func save_pair(path: String, data: Dictionary, decor: PackedScene) -> Error:
	var directory_error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK: return directory_error
	var decor_path := LevelDecor.decor_path_for(path)
	var staged := path + ".designer-tmp"
	var staged_decor := decor_path.trim_suffix(".tscn") + ".designer-tmp.tscn"
	var file := FileAccess.open(staged, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK: error = ResourceSaver.save(decor, staged_decor)
	if error != OK:
		DirAccess.remove_absolute(staged)
		DirAccess.remove_absolute(staged_decor)
		return error
	var paths := [path, decor_path]
	var backups := []
	for target in paths:
		backups.append(FileAccess.get_file_as_bytes(target) if FileAccess.file_exists(target) else null)
	error = DirAccess.rename_absolute(staged_decor, decor_path)
	if error == OK: error = DirAccess.rename_absolute(staged, path)
	if error != OK:
		for i in paths.size():
			if backups[i] == null:
				DirAccess.remove_absolute(paths[i])
			else:
				var restore := FileAccess.open(paths[i], FileAccess.WRITE)
				if restore:
					restore.store_buffer(backups[i])
					restore.close()
		DirAccess.remove_absolute(staged)
		DirAccess.remove_absolute(staged_decor)
	return error
