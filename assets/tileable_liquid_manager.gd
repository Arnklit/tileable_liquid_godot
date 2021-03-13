tool
extends Path

const SHADER_PATH = "res://assets/tileable_liquid.shader"

export var mesh : Mesh setget set_mesh
export(int, 1, 20) var mesh_repeat := 1 setget set_mesh_repeat
export(int, 16, 1024) var curve_samples := 50

# Private vars
var _mat : ShaderMaterial
var _mmi : MultiMeshInstance
var _curve_texture : ImageTexture
var _first_enter_tree := true


func _get_property_list() -> Array:
	var props = []
	
	props.append({
			name = "Shader Params",
			type = TYPE_NIL,
			hint_string = "param_",
			usage = PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	
	if _mat.shader != null:
		var shader_params := VisualServer.shader_get_param_list(_mat.shader.get_rid())
		for p in shader_params:
			if p.name.begins_with("i_"):
				continue
			var cp := {}
			for k in p:
				cp[k] = p[k]
			cp.name = str("param_", p.name)
			props.append(cp)
	return props


func _set(property: String, value) -> bool:
	if property.begins_with("param_"):
		var param_name = property.right(len("param_"))
		_mat.set_shader_param(param_name, value)
		return true
	return false


func _get(property : String):
	if property.begins_with("param_"):
		var param_name = property.right(len("param_"))
		return  _mat.get_shader_param(param_name)


func property_get_revert(property : String):
	if property.begins_with("param_"):
		var param_name = property.right(len("param_"))
		var revert_value = _mat.property_get_revert(str("shader_param/", param_name))
		return revert_value


func _init() -> void:
	print("init")
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH) as Shader


func _enter_tree() -> void:
	print("enter_tree")
	if Engine.editor_hint and _first_enter_tree:
		_first_enter_tree = false
	
	for child in get_child_count():
		remove_child(get_child(child))
	
	_mmi = MultiMeshInstance.new()
	_mmi.multimesh = MultiMesh.new()
	_mmi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_mmi.multimesh.color_format = MultiMesh.COLOR_FLOAT
	_mmi.multimesh.custom_data_format = MultiMesh.CUSTOM_DATA_NONE
	if mesh != null:
		_mmi.multimesh.mesh = mesh
		_mmi.multimesh.mesh.surface_set_material(0, _mat)
	add_child(_mmi)
	_mmi.set_owner(get_tree().get_edited_scene_root())
	_update_mmi()
	update_curve_texture()
	
	connect("curve_changed", self, "update_curve_texture")


func _exit_tree() -> void:
	disconnect("curve_changed", self, "update_curve_texture")


func _update_mmi() -> void:
	_mmi.multimesh.instance_count = mesh_repeat
	for i in mesh_repeat:
		var red = float(i) / float(mesh_repeat + 1)
		_mmi.multimesh.set_instance_color(i, Color(red, 0.0, 0.0, 1.0))


func update_curve_texture() -> void:
	var start_pos := curve.get_point_position(0)
	var end_pos := curve.get_point_position(curve.get_point_count() - 1)
	var aabb_start = Vector3(9999.0, 9999.0, 9999.0)
	var aabb_end = Vector3(-9999.0, -9999.0, -9999.0)
	for point in curve.get_point_count():
		var p_pos = curve.get_point_position(point)
		aabb_start = Vector3(min(aabb_start.x, p_pos.x), min(aabb_start.y, p_pos.y), min(aabb_start.z, p_pos.z))
		aabb_end = Vector3(max(aabb_end.x, p_pos.x), max(aabb_end.y, p_pos.y), max(aabb_end.z, p_pos.z))
	
	var image := Image.new()
	image.create(curve_samples, 15, false, Image.FORMAT_RGB8)
	
	image.lock()
	var cl = curve.get_baked_length()
	for x in curve_samples:
		var pos_curve = curve.interpolate_baked(float(x) / curve_samples * cl)
		var dir_curve = curve.interpolate_baked( (float(x) / curve_samples * cl) - 0.1) - curve.interpolate_baked( (float(x) / curve_samples * cl) + 0.1)
		var up_vec = curve.interpolate_baked_up_vector(float(x) / curve_samples * cl)
		dir_curve = dir_curve.normalized() * 0.5 + Vector3(0.5, 0.5, 0.5)
		up_vec = up_vec.normalized() * 0.5 + Vector3(0.5, 0.5, 0.5)
		pos_curve -= aabb_start
		pos_curve = pos_curve / (aabb_end - aabb_start)
		
		var position_color = Color(pos_curve.x, pos_curve.y, pos_curve.z)
		var normal_color = Color(dir_curve.x, dir_curve.y, dir_curve.z)
		var up_vec_color = Color(up_vec.x, up_vec.y, up_vec.z)
		
		for y in 5:	
			image.set_pixel(x, y, position_color)
			image.set_pixel(x, y + 5, normal_color)
			image.set_pixel(x, y + 10, up_vec_color)
		
	image.unlock()
	
	_curve_texture = ImageTexture.new()
	_curve_texture.create_from_image(image, 4)
	
	_mat.set_shader_param("i_bb_start", aabb_start)
	_mat.set_shader_param("i_bb_size", aabb_end - aabb_start)
	_mat.set_shader_param("i_curve_texture", _curve_texture)


func set_mesh(new_mesh : Mesh) -> void:
	mesh = new_mesh
	if _first_enter_tree:
		return
	_mmi.multimesh.mesh = mesh
	if mesh != null:
		_mmi.multimesh.mesh.surface_set_material(0, _mat)


func set_mesh_repeat(value : int) -> void:
	mesh_repeat = value
	_mat.set_shader_param("i_mesh_repeat", mesh_repeat)
	if _first_enter_tree:
		return
	_update_mmi()
