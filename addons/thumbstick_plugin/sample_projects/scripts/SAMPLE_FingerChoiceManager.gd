# MIT License - Copyright (c) 2025 | JoenTNT
# Permission is granted to use, copy, modify, and distribute this file
# for any purpose with or without fee, provided the above notice is included.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.

class_name SAMPLE_FingerChoiceManager
extends Node2D

# Constants
const POSITION_KEY: String = "pos";
const IS_ACTIVE_KEY: String = "is_active";
const MODEL_KEY: String = "model";

# Properties
@export var _display_pointer_pref: PackedScene = null;
## Every finger color by index starting from first to last.
## This will also limit how many fingers that can be presented inside the gameplay.
@export var _colors: Array[Color] = [];
## Delay submission on which finger will be randomly chosen.
## This will be run if any finger presented.
@export var _delay_countdown = 5.0;
@export var _focuser: SAMPLE_BackgroundHoleSetter = null;
@export var _countdown_text: RichTextLabel = null;

# Runtime variable data.
@onready var _rand: RandomNumberGenerator = RandomNumberGenerator.new();
var _listed_fingers: Dictionary = {};
var _this_scene: Node = null;
var _temp_pos: Vector2 = Vector2.ZERO;
var _index: int = 0;
var _index_counter: Array[int] = [];
var _max_finger: int = 0;
var _countdown: float = 0.0;
var _do_countdown: bool = false;
var _choosen_index: int = 0;
var _format_txt: String;

func _ready() -> void:
	_format_txt = _countdown_text.text;
	_countdown_text.text = "";
	_this_scene = get_tree().current_scene;
	var sz: int = _colors.size();
	for i in range(0, sz):
		_listed_fingers[i] = {};
		_listed_fingers[i][MODEL_KEY] = _display_pointer_pref.instantiate();
		_listed_fingers[i][MODEL_KEY].modulate = _colors[i];
		_this_scene.add_child(_listed_fingers[i][MODEL_KEY]);
	_index_counter.clear();

func _process(delta: float) -> void:
	if _focuser.is_shrunked():
		_focuser.position = _listed_fingers[_choosen_index][POSITION_KEY];
	if !_do_countdown: return;
	_countdown -= delta;
	_countdown_text.text = _format_txt % str(ceil(_countdown));
	if _countdown > 0.0: return;
	_choosen_index = _index_counter[_rand.randi_range(0, _index_counter.size() - 1)];
	if !_focuser.is_shrunked():
		_countdown_text.text = "";
		_focuser.set_outer_color(_colors[_choosen_index % _colors.size()]);
		_focuser.shrink_hole();
	_do_countdown = false;

func on_pressed(args: MultiTouchOnPressed) -> void:
	_index = args.finger_index;
	_temp_pos = args.pressed_position;
	_listed_fingers[_index][POSITION_KEY] = _temp_pos;
	_listed_fingers[_index][IS_ACTIVE_KEY] = true;
	_listed_fingers[_index][MODEL_KEY].visible = true;
	_listed_fingers[_index][MODEL_KEY].process_mode = PROCESS_MODE_INHERIT;
	_listed_fingers[_index][MODEL_KEY].position = _temp_pos;
	_index_counter.push_back(_index);
	if _index_counter.size() > 0 && !_focuser.is_shrunked():
		_countdown = _delay_countdown;
		_do_countdown = true;

func on_released(args: MultiTouchOnReleased) -> void:
	_index = args.finger_index;
	_listed_fingers[_index][IS_ACTIVE_KEY] = false;
	_listed_fingers[_index][MODEL_KEY].visible = false;
	_listed_fingers[_index][MODEL_KEY].process_mode = PROCESS_MODE_DISABLED;
	_countdown = _delay_countdown;
	var sz: int = _index_counter.size();
	for i in range(0, sz):
		if _index_counter[i] == _index:
			_index_counter.remove_at(i);
			break;
	if _focuser.is_shrunked() && _choosen_index == _index:
		_do_countdown = false;
		_countdown_text.text = "";
		_focuser.grow_hole();
	if _index_counter.size() > 0 && !_focuser.is_shrunked():
		_do_countdown = true;
	else:
		_do_countdown = false;
		_countdown_text.text = "";

func on_dragged(args: MultiTouchOnDragged) -> void:
	_index = args.finger_index;
	_listed_fingers[_index][POSITION_KEY] = args.drag_pos;
	_listed_fingers[_index][MODEL_KEY].position = args.drag_pos;

func on_max_touch_changed(args: MultiTouchOnMaxChanged) -> void:
	for i in range(0, args.new_amount):
		if _listed_fingers.has(i): continue;
		_listed_fingers[i] = {};
		_listed_fingers[i][MODEL_KEY] = _display_pointer_pref.instantiate();
		_listed_fingers[i][MODEL_KEY].modulate = _colors[i % _colors.size()];
		_this_scene.add_child(_listed_fingers[i][MODEL_KEY]);
