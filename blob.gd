@tool
extends Node2D
class_name Blob

@onready var points: Node2D = $points
@onready var polys: Node2D = $polys

#  Vertex: 1.2         Edge  .0.
#          . .               3 1
#          8.4               .2.
#
#  0 ...   4 ...   8 ...  12 ...
#    . .     . /     \ .     ===
#    ...     ./*     *\.     *.*
#
#  1 */.   5 */.   9 *|.  13 *\.
#    / .     / /     .|.     . \
#    ...     ./*     *|.     *.*
#
#  2 .\*   6 .|*  10 .\*  14 ./*
#    . \     .|.     \ \     / .
#    ...     .|*     *\.     *.*
#
#  3 *.*   7 *.*  11 *.*  15 *.*
#    ===     \ .     . /     . .
#    ...     .\*     */.     *.*
#

const edge_table = [
  [], # 0
  [3, 0], # 1
  [0, 1], # 2
  [3, 1], # 3
  [1, 2], # 4
  [3, 0, 1, 2], # 5
  [0, 2], # 6
  [3, 2], # 7
  [2, 3], # 8
  [2, 0], # 9
  [0, 1, 2, 3], # 10
  [2, 1], # 11
  [1, 3], # 12
  [1, 0], # 13
  [0, 3], # 14
  [], # 15
]

const connection_table = [
  [9, 9, 9, 9], # 0
  [9, 9, 9, 0], # 1
  [1, 9, 9, 9], # 2
  [9, 9, 9, 1], # 3
  [9, 2, 9, 9], # 4
  [9, 2, 9, 0], # 5
  [2, 9, 9, 9], # 6
  [9, 9, 9, 2], # 7
  [9, 9, 3, 9], # 8
  [9, 9, 0, 9], # 9
  [1, 9, 3, 9], # 10
  [9, 9, 1, 9], # 11
  [9, 3, 9, 9], # 12
  [9, 0, 9, 9], # 13
  [3, 9, 9, 9], # 14
  [9, 9, 9, 9], # 15
]

const edge_direction:Array[Vector2i] = [
  Vector2i(0, -1),
  Vector2i(1, 0),
  Vector2i(0, 1),
  Vector2i(-1, 0),
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

@export var generate_polygons:bool = false:
  set(value):
    generate_polygons = value
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
  if pts.size() > 2:
    var poly:Polygon2D = Polygon2D.new()
    poly.set_polygon(PackedVector2Array(pts))
    polys.add_child(poly)
    if Engine.is_editor_hint():
      poly.owner = get_tree().edited_scene_root

func calcSDF(pos:Quaternion)->Quaternion:
  var s0 = sdf(pos.x, pos.y)
  var s1 = sdf(pos.z, pos.y)
  var s2 = sdf(pos.z, pos.w)
  var s3 = sdf(pos.x, pos.w)
  return Quaternion(s0, s1, s2, s3)

func calcEdgeIndex(sdf:Quaternion)->int:
  return (1 if sdf.x >= limit else 0) \
       + (2 if sdf.y >= limit else 0) \
       + (4 if sdf.z >= limit else 0) \
       + (8 if sdf.w >= limit else 0);

# the s(df) quaternion holds the sdf values for all 4 corners
# the p(os) quaternion holds the x0, y0, x1, y1 coordinates of the 4 corners
func calcEdges(s:Quaternion, p:Quaternion)->Array[Vector2]:
  var e0 = Vector2(     remap(limit, s.x, s.y, p.x, p.z), p.y)
  var e1 = Vector2(p.z, remap(limit, s.y, s.z, p.y, p.w))
  var e2 = Vector2(     remap(limit, s.z, s.w, p.z, p.x), p.w)
  var e3 = Vector2(p.x, remap(limit, s.w, s.x, p.w, p.y))
  return [e0, e1, e2, e3]

func calc_lines()->void:
  for p in polys.get_children():
    polys.remove_child(p)
    p.queue_free()
  var visited:Dictionary = {}
  for p:BlobPoint in points.get_children():
    var pts:Array[Vector2] = []
    # start in the center of the blob and find the edge
    var cell = Vector2i(p.position.x / cell_size, p.position.y / cell_size)
    var hue = 0.0
    var from = -1
    while true:
      var rect = Quaternion(cell.x, cell.y, cell.x + 1, cell.y + 1) * cell_size
      var s = calcSDF(rect)
      var idx = calcEdgeIndex(s)
      if idx == 15:
        # check the next cell below
        if show_grid && !visited.has(cell):
          var dc = sdf(rect.x + cell_size / 2, rect.y + cell_size / 2)
          draw_rect(Rect2(rect.x, rect.y, cell_size, cell_size), Color.YELLOW, dc >= limit)
        cell.y += 1
        assert(cell.y < 1000)
        continue

      var edges = calcEdges(s, rect)
      var color = Color.from_hsv(hue, 1.0, 1.0)
      hue += 0.01
      var edge = edge_table[idx]
      if from < 0:
        from = edge[0]

      if show_grid && !visited.has(cell):
        var dc = sdf(rect.x + cell_size / 2, rect.y + cell_size / 2)
        draw_rect(Rect2(rect.x, rect.y, cell_size, cell_size), Color.CHOCOLATE, dc >= limit)

      if visited.has(cell):
        if visited[cell] & 2**from:
          commit_poly(pts)
          break;
        visited[cell] |= 2**from
      else:
        visited[cell] = 2**from
      var to = connection_table[idx][from]
      draw_line(edges[from], edges[to], color, 0.5, true)
      if generate_polygons:
        if pts.is_empty():
          pts.push_back(edges[from])
        pts.push_back(edges[to])
      # TODO: optimize and only recalc new corners
      cell += edge_direction[to]
      from = (to + 2) % 4

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

func _on_range_spin_value_changed(value: float) -> void:
  cell_size = value

func _on_btn_remove_pressed() -> void:
  if selected:
    points.remove_child(selected)
    selected.queue_free()
    selected = null
    recalc()

func _on_btn_grid_toggled(toggled_on: bool) -> void:
  show_grid = toggled_on

func _on_btn_polygons_toggled(toggled_on: bool) -> void:
  generate_polygons = toggled_on
