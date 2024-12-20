class_name Hitbox
extends Area2D

signal hit(Hurtbox)

func _init() -> void:
    area_entered.connect(_on_area_entered)

func _on_area_entered(hurtbox: Hurtbox) -> void:
    print("[Hit] %s => %s" % [self.owner.name, hurtbox.owner.name])
    self.hit.emit(hurtbox)
    hurtbox.hurt.emit(self)
