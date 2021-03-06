extends Node

signal game_start()
signal game_end()
signal camera_change(new_camera)

const direction = {
"NORTH" : Vector2(0, -1),
"NORTHWEST" : Vector2(-1, -1),
"WEST" : Vector2(-1, 0),
"SOUTHWEST" : Vector2(-1, 1),
"SOUTH" : Vector2(0, 1),
"SOUTHEAST" : Vector2(1, 1),
"EAST" : Vector2(1, 0),
"NORTHEAST" : Vector2(1, -1)}
const states = {}
const disabilities = {
"CANNOT_WALK" : int(pow(2, 0))}
const base = {
"element" : "res://src/element/element.gd",
"client" : "res://src/client.gd",
"mind" : "res://src/module/mind/mind.gd",
"human" : "res://src/mob/human/human.tscn"
}

sync var game_started = false setget has_game_started, set_game_started	# Whether the game has started or not. Should not be changed manually.
sync var map = null setget ,set_current_map	# Map instance
onready var network = NetworkedMultiplayerENet.new()
var _active_camera = null setget get_active_camera, set_active_camera

func _ready():
	rpc_config("emit_signal", RPC_MODE_SYNC)
	network.connect("connection_failed", self, "_on_connection_failed")
	network.connect("connection_succeeded", self, "_on_connection_success")
	network.connect("server_disconnected", self, "_on_server_disconnect")
	network.connect("peer_connected", self, "_on_peer_connect")
	network.connect("peer_disconnected", self, "_on_peer_disconnect")

func has_game_started():
	return game_started

sync func set_current_map(new_map):
	if typeof(new_map) == TYPE_STRING or typeof(new_map) == TYPE_NODE_PATH:
		map = get_node(new_map)
	elif typeof(new_map) == TYPE_OBJECT and new_map is TileMap:
		map = new_map
	else:
		raise()
	
sync func set_game_started(value):
	game_started = value
	if value:
		emit_signal("game_start")
	else:
		emit_signal("game_end")
		
func get_client(ID):
	for client in get_tree().get_nodes_in_group("clients"):
		if client.ID == ID:
			return client
	return false
	
func get_current_client():
	return get_client(get_tree().get_network_unique_id())
	
sync func instance(object, parent_path, variables={}, call_functions=[], name=""):
	assert typeof(parent_path) == TYPE_NODE_PATH
	assert typeof(variables) == TYPE_DICTIONARY
	if typeof(object) == TYPE_STRING:
		object = load(object)
		print(typeof(object))
		assert typeof(object) == TYPE_OBJECT
		if object.has_method("instance"):
			object = object.instance()
		elif object.has_method("new"):
			object = object.new()
		else:
			raise()
	elif typeof(object) == TYPE_OBJECT:
		if object.has_method("instance"):
			object = object.instance()
		elif object.has_method("new"):
			object = object.new()
		else:
			raise()
	assert typeof(object) == TYPE_OBJECT and object is Node
	for variable in variables.keys():
		if variable != "script":
			object.set(variable, variables[variable])
	for method in call_functions:
		object.call(method)
	assert typeof(name) == TYPE_STRING
	if name.strip_edges().length() > 0:
		object.set_name(name)
	get_node(parent_path).add_child(object, true)
	return object

func create_server(port=7777, max_players=32):
	network.create_server(port, max_players)
	get_tree().set_network_peer(network)
	get_tree().change_scene("res://src/game.tscn")
	var server = load(base.client).new()
	server.ID = get_tree().get_network_unique_id()
	server.set_name("Host")
	add_child(server)
	
func join_game(ip="127.0.0.1", port=7777):
	network.create_client(ip, port)
	get_tree().set_network_peer(network)
	
func _on_connection_failed():
	print("Connection failed.")
	print(network.get_packet_error())
	get_tree().change_scene("res://src/menu/title/title.tscn")
	
func _on_connection_success():
	get_tree().change_scene("res://src/game.tscn")
	
func _on_server_disconnect():
	print("Server disconnected!")
	get_tree().quit()
	
func _on_peer_connect(ID):
	if get_tree().is_network_server():
		for client in get_tree().get_nodes_in_group("clients"):
			var variables = {}
			for i in client.get_property_list():
				variables[i["name"]] = client.get(i["name"])
			rpc_id(ID, "instance", base.client, get_path(), variables, [], client.get_name())
		rpc("instance", base.client, get_path(), {"ID" : ID}, [], "Scientist")

func _on_peer_disconnect(ID):
	get_client(ID).rset("is_alive", false)
	
sync func rename(path, name):
	assert typeof(path) == TYPE_NODE_PATH
	get_node(path).set_name(name)
	
func has_active_camera():
	if typeof(_active_camera) == TYPE_OBJECT:
		if _active_camera is Camera2D:
			return true
	return false
	
func get_active_camera():
	return _active_camera

func set_active_camera(reference):
	assert typeof(reference) == TYPE_OBJECT
	assert reference is Camera2D
	_active_camera = reference
	emit_signal("camera_change", reference)

func _process(dt):
	if has_active_camera():
		if not get_active_camera().is_current():
			get_active_camera().make_current()