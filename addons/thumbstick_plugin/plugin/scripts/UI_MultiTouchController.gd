# MIT License - Copyright (c) 2025 | JoenTNT
# Permission is granted to use, copy, modify, and distribute this file
# for any purpose with or without fee, provided the above notice is included.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.

@tool
class_name UI_MultiTouchController
extends Control

# TODO: Finish the Prototype.
## Called when touch pressed on screen.
## It is recommended to cache touch owner index to track each touches.
signal on_touch_pressed(args: MultiTouchOnPressed);

## Called when touch is being dragged.
## It is recommended to use cached touch owner index to track each touches.
signal on_touch_dragged(args: MultiTouchOnDragged);

## Called when tap on the screen before cancelation threshold.
## This only works if [code]_tap_trigger_enabled[/code] enabled.
## It is recommended to use cached touch owner index to track each touches.
signal on_touch_tap(args: MultiTouchOnTap);

## Called when touch has been released.
## It is recommended to use cached touch owner index to track each touches.
signal on_touch_released(args: MultiTouchOnReleased);

## Called if maximum touch property value was changed.
## If the setting condition invalid, the event will not be called.
signal on_touch_max_amount_changed(args: MultiTouchOnMaxChanged);

# Constant aliases.
const ASSETS_PATH = "res://addons/thumbstick_plugin/plugin/assets/";
const MOUSE_FROM_TOUCH_SETTING = "input_devices/pointing/emulate_mouse_from_touch";
const TOUCH_FROM_MOUSE_SETTING = "input_devices/pointing/emulate_touch_from_mouse";
const DEFAULT_MAX_TOUCHES: int = 4;
const DEFAULT_CANCEL_TAP_THRESHOLD: float = 0.2;
const DEFAULT_START_TRIGGER_THRESHOLD: float = 16;
const DEFAULT_GIZMOS_INACTIVE_COLOR: Color = Color.RED;
const DEFAULT_GIZMOS_ACTIVE_COLOR: Color = Color.GREEN;
const DEFAULT_GIZMOS_PRETAP_COLOR: Color = Color.YELLOW;
const DEFAULT_GIZMOS_TEXT_COLOR: Color = Color.BLACK;
const DEFAULT_GIZMOS_TOUCH_HINT_RADIUS: float = 68.0;
const DEFAULT_GIZMOS_TEXT_HINT_OFFSET: Vector2 = Vector2(-64.0, 84.0);
const CACHE_KEY_IS_PRESSED: String = "is_pressed";
const CACHE_KEY_IS_TRIGGERED: String = "is_triggered";
const CACHE_KEY_START_DRAGGED_THRESHOLD: String = "start_dragged_threshold";
const CACHE_KEY_TOUCH_START_POSITION: String = "touch_start_position";
const CACHE_KEY_TOUCH_POSITION: String = "touch_position";
const CACHE_KEY_TOUCH_PREVIOUS_POSITION: String = "touch_prev_pos";
const CACHE_KEY_TOUCH_DRAGGED_DIRECTION: String = "touch_drag_dir";
const CACHE_KEY_TOUCH_DRAGGED_MAGNITUDE: String = "touch_drag_mag";
const CACHE_KEY_START_ELAPSED_TIME_AT: String = "start_elapsed_time_at";
const CACHE_KEY_RUNNING_ELAPSED_TIME: String = "running_elapsed_time";
const DEFAULT_TRIGGER_FUNCTIONS: Dictionary = {
	"on_dragged_method": "on_dragged",
	"on_pressed_method": "on_pressed",
	"on_released_method": "on_released",
	"on_tap_method": "on_tap",
	"on_max_touch_amount_method": "on_max_touch_changed",
};

# Properties.
## Maximum of touches iat the same timw is enabled.
## Set this equal to zero to disable the controller.
var _max_touch_amount: int = DEFAULT_MAX_TOUCHES:
	set(touch_amount):
		if _is_ready:
			if touch_amount < 0:
				print("Warning: Setting amount cannot be less than zero, abort the process.");
				return;
			elif touch_amount == _max_touch_amount:
				print("Warning: Setting the same touch amount, abort the process.");
				return;
		_on_max_touch_amount_changed(_max_touch_amount, touch_amount);
		_max_touch_amount = touch_amount;
## Move touch by distance in screen space to start trigger input.
var start_trigger_threshold: float = DEFAULT_START_TRIGGER_THRESHOLD:
	set(p_threshold):
		if p_threshold < 0.0: p_threshold = 0.0;
		start_trigger_threshold = p_threshold;
## Enable or disable tap trigger functionality.
var _tap_trigger_enabled: bool = false:
	set(p_enabled):
		_tap_trigger_enabled = p_enabled;
		notify_property_list_changed();
## The seconds allowed to cancel a tap input.
var _cancel_tap_threshold: float = DEFAULT_CANCEL_TAP_THRESHOLD;
## Disable controller state status.
var _is_disabled: bool = false;
## If this is [b]True[/b], when maximum touch amount changed,
## then it removes all the exceeding touch index immediately.
var _remove_exceeded_touch: bool = false;

# Controlling target.
## Once it is filled, all methods inside the node will be called.
var control_target_node: Node = null;
## Calling method on pressed ([color=FE861A][b]Control Target Node[/b][/color] must be filled)
var _on_touch_pressed_method_name: String = DEFAULT_TRIGGER_FUNCTIONS["on_pressed_method"];
## Calling method on dragged ([color=FE861A][b]Control Target Node[/b][/color] must be filled)
var _on_touch_dragged_method_name: String = DEFAULT_TRIGGER_FUNCTIONS["on_dragged_method"];
## Calling method on released ([color=FE861A][b]Control Target Node[/b][/color] must be filled)
var _on_touch_released_method_name: String = DEFAULT_TRIGGER_FUNCTIONS["on_released_method"];
## Calling method on tap ([color=FE861A][b]Control Target Node[/b][/color] must be filled)
var _on_touch_tap_method_name: String = DEFAULT_TRIGGER_FUNCTIONS["on_tap_method"];
## Calling method on max touch changed ([color=FE861A][b]Control Target Node[/b][/color] must be filled)
var _on_max_touch_amount_changed_method_name: String = DEFAULT_TRIGGER_FUNCTIONS["on_max_touch_amount_method"];

# Debugger.
## Open debug mode, only works in editor.
var _debug_mode: bool = false:
	set(p_debug):
		_debug_mode = p_debug;
		notify_property_list_changed();
## Visualization control hint in scene for development purpose.
var _visualize_gizmos: bool = true:
	set(p_vgiz):
		_visualize_gizmos = p_vgiz;
		notify_property_list_changed();
## Debug circle touch trigger color for gizmos when inactive.
var _gizmos_inactive_trigger_color: Color = DEFAULT_GIZMOS_INACTIVE_COLOR;
## Debug circle touch trigger color for gizmos when active.
var _gizmos_active_trigger_color: Color = DEFAULT_GIZMOS_ACTIVE_COLOR;
## Debug circle tap trigger color for gizmos while less than cancel threshold. 
var _gizmos_pretap_trigger_color: Color = DEFAULT_GIZMOS_PRETAP_COLOR;
## Debug touch point base circle drawn to validate status.
var _gizmos_touch_hint_radius: float = DEFAULT_GIZMOS_TOUCH_HINT_RADIUS;
## Debug text hint offset following touch domain.
var _gizmos_text_hint_offset: Vector2 = DEFAULT_GIZMOS_TEXT_HINT_OFFSET;
## Recolor text hint with color, useful to prevent camouflage against background.
var _gizmos_text_hint_color: Color = DEFAULT_GIZMOS_TEXT_COLOR;
## Notice developer for editor only warnings.
var _editor_warnings: bool = true;

# Runtime variable data.
@onready var _on_pressed_data: MultiTouchOnPressed = MultiTouchOnPressed.new();
@onready var _on_dragged_data: MultiTouchOnDragged = MultiTouchOnDragged.new();
@onready var _on_released_data: MultiTouchOnReleased = MultiTouchOnReleased.new();
@onready var _on_tapped_data: MultiTouchOnTap = MultiTouchOnTap.new();
@onready var _on_max_touch_changed_data: MultiTouchOnMaxChanged = MultiTouchOnMaxChanged.new();
var _current_touch_count: int = 0;
var _cached_touches: Dictionary = {};
var _temp_touch: Dictionary;
var _temp_draw_touch: Dictionary;
var _temp_start_point: Vector2;
var _temp_dragged_direction: Vector2;
var _temp_dragged_magnitude: float;
var _temp_unix_time_now: float = 0.0;
var _temp_time_elapsed: float = 0.0;
var _temp_touch_text_hint_pos: Vector2;
var _gui_position_offset: Vector2;
var _temp_touch_pos: Vector2;
var _temp_dragged_pos: Vector2;
var _gizmos_color: Color;
var _gizmos_color_when_trigger: Color;
var _running_in_editor: bool = false;
var _is_ready: bool = false;

#region Property Drawer
func _get_property_list() -> Array[Dictionary]:
	var r: Array[Dictionary] = [{
		"name": "Main Properties",
		"type": TYPE_STRING_NAME,
		"usage": PROPERTY_USAGE_GROUP,
	}, {
		"name": &"_max_touch_amount",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_DEFAULT,
	}, {
		"name": &"start_trigger_threshold",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT,
	}]
	r.append_array([{
		"name": "Controller Settings",
		"type": TYPE_STRING_NAME,
		"usage": PROPERTY_USAGE_SUBGROUP,
	}, {
		"name": &"_tap_trigger_enabled",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_DEFAULT,
	}, {
		"name": &"_remove_exceeded_touch",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_DEFAULT,
	}]);
	if _tap_trigger_enabled:
		r.append({
			"name": &"_cancel_tap_threshold",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
		});
	r.append_array([{
		"name": "Single Control Target",
		"type": TYPE_STRING_NAME,
		"usage": PROPERTY_USAGE_GROUP,
	}, {
		"name": &"control_target_node",
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_NODE_TYPE,
		"usage": PROPERTY_USAGE_DEFAULT,
	}, {
		"name": &"_on_touch_pressed_method_name",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
	}, {
		"name": &"_on_touch_dragged_method_name",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
	}, {
		"name": &"_on_touch_released_method_name",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
	}, {
		"name": &"_on_max_touch_amount_changed_method_name",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
	}]);
	if _tap_trigger_enabled:
		r.append({
			"name": &"_on_touch_tap_method_name",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT,
		});
	r.append_array([{
		"name": "Debugger",
		"type": TYPE_STRING_NAME,
		"usage": PROPERTY_USAGE_GROUP,
	}, {
		"name": &"_debug_mode",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT,
	}]);
	if _debug_mode:
		r.append_array([{
			"name": "Debug Mode Activators",
			"type": TYPE_STRING_NAME,
			"usage": PROPERTY_USAGE_SUBGROUP,
		}, {
			"name": &"_visualize_gizmos",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
		}]);
		if _visualize_gizmos:
			if _tap_trigger_enabled:
				r.append({
					"name": &"_gizmos_pretap_trigger_color",
					"type": TYPE_COLOR,
					"usage": PROPERTY_USAGE_DEFAULT,
				});
			r.append_array([{
				"name": &"_gizmos_inactive_trigger_color",
				"type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT,
			}, {
				"name": &"_gizmos_active_trigger_color",
				"type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT,
			}, {
				"name": &"_gizmos_touch_hint_radius",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
			}]);
		r.append_array([{
			"name": &"_gizmos_text_hint_color",
			"type": TYPE_COLOR,
			"usage": PROPERTY_USAGE_DEFAULT,
		}, {
			"name": &"_gizmos_text_hint_offset",
			"type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT,
		}, {
			"name": &"_editor_warnings",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
		}]);
	return r;

func _property_can_revert(property: StringName) -> bool:
	match (property):
		&"_max_touch_amount": return _max_touch_amount != DEFAULT_MAX_TOUCHES;
		&"_tap_trigger_enabled": return true;
		&"_remove_exceeded_touch": return true;
		&"_cancel_tap_threshold": return _cancel_tap_threshold != DEFAULT_CANCEL_TAP_THRESHOLD;
		&"start_trigger_threshold": return start_trigger_threshold != DEFAULT_START_TRIGGER_THRESHOLD;
		&"control_target_node": return control_target_node != null;
		&"_on_touch_pressed_method_name": return _on_touch_pressed_method_name != DEFAULT_TRIGGER_FUNCTIONS["on_pressed_method"];
		&"_on_touch_dragged_method_name": return _on_touch_dragged_method_name != DEFAULT_TRIGGER_FUNCTIONS["on_dragged_method"];
		&"_on_touch_released_method_name": return _on_touch_released_method_name != DEFAULT_TRIGGER_FUNCTIONS["on_released_method"];
		&"_on_touch_tap_method_name": return _on_touch_tap_method_name != DEFAULT_TRIGGER_FUNCTIONS["on_tap_method"];
		&"_on_max_touch_amount_changed_method_name": return _on_max_touch_amount_changed_method_name != DEFAULT_TRIGGER_FUNCTIONS["on_max_touch_amount_method"];
		&"_debug_mode": return true;
		&"_visualize_gizmos": return true;
		&"_gizmos_pretap_trigger_color": return _gizmos_pretap_trigger_color != DEFAULT_GIZMOS_PRETAP_COLOR;
		&"_gizmos_inactive_trigger_color": return _gizmos_inactive_trigger_color != DEFAULT_GIZMOS_INACTIVE_COLOR;
		&"_gizmos_active_trigger_color": return _gizmos_active_trigger_color != DEFAULT_GIZMOS_ACTIVE_COLOR;
		&"_gizmos_touch_hint_radius": return _gizmos_touch_hint_radius != DEFAULT_GIZMOS_TOUCH_HINT_RADIUS;
		&"_gizmos_text_hint_color": return _gizmos_text_hint_color != DEFAULT_GIZMOS_TEXT_COLOR;
		&"_gizmos_text_hint_offset": return _gizmos_text_hint_offset != DEFAULT_GIZMOS_TEXT_HINT_OFFSET;
		&"_editor_warnings": return true;
		_: return false;

func _property_get_revert(property: StringName) -> Variant:
	match (property):
		&"_max_touch_amount": return DEFAULT_MAX_TOUCHES;
		&"_tap_trigger_enabled": return false;
		&"_remove_exceeded_touch": return false;
		&"_cancel_tap_threshold": return DEFAULT_CANCEL_TAP_THRESHOLD;
		&"start_trigger_threshold": return DEFAULT_START_TRIGGER_THRESHOLD;
		&"control_target_node": return null;
		&"_on_touch_pressed_method_name": return DEFAULT_TRIGGER_FUNCTIONS["on_pressed_method"];
		&"_on_touch_dragged_method_name": return DEFAULT_TRIGGER_FUNCTIONS["on_dragged_method"];
		&"_on_touch_released_method_name": return DEFAULT_TRIGGER_FUNCTIONS["on_released_method"];
		&"_on_touch_tap_method_name": return DEFAULT_TRIGGER_FUNCTIONS["on_tap_method"];
		&"_on_max_touch_amount_changed_method_name": return DEFAULT_TRIGGER_FUNCTIONS["on_max_touch_amount_method"];
		&"_debug_mode": return false;
		&"_visualize_gizmos": return false;
		&"_gizmos_pretap_trigger_color": return DEFAULT_GIZMOS_PRETAP_COLOR;
		&"_gizmos_inactive_trigger_color": return DEFAULT_GIZMOS_INACTIVE_COLOR;
		&"_gizmos_active_trigger_color": return DEFAULT_GIZMOS_ACTIVE_COLOR;
		&"_gizmos_touch_hint_radius": return DEFAULT_GIZMOS_TOUCH_HINT_RADIUS;
		&"_gizmos_text_hint_color": return DEFAULT_GIZMOS_TEXT_COLOR;
		&"_gizmos_text_hint_offset": return DEFAULT_GIZMOS_TEXT_HINT_OFFSET;
		&"_editor_warnings": return false;
		_: return false;
#endregion

func _ready() -> void:
	_is_ready = true;
	_running_in_editor = Engine.is_editor_hint();
	if _running_in_editor: if !_editor_warnings: return;
	var mft: bool = ProjectSettings.get_setting(MOUSE_FROM_TOUCH_SETTING);
	var tfm: bool = ProjectSettings.get_setting(TOUCH_FROM_MOUSE_SETTING);
	if mft:
		print_rich("[color=FDD303]Warning: \"Project Settings -> Pointing" +
			"-> emulate_mouse_from_touch must\" be uncheck.");
	if not tfm:
		print_rich("[color=FDD303]Warning: \"Project Settings -> Pointing" +
			"-> emulate_touch_from_mouse\" must be checked.");
	if _running_in_editor: return;
	_clear_caches();

func _process(delta: float) -> void:
	_running_in_editor = Engine.is_editor_hint();
	if _running_in_editor: return;
	if _cached_touches.size() > 0:
		for k in _cached_touches.keys():
			_temp_touch = _cached_touches[k];
			if _temp_touch.has(CACHE_KEY_RUNNING_ELAPSED_TIME) && _temp_touch.has(CACHE_KEY_START_ELAPSED_TIME_AT):
				_temp_touch[CACHE_KEY_RUNNING_ELAPSED_TIME] = Time.get_unix_time_from_system() - _temp_touch[CACHE_KEY_START_ELAPSED_TIME_AT];
		queue_redraw();

func _draw() -> void:
	if !_debug_mode || !_visualize_gizmos: return;
	_gizmos_color = Color.AQUAMARINE;
	_gizmos_color.a = 0.15;
	draw_rect(Rect2(Vector2(0.0, 0.0), size), _gizmos_color);
	var touch_pos: Vector2;
	var start_pos: Vector2;
	for k in _cached_touches.keys():
		_temp_draw_touch = _cached_touches[k];
		if !_temp_draw_touch.get_or_add(CACHE_KEY_IS_PRESSED, false): continue;
		touch_pos = _temp_draw_touch[CACHE_KEY_TOUCH_POSITION] - global_position;
		if _temp_draw_touch[CACHE_KEY_IS_TRIGGERED]:
			_temp_touch_text_hint_pos = touch_pos;
			_gizmos_color_when_trigger = Color.CYAN;
			_gizmos_color_when_trigger.a = 0.25;
			_gizmos_color = _gizmos_active_trigger_color;
			_gizmos_color.a = 0.3;
			draw_circle(touch_pos, start_trigger_threshold, _gizmos_color);
		else:
			start_pos = _temp_draw_touch[CACHE_KEY_TOUCH_START_POSITION] - global_position;
			_temp_touch_text_hint_pos = start_pos;
			_gizmos_color_when_trigger = Color.BLUE;
			_gizmos_color_when_trigger.a = 0.25;
			if _tap_trigger_enabled && _temp_draw_touch[CACHE_KEY_RUNNING_ELAPSED_TIME] < _cancel_tap_threshold:
				_gizmos_color = _gizmos_pretap_trigger_color;
				_gizmos_color.a = 0.3;
				draw_circle(start_pos, start_trigger_threshold, _gizmos_color);
			else:
				_gizmos_color = _gizmos_inactive_trigger_color;
				_gizmos_color.a = 0.3;
				draw_circle(start_pos, start_trigger_threshold, _gizmos_color);
		draw_circle(touch_pos, _gizmos_touch_hint_radius, _gizmos_color_when_trigger);
		# Draw text information on screen.
		_temp_touch_text_hint_pos += _gizmos_text_hint_offset;
		draw_string(ThemeDB.fallback_font, _temp_touch_text_hint_pos,
			"Index: %d" % k,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, _gizmos_text_hint_color);
		_temp_touch_text_hint_pos += Vector2(0.0, 14.0);
		draw_string(ThemeDB.fallback_font, _temp_touch_text_hint_pos,
			"Is Triggered: %s" % ("True" if _temp_draw_touch[CACHE_KEY_IS_TRIGGERED] else "False"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, _gizmos_text_hint_color);
		_temp_touch_text_hint_pos += Vector2(0.0, 14.0);
		draw_string(ThemeDB.fallback_font, _temp_touch_text_hint_pos,
			"Position: {pos}".format({"pos": touch_pos}),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, _gizmos_text_hint_color);
		_temp_touch_text_hint_pos += Vector2(0.0, 14.0);
		draw_string(ThemeDB.fallback_font, _temp_touch_text_hint_pos,
			"Elapsed: %.3f" % _temp_draw_touch[CACHE_KEY_RUNNING_ELAPSED_TIME],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, _gizmos_text_hint_color);

func _gui_input(event: InputEvent) -> void:
	_running_in_editor = Engine.is_editor_hint();
	if _running_in_editor: return;
	_temp_unix_time_now = Time.get_unix_time_from_system();
	_gui_position_offset = global_position;
	if event is InputEventScreenTouch:
		_on_touch_input(event as InputEventScreenTouch);
	if event is InputEventScreenDrag:
		_on_touch_drag(event as InputEventScreenDrag);
	queue_redraw();

func _on_touch_input(e: InputEventScreenTouch) -> void:
	_temp_touch = _cached_touches.get_or_add(e.index, {});
	_temp_touch_pos = e.position + _gui_position_offset;
	_temp_touch[CACHE_KEY_TOUCH_POSITION] = _temp_touch_pos;
	if _current_touch_count < _max_touch_amount && e.pressed:
		_on_touch_pressed(e.index, _temp_touch_pos);
		_temp_touch[CACHE_KEY_TOUCH_PREVIOUS_POSITION] = _temp_touch_pos;
	elif _current_touch_count > 0 && !e.pressed:
		_on_touch_released(e.index, _temp_touch_pos);

func _on_touch_pressed(index: int, point: Vector2) -> void:
	_current_touch_count += 1;
	_temp_touch[CACHE_KEY_IS_PRESSED] = true;
	_temp_touch[CACHE_KEY_IS_TRIGGERED] = false;
	_temp_touch[CACHE_KEY_TOUCH_START_POSITION] = point;
	_temp_touch[CACHE_KEY_START_ELAPSED_TIME_AT] = _temp_unix_time_now;
	_temp_touch[CACHE_KEY_RUNNING_ELAPSED_TIME] = 0.0;
	# Cached data.
	_on_pressed_data.finger_index = index;
	_on_pressed_data.touch_amount = _current_touch_count;
	_on_pressed_data.pressed_position = _temp_touch[CACHE_KEY_TOUCH_START_POSITION];
	_on_pressed_data.local_pressed_position = _on_pressed_data.pressed_position - _gui_position_offset;
	# Call events.
	if control_target_node != null:
		if control_target_node.has_method(_on_touch_pressed_method_name):
			control_target_node.call(_on_touch_pressed_method_name, _on_pressed_data);
	on_touch_pressed.emit(_on_pressed_data);

func _on_touch_released(index: int, point: Vector2) -> void:
	if !_temp_touch.get_or_add(CACHE_KEY_IS_PRESSED, false): return;
	_current_touch_count -= 1;
	_temp_touch[CACHE_KEY_IS_PRESSED] = false;
	_temp_touch[CACHE_KEY_IS_TRIGGERED] = false;
	_temp_time_elapsed = Time.get_unix_time_from_system() - _temp_touch[CACHE_KEY_START_ELAPSED_TIME_AT];
	if _temp_time_elapsed < _cancel_tap_threshold:
		# Cached data.
		_on_tapped_data.finger_index = index;
		_on_tapped_data.touch_amount = _current_touch_count;
		_on_tapped_data.tap_position = _temp_touch[CACHE_KEY_TOUCH_START_POSITION];
		_on_tapped_data.local_tap_position = _on_tapped_data.tap_position - _gui_position_offset;
		# Call events.
		if control_target_node != null:
			if control_target_node.has_method(_on_touch_tap_method_name):
				control_target_node.call(_on_touch_tap_method_name, _on_tapped_data);
		on_touch_tap.emit(_on_tapped_data);
	# Cached data.
	_on_released_data.finger_index = index;
	_on_released_data.touch_amount = _current_touch_count;
	_on_released_data.latest_position = _temp_touch[CACHE_KEY_TOUCH_POSITION];
	_on_released_data.local_latest_position = _on_released_data.latest_position - _gui_position_offset;
	# Call events.
	if control_target_node != null:
		if control_target_node.has_method(_on_touch_released_method_name):
			control_target_node.call(_on_touch_released_method_name, _on_released_data);
	on_touch_released.emit(_on_released_data);

func _on_touch_drag(e: InputEventScreenDrag) -> void:
	_temp_touch = _cached_touches.get_or_add(e.index, {});
	if !_temp_touch.has(CACHE_KEY_IS_PRESSED): return;
	if !_temp_touch[CACHE_KEY_IS_PRESSED]: return;
	_temp_dragged_pos = e.position + _gui_position_offset;
	_temp_touch[CACHE_KEY_TOUCH_POSITION] = _temp_dragged_pos;
	_on_touch_triggered(e.index, _temp_dragged_pos);
	_temp_touch[CACHE_KEY_TOUCH_PREVIOUS_POSITION] = _temp_dragged_pos;

func _on_touch_triggered(index: int, point: Vector2) -> void:
	_temp_dragged_direction = _temp_touch.get_or_add(CACHE_KEY_TOUCH_DRAGGED_DIRECTION, Vector2.ZERO);
	_temp_dragged_magnitude = _temp_touch.get_or_add(CACHE_KEY_TOUCH_DRAGGED_MAGNITUDE, 0.0);
	if CACHE_KEY_IS_TRIGGERED not in _temp_touch:
		_temp_touch[CACHE_KEY_IS_TRIGGERED] = false;
	if not _temp_touch[CACHE_KEY_IS_TRIGGERED]:
		_temp_start_point = _temp_touch.get_or_add(CACHE_KEY_TOUCH_START_POSITION, point);
		if _temp_start_point.distance_to(point) < start_trigger_threshold: return;
		_temp_touch[CACHE_KEY_IS_TRIGGERED] = true;
	_temp_dragged_direction = _temp_touch[CACHE_KEY_TOUCH_POSITION] - _temp_touch[CACHE_KEY_TOUCH_PREVIOUS_POSITION];
	_temp_dragged_magnitude = _temp_dragged_direction.length();
	_temp_touch[CACHE_KEY_TOUCH_DRAGGED_DIRECTION] = _temp_dragged_direction.normalized();
	_temp_touch[CACHE_KEY_TOUCH_DRAGGED_MAGNITUDE] = _temp_dragged_magnitude;
	# Cached data.
	_on_dragged_data.finger_index = index;
	_on_dragged_data.touch_amount = _current_touch_count;
	_on_dragged_data.drag_pos = _temp_touch[CACHE_KEY_TOUCH_POSITION];
	_on_dragged_data.local_drag_pos = _on_dragged_data.drag_pos - _gui_position_offset;
	_on_dragged_data.normal_drag_dir = _temp_touch[CACHE_KEY_TOUCH_DRAGGED_DIRECTION];
	_on_dragged_data.drag_magnitude = _temp_touch[CACHE_KEY_TOUCH_DRAGGED_MAGNITUDE];
	# Call events.
	if control_target_node != null:
		if control_target_node.has_method(_on_touch_dragged_method_name):
			control_target_node.call(_on_touch_dragged_method_name, _on_dragged_data);
	on_touch_dragged.emit(_on_dragged_data);

## Clear all touch temporary data from caches.
func _clear_caches() -> void: _cached_touches.clear();

func _on_max_touch_amount_changed(old_amount: int, new_amount: int) -> void:
	if !_is_ready: return;
	_on_max_touch_changed_data.old_amount = old_amount;
	_on_max_touch_changed_data.new_amount = new_amount;
	_on_max_touch_changed_data.touch_triggered = _current_touch_count;
	if old_amount > new_amount: # Case if reducing touch amount.
		var sz: int = _cached_touches.size();
		if _remove_exceeded_touch && sz > new_amount:
			for i in range(new_amount - 1, sz):
				_temp_touch = _cached_touches[i];
				_on_touch_released(i, _temp_touch[CACHE_KEY_TOUCH_POSITION]);
	if control_target_node != null:
		if control_target_node.has_method(_on_max_touch_amount_changed_method_name):
			control_target_node.call(_on_max_touch_amount_changed_method_name, _on_max_touch_changed_data);
	on_touch_max_amount_changed.emit(_on_max_touch_changed_data);

func set_remove_exceeding_touches(should_remove: bool) -> void:
	_remove_exceeded_touch = should_remove;

func set_max_touch_amount(amount: int) -> void:
	_max_touch_amount = amount;

func get_max_touch_amount() -> int:
	return _max_touch_amount;

func get_current_touch_count() -> int:
	return _current_touch_count;

func get_touch_position(index: int) -> Vector2:
	if not _cached_touches.has(index):
		return Vector2.ZERO;
	if not _cached_touches[index].has(CACHE_KEY_TOUCH_POSITION):
		return Vector2.ZERO;
	return _cached_touches[index][CACHE_KEY_TOUCH_POSITION];
