@tool
extends Node2D
class_name Blob

@onready var points: Node2D = $points
@onready var polys: Node2D = $polys

class Line:
  var p0:Vector2
  var p1:Vector2

const edge_table = [
  [],       # 0
  [0, 3],   # 1
  [1, 0],   # 2
  [1, 3],   # 3
  [2, 1],   # 4
  [2, 1, 0, 3], # 5
  [2, 0],   # 6
  [2, 3],   # 7
  [3, 2],   # 8
  [0, 2],   # 9
  [3, 2, 1, 0],   # 10
  [1, 2],   # 11
  [3, 1],   # 12
  [0, 1],   # 13
  [3, 0],   # 14
  [],   # 15
]

var selected:BlobPoint

@export_range(5.0, 50.0) var cell_size:float = 10.0:
  set(value):
    cell_size = value
    recalc()

@export_range(0.1, 5.0) var limit:float = 1.0:
  set(value):
    limit = value
    recalc()

@export var show_grid:bool = false:
  set(value):
    show_grid = value
    recalc()

func _ready():
  for b:BlobPoint in points.get_children():
    b.local_transform_changed.connect(recalc)
  if !Engine.is_editor_hint():
    for b:BlobPoint in points.get_children():
      b.clicked.connect(_on_point_clicked.bind(b))

func _on_point_clicked(event:InputEventMouseButton, pt:BlobPoint)->void:
  if event.pressed:
    select(pt, true)

func select(pt:BlobPoint, sel:bool):
  if selected:
    selected.selected = false
    selected = null
  if sel:
    pt.selected = true
    selected = pt

func _unhandled_input(event: InputEvent) -> void:
  if event is InputEventMouseMotion and event.button_mask == MOUSE_BUTTON_MASK_LEFT and selected:
    selected.global_position = event.position

func sdf(x:float, y:float)->float:
  var dist:float = 0.0
  for b:BlobPoint in points.get_children():
    dist += b.sdf(x, y)
  return dist

func commit_poly(pts:Array[Vector2])->void:
  if pts.size() > 0:
    var poly:Polygon2D = Polygon2D.new()
    poly.set_polygon(PackedVector2Array(pts))
    polys.add_child(poly)
    if Engine.is_editor_hint():
      poly.owner = get_tree().edited_scene_root

func calc_lines()->void:
  for p in polys.get_children():
    polys.remove_child(p)
    p.queue_free()
  var pts:Array[Vector2] = []
  var visited:Dictionary = {}
  var next:Vector2i
  var has_next:bool = false

  var min_x:float = INF
  var min_y:float = INF
  var max_x:float = -INF
  var max_y:float = -INF
  for p:BlobPoint in points.get_children():
    min_x = minf(min_x, p.position.x - p.radius)
    min_y = minf(min_y, p.position.y - p.radius)
    max_x = maxf(max_x, p.position.x + p.radius)
    max_y = maxf(max_y, p.position.y + p.radius)
  var r0 = -3
  var r1 = ceil((max_y - min_y) / cell_size) + 3
  var q0 = -3
  var q1 = ceil((max_x - min_x) / cell_size) + 3

  var r = r0
  var q = q0
  var hue:float = 0
  while q < q1:
    if !has_next:
      next = Vector2i(q, r)
      r += 1
      if r >= r1:
        r = r0
        q += 1
    has_next = false
    if visited.has(next):
      continue
    visited[next] = true
    var y0 = min_y + (next.y + 1) * cell_size
    var y1 = min_y + next.y * cell_size
    var x0 = min_x + next.x * cell_size
    var x1 = min_x + (next.x + 1) * cell_size
    if show_grid:
      var dc = sdf(x0 + cell_size / 2, y1 + cell_size / 2)
      draw_rect(Rect2(x0, y1, cell_size, cell_size), Color.CHOCOLATE, dc >= limit)
    var s0 = sdf(x0, y0)
    var s1 = sdf(x1, y0)
    var s2 = sdf(x1, y1)
    var s3 = sdf(x0, y1)
    var idx:int = 1 if s0 >= limit else 0
    idx += 2 if s1 >= limit else 0
    idx += 4 if s2 >= limit else 0
    idx += 8 if s3 >= limit else 0
    if idx == 0 or idx == 15:
      continue
    var e0 = Vector2(remap(limit, s0, s1, x0, x1), y0)
    var e1 = Vector2(x1, remap(limit, s1, s2, y0, y1))
    var e2 = Vector2(remap(limit, s2, s3, x1, x0), y1)
    var e3 = Vector2(x0, remap(limit, s3, s0, y1, y0))
    var edge = edge_table[idx]
    var edges = [e0, e1, e2, e3]
    var color = Color.from_hsv(hue, 1.0, 1.0)
    hue += 0.01
    const edge_direction:Array[Vector2i] = [
      Vector2i(0, 1),
      Vector2i(1, 0),
      Vector2i(0, -1),
      Vector2i(-1, 0),
    ]
    if edge.size() > 0:
      draw_line(edges[edge[0]], edges[edge[1]], color, 0.5, true)
      pts.push_back(edges[edge[0]])
      pts.push_back(edges[edge[1]])
      next += edge_direction[edge[1]]
      if visited.has(next):
        commit_poly(pts)
        pts = []
      else:
        has_next = true
    if edge.size() > 2:
      draw_line(edges[edge[2]], edges[edge[3]], color, 0.5, true)
      #pts.push_back(edges[edge[2]])
      #pts.push_back(edges[edge[3]])

  commit_poly(pts)

func recalc()->void:
  queue_redraw()

func _draw()->void:
  calc_lines()

func _on_btn_add_pressed() -> void:
  var b = BlobPoint.new()
  points.add_child(b)
  b.local_transform_changed.connect(recalc)
  b.clicked.connect(_on_point_clicked.bind(b))
  select(b, true)
