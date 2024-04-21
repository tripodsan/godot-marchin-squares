@tool
extends Marker2D
class_name BlobPoint

signal local_transform_changed()

signal clicked(event:InputEventMouseButton)

@export_range(1.0, 200.0) var radius:float = 50.0:
  set(value):
    radius = value
    var r2 = radius * sqrt(2)
    rect = Rect2(-r2/2.0, -r2/2.0, r2, r2)
    local_transform_changed.emit()
    queue_redraw()

var rect:Rect2

var selected:bool = false:
  set(value):
    selected = value;
    queue_redraw()

@export var square:bool = false:
  set(value):
    square = value
    local_transform_changed.emit()
    queue_redraw()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  pass # Replace with function body.

func _enter_tree() -> void:
  set_notify_local_transform(true)

func _notification(what: int) -> void:
  if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
    local_transform_changed.emit()
    queue_redraw()

func _draw()->void:
  var color = Color.PLUM if selected else Color.BLUE_VIOLET
  if square:
    draw_rect(rect, color, false, 1.0)
  else:
    draw_arc(Vector2.ZERO, radius, 0, TAU, 64, color, 0.5, true)

func sdf(x:float, y:float)->float:
  var dx = position.x - x
  var dy = position.y - y
  if square:
    return (rect.size.x/2) / max(abs(dx), abs(dy))
  else:
    return radius**2 / (dx*dx + dy*dy)

func _unhandled_input(event: InputEvent) -> void:
  if event is InputEventMouseButton:
    if (event.position - global_position).length_squared() < radius**2:
      clicked.emit(event)
