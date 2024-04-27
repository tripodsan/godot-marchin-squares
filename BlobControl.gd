extends Control

@onready var blob: Blob = $'../blob'
@onready var limit_spin: SpinBox = $HSplitContainer/PanelContainer/VBoxContainer/limit_spin
@onready var range_spin: SpinBox = $HSplitContainer/PanelContainer/VBoxContainer/range_spin
@onready var btn_polygons: CheckButton = $HSplitContainer/PanelContainer/VBoxContainer/btn_polygons
@onready var btn_simplify: CheckButton = $HSplitContainer/PanelContainer/VBoxContainer/btn_simplify
@onready var tolerance_spin: SpinBox = $HSplitContainer/PanelContainer/VBoxContainer/tolerance_spin
@onready var btn_grid: CheckButton = $HSplitContainer/PanelContainer/VBoxContainer/btn_grid
@onready var btn_lines: CheckButton = $HSplitContainer/PanelContainer/VBoxContainer/btn_lines
@onready var num_points: Label = $HSplitContainer/PanelContainer/VBoxContainer/num_points
@onready var btn_calc_com: CheckButton = $HSplitContainer/PanelContainer/VBoxContainer/btn_calc_com

func _ready() -> void:
  limit_spin.value = blob.limit
  range_spin.value = blob.cell_size
  btn_polygons.button_pressed = blob.generate_polygons
  btn_simplify.button_pressed = blob.optimize_polygons
  tolerance_spin.value = blob.simplify_tolerance
  btn_grid.button_pressed = blob.show_lines
  btn_lines.button_pressed = blob.show_grid
  btn_calc_com.button_pressed = blob.calc_com_enabled
  blob.updated.connect(_on_blob_updated)

func _on_blob_updated()->void:
  num_points.text = '%d' % blob.num_polygon_points

func _on_range_spin_value_changed(value: float) -> void:
  blob.cell_size = value

func _on_btn_grid_toggled(toggled_on: bool) -> void:
  blob.show_grid = toggled_on

func _on_btn_polygons_toggled(toggled_on: bool) -> void:
  blob.generate_polygons = toggled_on

func _on_tolerance_spin_value_changed(value: float) -> void:
  blob.simplify_tolerance = value

func _on_btn_lines_toggled(toggled_on: bool) -> void:
  blob.show_lines = toggled_on

func _on_btn_simplify_toggled(toggled_on: bool) -> void:
  blob.optimize_polygons = toggled_on

func _on_limit_spin_value_changed(value: float) -> void:
  blob.limit = value

func _on_btn_add_pressed() -> void:
  blob.add_point()

func _on_btn_remove_pressed() -> void:
  blob.remove_point()

func _on_btn_calc_com_toggled(toggled_on: bool) -> void:
  blob.calc_com_enabled = toggled_on
