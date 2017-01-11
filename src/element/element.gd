extends KinematicBody2D

signal on_direction_change(direction)
signal on_collided(collider)	# When something collides with the element.
signal on_collide(collider)		# When the element collides with something.
signal on_clicked()
signal on_health_change(health)	    # When the health changes.
signal on_interacted(other, item)	# When this node is interacted by another one.
signal on_damaged(damage, other)	# When this node is attacked/damaged.
signal on_attack(other)		# When this node attacks another node.
signal on_death()	# When this node's health reaches zero.
signal on_client_change(client) # Called when this element's client is changed.

# State bit flags
const DEAD = int(pow(2,0)) # When this element is dead/destroyed.
const BURNING = int(pow(2,1)) # When this element is on fire.
const MUTE = int(pow(2,2)) # When this element can't talk.
const BLIND = int(pow(2,3)) # When this element can't see.
const DEAF = int(pow(2,4)) # When this element can't hear.
const CANT_WALK = int(pow(2,5)) # When this element can't walk.
const CANT_ATTACK = int(pow(2,6)) # When this element can't attack.
const CANT_USE_ITEMS = int(pow(2, 7)) # When this element can't use items.
const CANT_INTERACT = int(pow(2, 8)) # When this element can't interact with others.
const CANT_BE_INTERACTED = int(pow(2, 9)) # When others can't interact with this element.

# Direction constants
const NORTH = 0
const SOUTH = 1
const WEST = 2
const EAST = 3
const direction_index = {0 : Vector2(0, -1),
						 1 : Vector2(0, 1),
						 2 : Vector2(-1, 0),
						 3 : Vector2(1, 0)}

# Intents.

const INTENT_NONE = 0
const INTENT_INTERACT = 1
const INTENT_ATTACK = 2

export(int, "NORTH", "SOUTH", "WEST", "EAST") remote var direction = 0
export(bool) var is_movable = true
export(int, "No intent", "Interact intent", "Attack intent") remote var intent = 2 setget set_intent, get_intent
export(int) var max_health = 100
export(bool) var invincible = false
export(float) var damage_factor = 1.0
export(float) var burn_damage_factor = 1.0
export(float) var attack_factor = 1.0
export(float) var attack_delay = 0.5
export(int, FLAGS) remote var state = 0
export(int) var speed = 80
export(int) var interact_range = 100
export(int, "Neutral", "Male", "Female") var gender = 0
onready var orig_name = get_name()
#var z_floor = 0 setget set_floor,get_floor # Might get removed in the future.
var client = null setget get_client,_set_client # Do not change from this node. Call set_mob from client instead.
remote var last_pos = Vector2(0, 0)
remote var last_move = Vector2(0, 0)
remote var last_collider = null
remote var health = max_health

func _ready():
	set_pause_mode(PAUSE_MODE_STOP)
	set_pickable(true)
	set_fixed_process(true)
	set_process_input(true)
	rpc_config("emit_signal", RPC_MODE_SYNC)
	rpc_config("set_pos", RPC_MODE_SYNC)
	var attack_timer = Timer.new()
	attack_timer.set_wait_time(attack_delay)
	attack_timer.connect("timeout", self, "reset_attack_timer")
	attack_timer.set_name("AttackTimer")
	attack_timer.set_one_shot(true)
	add_child(attack_timer)
	if not timeline.right_click_menu.is_connected("item_pressed", self, "verb_pressed"):
		timeline.right_click_menu.connect("item_pressed", self, "verb_pressed")
	if not is_connected("on_clicked", self, "_on_clicked"):
		connect("on_clicked", self, "_on_clicked")
	if not is_connected("input_event", self, "_input_event"):
			connect("input_event", self, "_input_event")

#func set_floor(z):
#		z_floor = z
#
#func get_floor():
#	return z_floor
#
#sync func set_pos3(vector):
#	assert (typeof(vector) == TYPE_VECTOR3)
#	set_floor(vector.z)
#	if get_floor() == vector.z:
#		set_pos(vector.x, vector.y)
#
#func get_pos3():
#	var pos = get_pos()
#	return Vector3(pos.x, pos.y, get_floor())

func examine_element():
	timeline.get_current_client().update_chat(description)

func get_client():
	return client

sync func _set_client(new_client):
	emit_signal("on_client_change", new_client)
	if client and new_client != null:
		client.set_mob(null)
	client = new_client
	if client != null:
		set_name(str(client.get_ID()))
	else:
		set_name(orig_name)

func get_intent():
	return intent

func set_intent(new_intent):
	if not (intent < 0 or intent > 2) :
		return
	else:
		rset("intent", new_intent)
		intent = new_intent

func reset_attack_timer():
	if ((state & CANT_ATTACK) == CANT_ATTACK):
		rset("state", state ^ CANT_ATTACK)
		state ^= CANT_ATTACK

sync func damage(damage, other):
	if (not invincible):
		health -= round(damage * damage_factor)
		emit_signal("on_damaged", damage, other)
		emit_signal("on_health_change", health)
		if (health <= 0):
			health = 0
			state |= DEAD
			emit_signal("on_death", other)

func attack(other, bonus = 0):
	if (not (state & DEAD) and not (state & CANT_ATTACK)) and other extends timeline.element_base:
		var damage = (randi()%11) * (attack_factor + bonus)
		other.rpc("damage", damage, self)
		rpc("emit_signal", "on_attack", other)
		rset("state", state | CANT_ATTACK)
		state |= CANT_ATTACK
		get_node("AttackTimer").start()

func _on_clicked():
	var cmob = timeline.get_current_client().get_mob()
	if cmob:
		var intention = cmob.get_intent()
		if intention  == INTENT_INTERACT:
			rpc("emit_signal", "on_interacted", cmob, false)
		elif intention == INTENT_ATTACK:
			cmob.attack(self)

func _fixed_process(dt):
	if timeline.is_online:
		if self extends KinematicBody2D:
			if is_network_master() and timeline.get_current_client().get_mob() == self and !timeline.get_current_client().get_node("UserInterface").is_chat_visible:
				var move_direction = Vector2(0, 0)
				var old_direction = direction
				if not (state & CANT_WALK) and not (state & DEAD):
					if Input.is_action_pressed("ui_up"):
						move_direction += direction_index[NORTH]
						direction = NORTH
						last_collider = null
					if Input.is_action_pressed("ui_down"):
						move_direction += direction_index[SOUTH]
						direction = SOUTH
						last_collider = null
					if Input.is_action_pressed("ui_left"):
						move_direction += direction_index[WEST]
						direction = WEST
						last_collider = null
					if Input.is_action_pressed("ui_right"):
						move_direction += direction_index[EAST]
						direction = EAST
						last_collider = null

				if move_direction != Vector2(0, 0):
					last_pos = get_pos()
					last_move = move_direction
					move(move_direction * speed * dt)
					if is_colliding():
						var normal = get_collision_normal()
						move_direction = normal.slide(move_direction)
						last_collider = get_collider()
						emit_signal("on_collide", get_collider())
						if get_collider() extends timeline.element_base:
							get_collider().emit_signal("on_collided", self)
						move(move_direction * speed * dt)
					var new_pos = get_pos()
					if last_pos != new_pos:
						rpc("set_pos", new_pos)
					if old_direction != direction:
						rset("direction", direction)
						rpc("emit_signal", "on_direction_change", direction)

func verb_pressed(id):
	var menu = timeline.right_click_menu
	if timeline.right_click_menu_pointer == self and id > 0:
		timeline.right_click_menu_pointer = null
		call(verbs.values()[id - 1])
		menu.hide()

func receive_message(msg):
	if get_client():
		var client = get_client()
		client.update_chat(msg)

sync func hear(msg):
	if not state & DEAF:
		receive_message(msg)

func speak(msg):
	if not state & MUTE:
		for child in get_node("SpeakArea2D").get_overlapping_bodies():
			if child extends timeline.element_base:
				print(child.show_name)
				child.rpc("hear", "%s: %s" % [show_name, msg])

func _input_event(viewport, event, shape):
	if event.is_action_pressed("left_click") and not event.is_echo():
		emit_signal("on_clicked")
		get_tree().set_input_as_handled()
	if event.is_action_pressed("right_click") and not event.is_echo() and not verbs.empty():
		var menu = timeline.right_click_menu
		timeline.right_click_menu_pointer = self
		menu.clear()
		menu.add_item(show_name)
		for key in verbs:
			menu.add_item(key)
		menu.set_pos(get_pos())
		menu.show()