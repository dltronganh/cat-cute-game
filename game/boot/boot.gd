extends Control
## Boot screen: the first scene that runs (application/run/main_scene).
##
## For now it only shows the project name and version, so a build can be
## checked at a glance. Later it will load settings and open the menu.

@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	var game_name: String = ProjectSettings.get_setting("application/config/name")
	var version: String = ProjectSettings.get_setting("application/config/version")
	_version_label.text = "%s\nv%s · pre-production" % [game_name, version]
