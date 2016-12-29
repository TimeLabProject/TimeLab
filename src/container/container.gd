extends Node2D

signal on_item_stored(container, item)

export(int) var storage_size = 10
export(NodePath) var display_node

var storage = {}
# Contains the slot nodes
var slot_list = []

func _ready():
	display_node.hide()
	for c in display_node.get_children():
		slot_list.append(c)

func is_full():
	return storage.size() == storage_size

func store_item(item, slot=null):
	if is_full():
		return
	if !slot:
		# If no slot is provided, by default the item will be stored in the first empty slot
		for s in display_node.get_children():
			if not s.has_item():
				slot = s
				break
	
	storage[slot] = item
	slot.add_child(item)

func remove_item(item):
	for k in storage:
		if storage[k] == item:
			k.remove_child(item)
			storage.erase(k)
			break

func display():
	display_node.show()