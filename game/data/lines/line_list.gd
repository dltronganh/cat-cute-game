class_name LineList
extends RefCounted
## Loads a list of dialogue lines from a JSON file in game/data/lines/.
##
## JSON (not .tres) so anyone can open the file in a plain text editor and
## add a line. File shape: { "lines": ["...", "..."] }. Keys starting with "_"
## are notes for humans and are ignored.
## The export preset includes *.json files (export_presets.cfg include_filter).
##
## Example: game/data/lines/mr_thanh_calls.json (bà Hằng scolding Mr. Thanh).


## Returns the "lines" array of the JSON file at [param path], or an empty
## array (and an error in the log) if the file is missing or broken.
static func load_lines(path: String) -> PackedStringArray:
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary) or not (data.get("lines") is Array):
		push_error("LineList: cannot read lines from %s" % path)
		return PackedStringArray()
	return PackedStringArray(data["lines"])
