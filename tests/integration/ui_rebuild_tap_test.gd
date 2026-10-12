extends Node
## A list rebuilt by one of its own buttons (dialog choices, shop, menu tabs).
## On a phone the button fires on the emulated mouse release and the touch
## release that follows still goes to that button; Godot 4.3 then calls
## can_process() on it and prints "!is_inside_tree()" if it already left the
## tree. UIUtil.clear must empty the list at once yet keep the old buttons in
## the tree until they are freed.
##   godot --headless --path . res://tests/integration/ui_rebuild_tap_test.tscn
var failures := 0
var checks := 0
var box: VBoxContainer
var _tapped: Array[Button] = []


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	box = VBoxContainer.new()
	add_child(box)
	_fill()
	await get_tree().process_frame
	var old := box.get_child(0) as Button
	var refs: Array[WeakRef] = []
	for child in box.get_children():
		refs.append(weakref(child))
	# The handler rebuilds the list from inside the button's own signal.
	old.pressed.emit()
	check(box.get_child_count() == 3, "the rebuilt list holds only the new buttons (%d)" % box.get_child_count())
	check(not (old in box.get_children()), "the tapped button left the list at once")
	check(old.is_inside_tree(), "the tapped button stays in the tree until it is freed")
	check(not old.is_visible_in_tree(), "the tapped button is hidden while it waits")
	check(old.is_queued_for_deletion(), "the tapped button is queued for deletion")
	check(old.can_process(), "the touch release that follows finds the button processable")
	await get_tree().process_frame
	await get_tree().process_frame
	var alive := 0
	for r in refs:
		if r.get_ref() != null:
			alive += 1
	check(alive == 0, "the old buttons are freed after the frame (%d alive)" % alive)
	var holder := get_tree().root.get_node_or_null(^"UIDiscard")
	check(holder != null and holder.get_child_count() == 0, "the holder is empty again")
	# A list that is not in the tree is still emptied the usual way.
	var loose := VBoxContainer.new()
	loose.add_child(Button.new())
	UIUtil.clear(loose)
	check(loose.get_child_count() == 0, "a list outside the tree is emptied too")
	loose.free()
	print("UI REBUILD TAP: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _fill() -> void:
	for i in 3:
		var b := Button.new()
		b.text = "choice %d" % i
		b.pressed.connect(func():
			UIUtil.clear(box)
			_fill())
		box.add_child(b)
