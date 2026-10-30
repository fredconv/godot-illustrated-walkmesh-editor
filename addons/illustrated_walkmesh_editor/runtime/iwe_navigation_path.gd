class_name IWENavigationPath
extends RefCounted
## Helpers for characters that follow a path planned on the navigation an IWE stage exports. Nothing
## here belongs to a particular character: any controller can call them.
##
## The navigation mesh of a stage follows the outline of the walkable zones and of their cutouts exactly,
## so a path from NavigationServer3D touches every obstacle corner it goes around. A character with a
## body (a capsule with a radius) cannot round such a corner and stalls on it. `with_corner_clearance`
## moves each inner point of a path away from the edge, so the body has room.

const CLEARANCE_DIRECTIONS := 16


## Moves each corner of `path` away from the edge of the walkable area by up to `clearance` (world
## units: use the radius of your character plus a little). The first and last points stay, and a corner
## only moves to a spot that is still walkable and has less wall around it. A clearance of zero, or a
## path of fewer than three points, comes back unchanged.
static func with_corner_clearance(map: RID, path: PackedVector3Array, clearance: float) -> PackedVector3Array:
	if clearance <= 0.0 or path.size() < 3:
		return path
	var cleared := path.duplicate()
	for index in range(1, path.size() - 1):
		cleared[index] = _clear_of_edges(map, path[index], clearance)
	return cleared


## Plans a path on the navigation map from `from` to the walkable point nearest to `to`, with corner
## clearance applied. An empty path means the map has not synchronized its regions yet (try again on
## the next physics frame) or `from` is not on the walkable area.
static func plan(map: RID, from: Vector3, to: Vector3, clearance: float) -> PackedVector3Array:
	var target := NavigationServer3D.map_get_closest_point(map, to)
	return with_corner_clearance(map, NavigationServer3D.map_get_path(map, from, target, true), clearance)


static func _clear_of_edges(map: RID, point: Vector3, clearance: float) -> Vector3:
	var blocked := _blocked_directions(map, point, clearance)
	if blocked.is_empty():
		return point
	var away := Vector3.ZERO
	for direction in blocked:
		away -= direction
	if away.length() < 0.001:
		return point
	away = away.normalized()
	var best := point
	var best_blocked := blocked.size()
	for fraction in [0.25, 0.5, 0.75, 1.0]:
		var candidate: Vector3 = point + away * clearance * fraction
		candidate.y = point.y
		var snapped := NavigationServer3D.map_get_closest_point(map, candidate)
		if snapped.distance_to(candidate) > 0.001:
			continue
		var count := _blocked_directions(map, candidate, clearance).size()
		if count < best_blocked:
			best = candidate
			best_blocked = count
	return best


## Directions on the floor in which the walkable area ends within `clearance` of the point.
static func _blocked_directions(map: RID, point: Vector3, clearance: float) -> Array[Vector3]:
	var blocked: Array[Vector3] = []
	for step in CLEARANCE_DIRECTIONS:
		var angle := TAU * float(step) / float(CLEARANCE_DIRECTIONS)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var probe := point + direction * clearance
		var closest := NavigationServer3D.map_get_closest_point(map, probe)
		if closest.distance_to(probe) > clearance * 0.05:
			blocked.append(direction)
	return blocked
