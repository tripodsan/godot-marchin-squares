extends SplitContainer

@export
var flip_split_offset:bool = false

@onready
var _dir:int = 0 if (is_instance_of(self, HSplitContainer)) else 1

@onready
var _base_split_offset:int = split_offset

func _ready() -> void:
  if flip_split_offset:
    _resize_split()
    _connect_signals()

func _connect_signals() -> void:
  connect("resized", _resize_split)
  connect("dragged", _dragged)

func _resize_split() -> void:
  split_offset = int(size[_dir]) - _base_split_offset

func _dragged(offset: int) -> void:
  _base_split_offset = int(size[_dir]) - offset
