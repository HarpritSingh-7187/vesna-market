extends CharacterBody3D

# --- BEGIN: configurazione scene-agnostic
@export var nav_region_path: NodePath = NodePath("/root/Root/NavigationRegion3D")
@export var markers_path: NodePath = NodePath("/root/Root/NavigationRegion3D/Markers")
@export var regions_path: NodePath = NodePath("/root/Root/NavigationRegion3D/Regions")
@export var doors_path: NodePath = NodePath("/root/Root/NavigationRegion3D/Doors")

@export var navigator_path: NodePath = NodePath("NavigationAgent3D")
@export var jump_anim_path: NodePath = NodePath("Body/Jump")
@export var idle_anim_path: NodePath = NodePath("Body/Idle")
@export var run_anim_path: NodePath = NodePath("Body/Run")

@export var desired_separation: float = 3.0  # distanza minima desiderata
@export var separation_weight: float = 5.0   # peso della forza di separazione

# --- Vision Cone Configuration ---
@export_group("Vision System")
@export var vision_enabled: bool = true
@export var vision_cone_angle: float = 120.0  # gradi
@export var vision_range: float = 5.0  # metri
@export var vision_update_interval: float = 1.0  # secondi
@export var vision_debug_draw: bool = false  # visualizzazione cono

var seen_objects: Dictionary = {}  # {object_name: true}
var vision_timer: float = 0.0
var vision_cone_mesh: MeshInstance3D = null  # per debug
# ---------------------------------

var nav_region_node = null
var markers_node = null
var regions_node = null
var doors_node = null

var navigator: NavigationAgent3D = null
var jump_anim = null
var idle_anim = null
var run_anim = null
# --- END

const SPEED = 10.0
const ACCELERATION = 8.0
const JUMP_VELOCITY = 4.5

@export var PORT : int = 9080
var tcp_server := TCPServer.new()
var ws := WebSocketPeer.new()

var regions_dict : Dictionary = {}
var current_region = ""

var end_communication = true

var target_movement : String = "empty"


func _ready() -> void:
	if tcp_server.listen( PORT ) != OK:
		push_error( "Unable to start the srver" )
		set_process( false )
	# Resolve region/marker/doors nodes from exported NodePaths (safe)
	nav_region_node = get_node_or_null(nav_region_path)
	markers_node = get_node_or_null(markers_path)
	regions_node = get_node_or_null(regions_path)
	doors_node = get_node_or_null(doors_path)

	if regions_node:
		for region in regions_node.get_children():
			region.connect( "body_entered", func( body) : _on_area_body_entered( region.name, body ) )
	else:
		# fallback: try absolute path
		var regions_fallback = get_node_or_null("/root/Root/NavigationRegion3D/Regions")
		if regions_fallback:
			for region in regions_fallback.get_children():
				region.connect( "body_entered", func( body) : _on_area_body_entered( region.name, body ) )

	if doors_node:
		for door in doors_node.get_children():
			var area = door.get_node_or_null("Area3D")
			if area:
				area.connect( "body_entered", func( body) : _on_area_body_entered( door.name, body ) )
	else:
		# fallback: try absolute path for Doors
		var doors_fallback = get_node_or_null("/root/Root/NavigationRegion3D/Doors")
		if doors_fallback:
			for door in doors_fallback.get_children():
				var area = door.get_node_or_null("Area3D")
				if area:
					area.connect( "body_entered", func( body) : _on_area_body_entered( door.name, body ) )

	# Resolve scene-local nodes safely (scene-agnostic)
	navigator = get_node_or_null(navigator_path)
	if navigator == null:
		navigator = get_node_or_null("NavigationAgent3D")
	jump_anim = get_node_or_null(jump_anim_path)
	idle_anim = get_node_or_null(idle_anim_path)
	run_anim = get_node_or_null(run_anim_path)

	play_idle()
	print("markers_node:", markers_node)
	print("regions_node:", regions_node)
	print("regions_node:", regions_node)
	print("doors_node:", doors_node)
	
	# --- Vision Debug Setup ---
	if vision_debug_draw:
		_setup_vision_debug_mesh()
	# --------------------------
	
func _process(_delta: float) -> void:
	while tcp_server.is_connection_available():
		var conn : StreamPeerTCP = tcp_server.take_connection()
		assert( conn != null )
		ws.accept_stream( conn )
		
	ws.poll()
	
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while ws.get_available_packet_count():
			var msg : String = ws.get_packet().get_string_from_ascii()
			print( "Received msg ", msg )
			var intention : Dictionary = JSON.parse_string( msg )
			manage( intention )

func _physics_process(delta: float) -> void:
	# --- Vision Update ---
	if vision_enabled:
		vision_timer += delta
		if vision_timer >= vision_update_interval:
			# Only update if moving or forced (optional optimization)
			if velocity.length() > 0.1 or vision_timer > vision_update_interval * 2:
				update_vision()
				vision_timer = 0.0
	# ---------------------

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	#var target_direction: Vector3 = (navigator.get_next_path_position() - global_transform.origin).normalized()
	
	if navigator and (navigator.is_target_reached() or navigator.is_navigation_finished()):
		play_idle()
		velocity.x = 0
		velocity.z = 0
		if not end_communication:
			signal_end_movement()
			
	elif navigator and not navigator.is_navigation_finished():
		play_run()
		var direction = ( navigator.get_next_path_position() - global_position ).normalized()
		var avoidance_force = get_avoidance_force()
		var final_direction = ( direction + avoidance_force ).normalized()
		rotation.y = atan2( -final_direction.z, final_direction.x )
		
		velocity = velocity.lerp( final_direction * SPEED, ACCELERATION * delta )
	
	move_and_slide()
	
func _on_area_body_entered( region_name, body ):
	if ( body.name == self.name ):
		print( "Agent ", self.name, " entered region ", region_name )
		if ( region_name == target_movement ):
			signal_end_movement()
			if navigator:
				navigator.set_target_position( global_position )
			else:
				print("No navigator to set target for (area enter).")
	
func _exit_tree() -> void:
	ws.close()
	tcp_server.stop()
	
func get_avoidance_force() -> Vector3:
	var force: Vector3 = Vector3.ZERO
	# Supponiamo che tutti i CharacterBody3D siano nel gruppo "players"
	for other in get_tree().get_nodes_in_group("agents"):
		if other == self:
			continue
		var diff = global_transform.origin - other.global_transform.origin
		var distance = diff.length()
		if distance < desired_separation and distance > 0:
			# La forza cresce quando la distanza diminuisce
			force += diff.normalized() / distance
	return force * separation_weight

func manage( intention : Dictionary ) -> void:
	var _sender : String = intention[ 'sender' ]
	var _receiver : String = intention[ 'receiver' ]
	var type : String = intention[ 'type' ]
	var data : Dictionary = intention[ 'data' ]
	if type == 'walk':
		if data[ 'type' ] == 'goto':
			var target : String = data[ 'target' ]
			if data.has( 'id' ):
				var id : int = data[ 'id' ]
				walk( target, id )
			else:
				walk( target, -1 )
	elif type == 'interact':
		if data[ 'type' ] == 'use':
			var art_name : String = data[ 'art_name' ]
			use( art_name )
		elif data[ 'type' ] == 'grab':
			var art_name : String = data[ 'art_name' ]
			grab( art_name )
		elif data[ 'type' ] == 'free':
			var art_name : String = data[ 'art_name' ]
			free_art( art_name )
		elif data[ 'type' ] == 'release':
			var art_name : String = data[ 'art_name' ]
			release( art_name )

func walk( target, _id ):
	var target_region = null
	# try markers
	if markers_node != null:
		target_region = markers_node.get_node_or_null(target)
	else:
		target_region = get_node_or_null(str(markers_path) + "/" + target)

	# try regions
	if target_region == null:
		if regions_node != null:
			target_region = regions_node.get_node_or_null(target)
		else:
			target_region = get_node_or_null(str(regions_path) + "/" + target)

	# try doors
	if target_region == null:
		if doors_node != null:
			target_region = doors_node.get_node_or_null(target)
		else:
			target_region = get_node_or_null(str(doors_path) + "/" + target)

	if target_region == null:
		print("Target region not found: ", target)
		return

	if navigator:
		navigator.set_target_position( target_region.global_position )
	else:
		print("walk(): navigator is null, cannot set target.")
	target_movement = target
	play_run()
	end_communication = false

func get_obj_from_group( art_name : String, group_name : String ):
	var group_objs = get_tree().get_nodes_in_group( group_name )
	for group_obj in group_objs:
		if art_name == group_obj.name:
			return group_obj
	return null
	
func use( art_name: String ):
	print( "I want to use " + art_name )
	
func grab( art_name: String ):
	var art = get_obj_from_group( art_name, "GrabbableArtifact")
	if art == null:
		print( "Object not found!")
		return
	print( "I take the hand" )
	var right_hand = get_node_or_null( "Body/Root/Skeleton3D/RightHand" )
	if ( right_hand == null ):
		print( "Oh no I do not have a hand!")
	#art.global_position = Vector3.ZERO
	art.reparent( right_hand )
	print( "reparent done" )
	#art.global_transform.origin = right_hand.position
	art.transform.origin = Vector3.ZERO
	print( "I want to grab " + art_name )

func free_art( art_name : String ):
	print( "I free " + art_name )
	
func release( art_name : String ):
	var release_points = get_tree().get_nodes_in_group( "ReleasePoint" )
	var nearest_release
	var nearest_dist = 1000
	for release_point in release_points:
		var cur_dist = release_point.global_position.distance_to( global_position )
		if  cur_dist < nearest_dist:
			nearest_release = release_point
			nearest_dist = cur_dist
	var art = get_obj_from_group( art_name, "GrabbableArtifact" )
	art.reparent( nearest_release )
	art.transform.origin = Vector3.ZERO
	print( "I release " + art_name )
	
func signal_end_movement( ) -> void:
	target_movement = "empty"
	var payload : Dictionary = {}
	payload[ 'sender' ] = 'body'
	payload[ 'receiver' ] = 'vesna'
	payload[ 'type' ] = 'signal'
	var msg : Dictionary = {}
	msg[ 'type' ] = 'movement'
	msg[ 'status' ] = 'completed'
	msg[ 'reason' ] = 'destination_reached'
	payload[ 'data' ] = msg

	# Only send if websocket is open
	if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text( JSON.stringify( payload ) )
	else:
		# Helpful debug log if connection is not open
		var state_desc = "null"
		if ws != null:
			state_desc = str(ws.get_ready_state())
			print("signal_end_movement: websocket not open, skipping send; state=", state_desc)

	end_communication = true
	
func update_region( new_region : String ) -> void:
	current_region = new_region
	if current_region not in regions_dict:
		regions_dict[ current_region ] = []
		
func play_idle() -> void:
	if run_anim and run_anim.is_playing():
		run_anim.stop()
	if idle_anim:
		idle_anim.play( "Root|Idle" )

func play_run() -> void:
	if idle_anim and idle_anim.is_playing():
		idle_anim.stop()
	if run_anim:
		run_anim.play( "Root|Run" )

# --- Vision System Implementation ---

func update_vision() -> void:
	var visible_objects = []
	var candidates = get_tree().get_nodes_in_group("GrabbableArtifact")
	
	for obj in candidates:
		if is_in_vision_cone(obj.global_position):
			# Check if already seen to set is_new flag
			var is_new = not seen_objects.has(obj.name)
			
			# Collect data
			var obj_data = {
				"name": obj.name,
				"coords": [obj.global_position.x, obj.global_position.y, obj.global_position.z],
				"is_new": is_new
			}
			
			# Add 'reparto' by traversing up the hierarchy to find the department
			# Skip nodes that look like shelves, coolers, displays, etc.
			var detected_reparto = "unknown"
			var current_node = obj.get_parent()
			var skip_keywords = ["Shelf", "shelf", "Cooler", "cooler", "Display", "display", "Rack", "rack", "Basket", "basket", "Cart", "cart"]
			
			while current_node:
				var name_check = current_node.name
				var is_container = false
				for keyword in skip_keywords:
					if keyword in name_check:
						is_container = true
						break
				
				if is_container:
					current_node = current_node.get_parent()
				else:
					detected_reparto = current_node.name
					break
			
			obj_data["reparto"] = detected_reparto
				
			visible_objects.append(obj_data)
			
			# Mark as seen
			if is_new:
				seen_objects[obj.name] = true
				
	if visible_objects.size() > 0:
		send_vision_perception(visible_objects)

func is_in_vision_cone(target_pos: Vector3) -> bool:
	# 1. Distance Check
	var distance = global_position.distance_to(target_pos)
	if distance > vision_range:
		return false
		
	# 2. Angle Check
	var direction_to_target = (target_pos - global_position).normalized()
	# Assuming agent faces -Z (Godot standard) or +Z based on model. 
	# Using basis.z if model faces Z, or -basis.z if model faces -Z.
	# Usually CharacterBody3D moves forward, so we can use velocity direction if moving,
	# or current rotation. Let's use the rotation basis.
	# NOTE: Adjust vector based on your specific model orientation!
	# Assuming agent faces +X (based on rotation logic).
	var forward_vector = global_transform.basis.x
	
	var angle_rad = forward_vector.angle_to(direction_to_target)
	var angle_deg = rad_to_deg(angle_rad)
	
	return angle_deg <= (vision_cone_angle / 2.0)

func send_vision_perception(objects: Array) -> void:
	var payload : Dictionary = {}
	payload['sender'] = 'body'
	payload['receiver'] = 'vesna'
	payload['type'] = 'perception'
	
	var data : Dictionary = {}
	data['perception_type'] = 'vision'
	data['objects'] = objects
	
	payload['data'] = data
	
	if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(payload))
		print("Sent vision perception: ", objects.size(), " objects")

func _setup_vision_debug_mesh():
	# Create a cone mesh to visualize the vision area
	var cone = CylinderMesh.new()
	cone.top_radius = tan(deg_to_rad(vision_cone_angle / 2.0)) * vision_range
	cone.bottom_radius = 0.0
	cone.height = vision_range
	
	# Material
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0, 1, 0, 0.3) # Semi-transparent green
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone.material = mat
	
	vision_cone_mesh = MeshInstance3D.new()
	vision_cone_mesh.mesh = cone
	
	# Position: The cone cylinder is centered at (0,0,0) with height Y.
	# We need to rotate it to point forward (+X) and move it so the tip is at the player.
	# Rotate Z -90 to point +X.
	add_child(vision_cone_mesh)
	
	# Adjust transform to align with forward vector (+X)
	vision_cone_mesh.position.x = vision_range / 2.0
	vision_cone_mesh.rotation.z = deg_to_rad(-90)
# ------------------------------------
