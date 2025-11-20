extends Node

func _ready():
	var nav = get_node_or_null("NavigationRegion3D")
	if not nav:
		print("NavigationRegion3D MANCANTE")
		return
	var markers = nav.get_node_or_null("Markers")
	var regions = nav.get_node_or_null("Regions")
	var doors = nav.get_node_or_null("Doors")
	if markers != null:
		var marker_names = []
		for c in markers.get_children():
			marker_names.append(c.name)
		print("Markers:", marker_names)
	else:
		print("Markers: MANCANTE")

	if regions != null:
		var region_names = []
		for c in regions.get_children():
			region_names.append(c.name)
		print("Regions:", region_names)
	else:
		print("Regions: MANCANTE")

	if doors != null:
		var door_names = []
		for c in doors.get_children():
			door_names.append(c.name)
		print("Doors:", door_names)
	else:
		print("Doors: MANCANTE")
