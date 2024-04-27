@tool
extends RigidBody2D
class_name Blob

signal updated()

@onready var points: Node2D = $points
@onready var polys: Node2D = $polys
@onready var visual: Node2D = $visual

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

@export var show_lines:bool = false:
  set(value):
    show_lines = value
    recalc()

@export var optimize_polygons:bool = false:
  set(value):
    optimize_polygons = value
    recalc()

@export var generate_polygons:bool = false:
  set(value):
    generate_polygons = value
    recalc()

@export var generate_collision:bool = true:
  set(value):
    generate_collision = value
    recalc()

## Calculate Center of Mass
@export var calc_com_enabled:bool = true:
  set(value):
    calc_com_enabled = value
    recalc()

@export_range(0.1, 20.0) var simplify_tolerance:float = 1.0:
  set(value):
    simplify_tolerance = value
    recalc()

var num_polygon_points:int = 0

## the center of all points
var center:Vector2 = Vector2.ZERO

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

func commit_poly(pts:PackedVector2Array)->void:
  if pts.size() > 2:
    # check if polygon is inside any other
    for poly:Polygon2D in polys.get_children():
      if Geometry2D.is_point_in_polygon(pts[0], poly.polygon):
        return
    if optimize_polygons:
      pts = Simplify.simplify(pts, simplify_tolerance, true)
    var poly:Polygon2D = Polygon2D.new()
    poly.set_polygon(pts)
    polys.add_child(poly)
    num_polygon_points += pts.size()
    if Engine.is_editor_hint():
      poly.owner = get_tree().edited_scene_root
    if generate_collision:
      var colpoly:CollisionPolygon2D = CollisionPolygon2D.new()
      colpoly.build_mode = CollisionPolygon2D.BUILD_SOLIDS
      colpoly.polygon = pts;
      add_child(colpoly)
      if Engine.is_editor_hint():
        colpoly.owner = get_tree().edited_scene_root


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
  num_polygon_points = 0
  if polys:
    for p in polys.get_children():
      polys.remove_child(p)
      p.queue_free()
  for p in get_children():
    if p is CollisionPolygon2D:
      remove_child(p)
      p.queue_free()

  var visited:Dictionary = {}

  # calculate center first, relative to self
  center = Vector2.ZERO
  for p:BlobPoint in points.get_children():
    center += p.position
  center = (center / points.get_child_count()) + points.position
  if !calc_com_enabled:
    # shift points
    for p:BlobPoint in points.get_children():
      p.translate_silent(-center)

  for p:BlobPoint in points.get_children():
    p.show_lines = show_lines
    var pts:PackedVector2Array = PackedVector2Array()
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
      if show_lines:
        draw_line(edges[from], edges[to], color, 0.5, true)
      if generate_polygons:
        if pts.is_empty():
          pts.push_back(edges[from])
        pts.push_back(edges[to])
      # TODO: optimize and only recalc new corners
      cell += edge_direction[to]
      from = (to + 2) % 4

  if calc_com_enabled:
    center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
    center_of_mass = center
    visual.position = center
  else:
    center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_AUTO
    if center != Vector2.ZERO:
      if Engine.is_editor_hint():
        center_blob(self)

## centers the blob using the `center` offset and repositions the points
func center_blob(state)->void:
  state.transform = state.transform.translated(center)
  center = Vector2.ZERO


func _integrate_forces(state: PhysicsDirectBodyState2D)->void:
  if !calc_com_enabled && center != Vector2.ZERO:
    center_blob(state)

func recalc()->void:
  queue_redraw()

func add_point():
  var b = BlobPoint.new()
  points.add_child(b)
  b.local_transform_changed.connect(recalc)
  b.clicked.connect(_on_point_clicked.bind(b))
  select(b, true)

func remove_point() -> void:
  if selected:
    points.remove_child(selected)
    selected.queue_free()
    selected = null
    recalc()

func _draw()->void:
  calc_lines()
  updated.emit()

var time:float = 0.0
func _process(delta:float)->void:
  if Engine.is_editor_hint():
    return
  time += delta
  var idx:int = 0
  var num = points.get_child_count()
  var speed = 2
  var d = TAU / 3
  for p:BlobPoint in points.get_children():
    var pair:int = idx / 3
    #p.position.x = pair * 150
    #p.position.y = (idx % 2 -1) * 50 + sin(time * TAU + idx*TAU/num) * 50
    p.position.x = cos(time * speed * d + idx * d) * 80 + pair * 200
    p.position.y = sin(time * speed * d + idx * d) * 50
    idx += 1



