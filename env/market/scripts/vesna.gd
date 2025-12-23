extends CharacterBody3D

# Definizione Variabili per la configurazione della scena 
@export var nav_region_path: NodePath = NodePath("/root/Root/NavigationRegion3D")
@export var markers_path: NodePath = NodePath("/root/Root/NavigationRegion3D/Markers")
@export var regions_path: NodePath = NodePath("/root/Root/NavigationRegion3D/Regions")
@export var doors_path: NodePath = NodePath("/root/Root/NavigationRegion3D/Doors")

# Definizione vairiabili componenti del corpo
@export var navigator_path: NodePath = NodePath("NavigationAgent3D")
@export var jump_anim_path: NodePath = NodePath("Body/Jump")
@export var idle_anim_path: NodePath = NodePath("Body/Idle")
@export var run_anim_path: NodePath = NodePath("Body/Run")

# Definizione per il comportamento sociale
@export var desired_separation: float = 3.0  # distanza minima desiderata
@export var separation_weight: float = 5.0   # peso della forza di separazione

# Definizione per il sistema di visione
@export_group("Vision System")
@export var vision_enabled: bool = true
@export var vision_cone_angle: float = 120.0  # gradi
@export var vision_range: float = 5.0  # metri
@export var vision_update_interval: float = 1.0  # secondi
@export var vision_debug_draw: bool = false  # visualizzazione cono
@export var manual_movement_enabled: bool = false # Abilita movimento manuale (WASD/Frecce)
@export var GRAB_RANGE: float = 2.0 # Distanza per afferrare oggetti

var seen_objects: Dictionary = {}  # {object_name: {reparto, coords, visible, grabbable}}
var field_of_view: Area3D = null
var vision_cone_mesh: MeshInstance3D = null  # per debug

# Variabili Cache
var nav_region_node = null
var markers_node = null
var regions_node = null
var doors_node = null
var navigator: NavigationAgent3D = null
var jump_anim = null
var idle_anim = null
var run_anim = null

#  Variabili per Fisica del movimento
const SPEED = 10.0
const ACCELERATION = 8.0
const JUMP_VELOCITY = 4.5

# Variabili per la comunicazione
@export var PORT : int = 9080
var tcp_server := TCPServer.new()
var ws := WebSocketPeer.new()
var regions_dict : Dictionary = {}

# Variabili per tracciare lo stato della navigazione
var current_region = ""
var target_movement : String = "empty"
var end_communication = true


func _ready() -> void:
	manual_movement_enabled = true # Enable for manual testing

	# Avvio server di comunicazione
	if tcp_server.listen( PORT ) != OK:
		push_error( "Unable to start the server" )
		set_process( false )
	# Risoluzione nodi region/marker/doors dai NodePaths esportati
	nav_region_node = get_node_or_null(nav_region_path)
	markers_node = get_node_or_null(markers_path)
	regions_node = get_node_or_null(regions_path)
	doors_node = get_node_or_null(doors_path)

	#Collegamento segnali delle aree (Regions)
	if regions_node:
		for region in regions_node.get_children():
			region.connect( "body_entered", func( body) : _on_area_body_entered( region.name, body ) )
	else:
		# fallback: provo percorso assoluto
		var regions_fallback = get_node_or_null("/root/Root/NavigationRegion3D/Regions")
		if regions_fallback:
			for region in regions_fallback.get_children():
				region.connect( "body_entered", func( body) : _on_area_body_entered( region.name, body ) )

	# Collegamento segnali delle porte (Doors)
	if doors_node:
		for door in doors_node.get_children():
			var area = door.get_node_or_null("Area3D")
			if area:
				area.connect( "body_entered", func( body) : _on_area_body_entered( door.name, body ) )
	else:
		# fallback
		var doors_fallback = get_node_or_null("/root/Root/NavigationRegion3D/Doors")
		if doors_fallback:
			for door in doors_fallback.get_children():
				var area = door.get_node_or_null("Area3D")
				if area:
					area.connect( "body_entered", func( body) : _on_area_body_entered( door.name, body ) )

	# Get dei componenti interni
	navigator = get_node_or_null(navigator_path)
	if navigator == null:
		navigator = get_node_or_null("NavigationAgent3D")
	jump_anim = get_node_or_null(jump_anim_path)
	idle_anim = get_node_or_null(idle_anim_path)
	run_anim = get_node_or_null(run_anim_path)

	# avvio stato iniziale + debug
	play_idle()
	print("markers_node:", markers_node)
	print("regions_node:", regions_node)
	print("Navigator:", navigator)
	print("Jump Anim:", jump_anim)
	print("Idle Anim:", idle_anim)
	print("Run Anim:", run_anim)
	print("doors_node:", doors_node)	

	_setup_field_of_view()
	if vision_debug_draw:
		_setup_vision_debug_mesh()
	
func _process(_delta: float) -> void:
	# Accettazione nuove connessioni
	while tcp_server.is_connection_available():
		var conn : StreamPeerTCP = tcp_server.take_connection()
		assert( conn != null )
		ws.accept_stream( conn )

	# Aggiorna il WebSocket
	ws.poll()

	# Lettura e gestione dei messaggi
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while ws.get_available_packet_count():
			var msg : String = ws.get_packet().get_string_from_ascii()
			print( "Received msg ", msg )
			var intention : Dictionary = JSON.parse_string( msg )
			manage( intention )

func _physics_process(delta: float) -> void:
	# Aggiorna il sistema di visione (CHECK periodico solo per grabbability su oggetti visibili)
	if vision_enabled:
		_check_grabbability_change()

	# Aggiunge la gravità
	if not is_on_floor():
		velocity += get_gravity() * delta
	# Movimento manuale WASD	
	if manual_movement_enabled:
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_down", "ui_up")
		var direction = Vector3(input_dir.y, 0, input_dir.x).normalized()
		
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
			rotation.y = atan2(-velocity.z, velocity.x)
			play_run()
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
			play_idle()
	# Movimento automatico per la navigazione
	# Se la navigazione è finita o il target è raggiunto:
	elif navigator and (navigator.is_target_reached() or navigator.is_navigation_finished()):
		play_idle()
		velocity.x = 0
		velocity.z = 0
		if not end_communication:
			signal_end_movement()
			
	# Se la navigazione non è finita:
	elif navigator and not navigator.is_navigation_finished():
		play_run()
		var direction = ( navigator.get_next_path_position() - global_position ).normalized()
		var avoidance_force = get_avoidance_force()
		var final_direction = ( direction + avoidance_force ).normalized()
		rotation.y = atan2( -final_direction.z, final_direction.x )
		
		velocity = velocity.lerp( final_direction * SPEED, ACCELERATION * delta )
	
	move_and_slide()
	
# Funzione callback per il segnale body_entered
func _on_area_body_entered( region_name, body ):
	# Se il corpo è lo stesso dell'agente
	if ( body.name == self.name ):
		print( "Agent ", self.name, " entered region ", region_name )
		# verifico se zona corrisponde ad obiettivo
		if ( region_name == target_movement ):
			# invio segnale di fine movimento
			print( "Agent ", self.name, " reached target ", target_movement )
			signal_end_movement()
			# fermo la navigazione 
			if navigator:
				navigator.set_target_position( global_position )
			else:
				print("No navigator to set target for (area enter).")
	
# chiusura connessione
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
	# Parsing del messaggio
	var _sender : String = intention[ 'sender' ]
	var _receiver : String = intention[ 'receiver' ]
	var type : String = intention[ 'type' ]
	var data : Dictionary = intention[ 'data' ]
	# Gestione Movimento
	if type == 'walk':
		if data[ 'type' ] == 'goto':
			var target : String = data[ 'target' ]
			if data.has( 'id' ):
				var id : int = data[ 'id' ]
				walk( target, id )
			else:
				walk( target, -1 )
	# Gestione Interazione
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
	# Ricerca destinazione
	# Prova con i markers
	if markers_node != null:
		target_region = markers_node.get_node_or_null(target)
	else:
		target_region = get_node_or_null(str(markers_path) + "/" + target)

	# Prova con le regioni
	if target_region == null:
		if regions_node != null:
			target_region = regions_node.get_node_or_null(target)
		else:
			target_region = get_node_or_null(str(regions_path) + "/" + target)

	# Prova con le porte
	if target_region == null:
		if doors_node != null:
			target_region = doors_node.get_node_or_null(target)
		else:
			target_region = get_node_or_null(str(doors_path) + "/" + target)

	# Controllo validità destinazione
	if target_region == null:
		print("Target region not found: ", target)
		return

	# Avvio navigazione
	if navigator:
		navigator.set_target_position( target_region.global_position )
	else:
		print("walk(): navigator is null, cannot set target.")

	# Aggiornamento stato
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
	# Ricerca oggetto
	if art == null:
		print( "Object not found!")
		return
	# Cerca la mano
	print( "I take the hand" )
	var right_hand = get_node_or_null( "Body/Root/Skeleton3D/RightHand" )
	if ( right_hand == null ):
		print( "Oh no I do not have a hand!")
	#art.global_position = Vector3.ZERO
	# Reparent oggetto preso
	art.reparent( right_hand )
	print( "reparent done" )
	#art.global_transform.origin = right_hand.position
	art.transform.origin = Vector3.ZERO
	print( "I want to grab " + art_name )

func free_art( art_name : String ):
	print( "I free " + art_name )
	
	
func release( art_name : String ):
	# Ricerca punto di rilascio più vicino
	var release_points = get_tree().get_nodes_in_group( "ReleasePoint" )
	var nearest_release
	var nearest_dist = 1000
	for release_point in release_points:
		var cur_dist = release_point.global_position.distance_to( global_position )
		if  cur_dist < nearest_dist:
			nearest_release = release_point
			nearest_dist = cur_dist
	# Prendo oggetto
	var art = get_obj_from_group( art_name, "GrabbableArtifact" )
	# Reparent oggetto rilasciato
	art.reparent( nearest_release )
	art.transform.origin = Vector3.ZERO
	print( "I release " + art_name )
	
func signal_end_movement( ) -> void:
	# Reset stato
	target_movement = "empty"
	var payload : Dictionary = {}

	# Costruzione payload
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



func _setup_field_of_view() -> void:
	field_of_view = Area3D.new()
	field_of_view.name = "FieldOfView"
	add_child(field_of_view)
	
	# Configurazione cono Field of View
	var cone_mesh = CylinderMesh.new()
	cone_mesh.top_radius = tan(deg_to_rad(vision_cone_angle / 2.0)) * vision_range
	cone_mesh.bottom_radius = 0.0
	cone_mesh.height = vision_range
	
	var shape = cone_mesh.create_convex_shape()
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = shape
	field_of_view.add_child(collision_shape)
	
	# Posizionamento cono in avanti (+X)
	collision_shape.position.x = vision_range / 2.0
	collision_shape.rotation.z = deg_to_rad(-90)
	
	field_of_view.body_entered.connect(_on_field_of_view_body_entered)
	field_of_view.body_exited.connect(_on_field_of_view_body_exited)
	
func _on_field_of_view_body_entered(body: Node3D) -> void:
	# Converti StaticBody3D in MeshInstance3D
	var artifact = body.get_parent()
	if artifact == null or not artifact.is_in_group("GrabbableArtifact"):
		return
		
	if not has_line_of_sight(artifact.global_position):
		return
		
	var artifact_name = artifact.name
	var is_new = not seen_objects.has(artifact_name)
	var obj_data = seen_objects.get(artifact_name, {})
	
	# Aggiorna stato oggetto
	obj_data["visible"] = true
	if not obj_data.has("reparto"):
		obj_data["reparto"] = deduce_reparto(artifact)
	obj_data["coords"] = [artifact.global_position.x, artifact.global_position.y, artifact.global_position.z]
	
	var is_grabbable = is_within_grab_range(artifact)
	obj_data["grabbable"] = is_grabbable
	
	seen_objects[artifact_name] = obj_data

	send_object_state("seen", artifact_name, obj_data, is_new)
	if is_grabbable:
		send_object_state("grabbable", artifact_name, obj_data, false)

func _on_field_of_view_body_exited(body: Node3D) -> void:
	var artifact = body.get_parent()
	if artifact == null: return
	
	var artifact_name = artifact.name
	if seen_objects.has(artifact_name) and seen_objects[artifact_name]["visible"]:
		seen_objects[artifact_name]["visible"] = false
		seen_objects[artifact_name]["grabbable"] = false
		send_object_state("lost", artifact_name, seen_objects[artifact_name], false)

func _check_grabbability_change() -> void:
	# Controlla grabbability solo per oggetti visibili
	for obj_name in seen_objects:
		var data = seen_objects[obj_name]
		if data["visible"]:
			var obj = get_obj_from_group(obj_name, "GrabbableArtifact")
			if obj:
				var is_now_grabbable = is_within_grab_range(obj)
				if data["grabbable"] != is_now_grabbable:
					data["grabbable"] = is_now_grabbable
					send_object_state("grabbable" if is_now_grabbable else "not_grabbable", obj_name, data, false)

func deduce_reparto(obj: Node3D) -> String:
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
	return detected_reparto

func is_within_grab_range(obj: Node3D) -> bool:
	var hand_pos = global_position + Vector3(0, 1.5, 0)
	var dist = hand_pos.distance_to(obj.global_position)
	return dist <= GRAB_RANGE

func send_object_state(status: String, name: String, data: Dictionary, is_new: bool) -> void:
	var payload : Dictionary = {}
	payload['sender'] = 'body'
	payload['receiver'] = 'vesna'
	payload['type'] = 'perception'
	
	var msg_data : Dictionary = {}
	msg_data['perception_type'] = 'object_state'
	msg_data['event'] = status
	msg_data['object'] = {
		"name": name,
		"reparto": data["reparto"],
		"coords": data.get("coords", [0,0,0]),
		"grabbable": data.get("grabbable", false),
		"is_new": is_new
	}
	payload['data'] = msg_data
	
	if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(payload))

func is_in_vision_cone(target_pos: Vector3) -> bool:
	# 1. Controllo distanza
	var distance = global_position.distance_to(target_pos)
	if distance > vision_range:
		return false
		
	# 2. Calcolo direzione ed orientamento
	var direction_to_target = (target_pos - global_position).normalized()
	var forward_vector = global_transform.basis.x
	
	var angle_rad = forward_vector.angle_to(direction_to_target)
	var angle_deg = rad_to_deg(angle_rad)
	
	return angle_deg <= (vision_cone_angle / 2.0) and has_line_of_sight(target_pos)

func has_line_of_sight(target_pos: Vector3) -> bool:
	# Preparazione raycast per controllo visibilità
	var space_state = get_world_3d().direct_space_state
	var ray_origin = global_position + Vector3(0, 0.5, 0)
	var ray_target = target_pos + Vector3(0, 0.5, 0)
	
	# Esecuzione query
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_dist = ray_origin.distance_to(result.position)
		var target_dist = ray_origin.distance_to(ray_target)
		
		# Se abbiamo colpito qualcosa più vicino del bersaglio, è un ostacolo.
		if hit_dist < target_dist - 0.2: # 20cm tolerance
			return false
		
	return true

func send_vision_perception(objects: Array) -> void:
	# Deprecato da send_object_state, tengo per compatibilità se necessario
	pass

func _setup_vision_debug_mesh():
	# Creazione mesh per debug visuale
	var cone = CylinderMesh.new()
	cone.top_radius = tan(deg_to_rad(vision_cone_angle / 2.0)) * vision_range
	cone.bottom_radius = 0.0
	cone.height = vision_range
	
	# Creazione material
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0, 1, 0, 0.3) # Semi-transparent green
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone.material = mat
	
	vision_cone_mesh = MeshInstance3D.new()
	vision_cone_mesh.mesh = cone
	
	# Posizionamento nella Scena
	add_child(vision_cone_mesh)
	
	vision_cone_mesh.position.x = vision_range / 2.0
	vision_cone_mesh.rotation.z = deg_to_rad(-90)
