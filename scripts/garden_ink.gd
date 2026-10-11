class_name GardenInk
extends RefCounted

## The rasterising primitives every glyph is built from: stamps, lines, dots,
## rings, arcs, polygons, hearts, drops and stars.
##
## Split out of GardenGlyphs. None of these know what a lantern or a stanza is --
## they only know how to put ink on an Image -- which is what makes them a
## separate concern from the tables that decide WHERE the ink goes.

static func _at(u: float, v: float, s: float) -> Vector2:
        ## A point in the normalized glyph box, scaled to the texture size.
        return Vector2(u * s, v * s)

static func _stamp(image: Image, at: Vector2, radius: float, color: Color, softness: float = 1.0) -> void:
        var size := image.get_width()
        var reach := int(ceil(radius + 1.0))
        var x0 := maxi(0, int(floor(at.x)) - reach)
        var x1 := mini(size - 1, int(ceil(at.x)) + reach)
        var y0 := maxi(0, int(floor(at.y)) - reach)
        var y1 := mini(size - 1, int(ceil(at.y)) + reach)
        for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                        var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(at)
                        var alpha := clampf((radius - d) / maxf(0.5, softness), 0.0, 1.0)
                        if alpha <= 0.0:
                                continue
                        var existing := image.get_pixel(x, y)
                        var out_a := alpha + existing.a * (1.0 - alpha)
                        var mixed := Color(
                                (color.r * alpha + existing.r * existing.a * (1.0 - alpha)) / out_a,
                                (color.g * alpha + existing.g * existing.a * (1.0 - alpha)) / out_a,
                                (color.b * alpha + existing.b * existing.a * (1.0 - alpha)) / out_a,
                                out_a
                        )
                        image.set_pixel(x, y, mixed)

static func _line(image: Image, from: Vector2, to: Vector2, color: Color, width: int) -> void:
        var length := from.distance_to(to)
        var steps := maxi(1, int(ceil(length)))
        for step in range(steps + 1):
                var at := from.lerp(to, float(step) / float(steps))
                _stamp(image, at, maxf(0.6, float(width) * 0.5), color)

static func _dot(image: Image, at: Vector2, radius: float, color: Color) -> void:
        _stamp(image, at, radius, color)

static func _glow_dot(image: Image, at: Vector2, radius: float, color: Color) -> void:
        # Three passes, widest and faintest first: a cheap soft bloom that keeps
        # every glowing glyph warm rather than a hard disc.
        _stamp(image, at, radius * 1.55, Color(color.r, color.g, color.b, color.a * 0.22))
        _stamp(image, at, radius * 1.18, Color(color.r, color.g, color.b, color.a * 0.55))
        _stamp(image, at, radius, color)

static func _ellipse_ring(image: Image, center: Vector2, radius_x: float, radius_y: float, color: Color, width: int) -> void:
        var thickness := maxf(0.7, float(width) * 0.5)
        var steps := maxi(28, int((radius_x + radius_y) * 2.4))
        for step in range(steps):
                var angle := TAU * float(step) / float(steps)
                var at := center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
                _stamp(image, at, thickness, color)
                # A second stamp on the opposite side of the ring, so the inner and
                # outer walls are both filled by the same sweep.
                var inward := center + Vector2(cos(angle) * (radius_x - thickness), sin(angle) * (radius_y - thickness))
                _stamp(image, inward, thickness, color)

static func _arc_cap(image: Image, center: Vector2, radius: float, from_angle: float, to_angle: float, color: Color, width: int) -> void:
        var thickness := maxf(0.7, float(width) * 0.5)
        var steps := maxi(12, int(radius * 1.8))
        for step in range(steps + 1):
                var angle: float = lerpf(from_angle, to_angle, float(step) / float(steps))
                var at := center + Vector2(cos(angle), sin(angle)) * radius
                _stamp(image, at, thickness, color)

static func _poly(image: Image, points: PackedVector2Array, color: Color, width: int, closed: bool) -> void:
        if points.size() < 2:
                return
        for index in range(points.size() - 1):
                _line(image, points[index], points[index + 1], color, width)
        if closed and points.size() > 2:
                _line(image, points[points.size() - 1], points[0], color, width)

static func _rect(image: Image, top_left: Vector2, width: float, height: float, color: Color, filled: bool, line_width: int) -> void:
        var right := top_left.x + width
        var bottom := top_left.y + height
        if filled:
                var thickness := maxf(1.0, float(line_width))
                for y in range(maxi(0, int(top_left.y)), mini(image.get_height() - 1, int(bottom)) + 1):
                        for x in range(maxi(0, int(top_left.x)), mini(image.get_width() - 1, int(right)) + 1):
                                _stamp(image, Vector2(float(x) + 0.5, float(y) + 0.5), thickness * 0.5, color)
        else:
                _poly(image, PackedVector2Array([top_left, Vector2(right, top_left.y), Vector2(right, bottom), Vector2(top_left.x, bottom)]), color, line_width, true)

static func _heart(image: Image, center: Vector2, radius: float, color: Color) -> void:
        # The classic two-lobe parametric heart, stroked densely enough (96
        # segments, width 2) to read as a heart at 24px. If it ever reads thin,
        # the fix is a scanline fill inside this outline, not a wider stroke.
        var steps := 96
        var points := PackedVector2Array()
        for step in range(steps + 1):
                var t := TAU * float(step) / float(steps)
                var x := 16.0 * pow(sin(t), 3.0)
                var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
                points.append(center + Vector2(x, y) * (radius / 16.0))
        for index in range(points.size()):
                var from := points[index]
                var to := points[(index + 1) % points.size()]
                _line(image, from, to, color, 2)

static func _drop(image: Image, center: Vector2, radius: float, color: Color) -> void:
        _ellipse_ring(image, center, radius * 0.78, radius, color, 2)
        _poly(image, PackedVector2Array([center + Vector2(0, -radius * 1.35), center + Vector2(-radius * 0.62, -radius * 0.25), center + Vector2(radius * 0.62, -radius * 0.25)]), color, 2, true)

static func _star(image: Image, center: Vector2, outer: float, inner: float, points: int, color: Color) -> void:
        var vertices := PackedVector2Array()
        var total := points * 2
        for step in range(total):
                var angle := -PI * 0.5 + TAU * float(step) / float(total)
                var reach: float = outer if step % 2 == 0 else inner
                vertices.append(center + Vector2(cos(angle), sin(angle)) * reach)
        for index in range(vertices.size()):
                _line(image, vertices[index], vertices[(index + 1) % vertices.size()], color, 3)
        # Fill the middle so the star reads as solid light, not a wire star.
        for index in range(vertices.size()):
                _line(image, center, vertices[index], color, 2)
