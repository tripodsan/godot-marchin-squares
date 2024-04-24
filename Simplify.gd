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
static func simplifyRadialDist(points:Array[Vector2], sqTolerance:float)->Array[Vector2]:
  var prevPoint = points[0]
  var newPoints = [prevPoint]
  var point
  for i in range(1, points.size()):
    point = points[i]
    if (point.distance_squared_to(prevPoint) > sqTolerance):
      newPoints.push(point);
      prevPoint = point;

  if (prevPoint != point):
    newPoints.push(point);
  return newPoints;

static func simplifyDPStep(points:Array[Vector2], first:int, last:int, sqTolerance:float, simplified:Array[Vector2]):
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
static func simplifyDouglasPeucker(points:Array[Vector2], sqTolerance:float)->Array[Vector2]:
  var last = points.size() - 1;
  var simplified:Array[Vector2] = [points[0]]
  simplifyDPStep(points, 0, last, sqTolerance, simplified);
  simplified.push_back(points[last]);
  return simplified;

# both algorithms combined for awesome performance
static func simplify(points:Array[Vector2], tolerance:float = 1, highestQuality:bool = false)->Array[Vector2]:
  if (points.size() <= 2):
      return points;

  var sqTolerance = tolerance * tolerance

  if !highestQuality:
    points = simplifyRadialDist(points, sqTolerance)
  points = simplifyDouglasPeucker(points, sqTolerance)
  return points
