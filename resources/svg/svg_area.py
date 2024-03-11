
import sys

from svg.path import parse_path
from shapely.geometry import Polygon
from svg.path.path import Line

def calculate_area(svg_path_data):
    path = parse_path(svg_path_data)
    points = []

    for segment in path:
        if isinstance(segment, Line):
            points.extend([(segment.start.real, segment.start.imag),
                           (segment.end.real, segment.end.imag)])

    polygon = Polygon(points)
    area = polygon.area

    return abs(area)


area = calculate_area(sys.argv[1])

print(area)
