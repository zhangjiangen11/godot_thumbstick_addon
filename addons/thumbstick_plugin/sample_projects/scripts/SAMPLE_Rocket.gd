# MIT License - Copyright (c) 2025 | JoenTNT
# Permission is granted to use, copy, modify, and distribute this file
# for any purpose with or without fee, provided the above notice is included.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.

class_name SAMPLE_Rocket
extends RigidBody2D

signal on_player_destroyed();

# Properties.
@export var move_speed: float = 12.0;
@export var max_rotation_fx: float = 5.0;

# Runtime variable data.
@onready var _thruster_anim: AnimatedSprite2D = $"Thruster Animation";
var _move_dir: Vector2 = Vector2.ZERO;

func _ready() -> void:
	_thruster_anim.play();

func _physics_process(_delta: float) -> void:
	linear_velocity = move_speed * _move_dir;
	rotation_degrees = _move_dir.x * max_rotation_fx;

func _on_move_input_released(_args: JoystickOnReleased) -> void:
	_move_dir = Vector2.ZERO;

func _on_move_input_trigger(args: JoystickOnTriggered) -> void:
	_move_dir = args.input_v;

func _on_destroyed(destroyed_by: Node2D) -> void:
	print(destroyed_by);
	process_mode = PROCESS_MODE_DISABLED;
	hide();
	on_player_destroyed.emit();
