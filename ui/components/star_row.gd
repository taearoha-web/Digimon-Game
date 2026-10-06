class_name StarRow
extends Control
## A row of drawn stars (filled = rank). Drawn as polygons instead of text so it
## never depends on a font having the star glyphs.

var filled := 0
var total := 5
var star_size := 22.0


func _init(p_filled := 0, p_total := 5, p_size := 22.0) -> void:
	filled = p_filled
	total = p_total
	star_size = p_size
	custom_minimum_size = Vector2(total * (star_size + 4.0), star_size + 2.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func star_points(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		var a := -PI * 0.5 + TAU * float(i) / 10.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw() -> void:
	for i in total:
		var c := Vector2(star_size * 0.5 + i * (star_size + 4.0), star_size * 0.5 + 1.0)
		var pts := star_points(c, star_size * 0.52)
		if i < filled:
			draw_colored_polygon(pts, Color("ffd23c"))
			var ring := pts.duplicate()
			ring.append(pts[0])
			draw_polyline(ring, Color("b8860b"), 1.5, true)
		else:
			var ring2 := pts.duplicate()
			ring2.append(pts[0])
			draw_polyline(ring2, Color(1, 1, 1, 0.35), 1.5, true)
