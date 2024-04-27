extends Node
class_name Simplify

# adapted from mourner.github.io/simplify-js

# square distance from a point to a segment
static func getSqSegDist(p:Vector2, p1:Vector2, p2:Vector2)->float:
  var x = p1.x
  var y = p1.y
  var dx = p2.x - x
  var dy = p2.y - y

  if (dx != 0 || dy != 0):
    var t = ((p.x - x) * dx + (p.y - y) * dy) / (dx * dx + dy * dy)
    if (t > 1):
      x = p2.x;
      y = p2.y;
    elif (t > 0):
      x += dx * t
      y += dy * t

  dx = p.x - x;
  dy = p.y - y;
  return dx * dx + dy * dy;

# basic distance-based simplification
static func simplifyRadialDist(points:PackedVector2Array, sqTolerance:float)->PackedVector2Array:
  var prevPoint = points[0]
  var newPoints:PackedVector2Array = PackedVector2Array([prevPoint])
  var point
  for i in range(1, points.size()):
    point = points[i]
    if (point.distance_squared_to(prevPoint) > sqTolerance):
      newPoints.push_back(point);
      prevPoint = point;

  if (prevPoint != point):
    newPoints.push_back(point);
  return newPoints;

static func simplifyDPStep(points:PackedVector2Array, first:int, last:int, sqTolerance:float, simplified:PackedVector2Array):
  var maxSqDist = sqTolerance
  var index

  for i:int in range(first + 1, last):
    var sqDist = getSqSegDist(points[i], points[first], points[last]);
    if (sqDist > maxSqDist):
      index = i;
      maxSqDist = sqDist;

  if (maxSqDist > sqTolerance):
      if (index - first > 1):
        simplifyDPStep(points, first, index, sqTolerance, simplified);
      simplified.push_back(points[index]);
      if (last - index > 1):
        simplifyDPStep(points, index, last, sqTolerance, simplified);

# simplification using Ramer-Douglas-Peucker algorithm
static func simplifyDouglasPeucker(points:PackedVector2Array, sqTolerance:float)->PackedVector2Array:
  var last = points.size() - 1;
  var simplified:PackedVector2Array = PackedVector2Array([points[0]])
  simplifyDPStep(points, 0, last, sqTolerance, simplified);
  simplified.push_back(points[last]);
  return simplified;

# both algorithms combined for awesome performance
static func simplify(points:PackedVector2Array, tolerance:float = 1, highestQuality:bool = false)->PackedVector2Array:
  if (points.size() <= 2):
      return points;

  var sqTolerance = tolerance * tolerance

  if !highestQuality:
    points = simplifyRadialDist(points, sqTolerance)
  points = simplifyDouglasPeucker(points, sqTolerance)
  return points
