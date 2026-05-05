extends Node3D

# NexusCore.gd
# Generates the 3D Periodic Table in a spiral/nexus formation

@onready var elements_container = $ElementsContainer
var database = PeriodicDatabase.new()

var element_mesh = SphereMesh.new()
var elements_nodes = {}

func _init():
	element_mesh.radial_segments = 64
	element_mesh.rings = 32

enum FilterType { DEFAULT, RADIUS, ELECTRONEGATIVITY }
var current_filter = FilterType.DEFAULT

func _ready():
	generate_nexus()
	generate_constellations()
	
	# Connect UI buttons
	$UI/FilterButtons/DefaultBtn.pressed.connect(update_all_filters.bind(FilterType.DEFAULT))
	$UI/FilterButtons/RadiusBtn.pressed.connect(update_all_filters.bind(FilterType.RADIUS))
	$UI/FilterButtons/ENBtn.pressed.connect(update_all_filters.bind(FilterType.ELECTRONEGATIVITY))
	$UI/InfoPanel/CloseBtn.pressed.connect(func(): $UI/InfoPanel.visible = false)

func _on_element_input(_camera, event, _position, _normal, _shape_idx, atomic_number):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		show_element_info(atomic_number)

func show_element_info(atomic_number: int):
	var data = database.get_element(atomic_number)
	if data:
		$UI/InfoPanel/VBox/Symbol.text = data["symbol"]
		$UI/InfoPanel/VBox/Name.text = data["name"]
		$UI/InfoPanel/VBox/Details.text = "Massa: " + str(data["mass"]) + "\nEletroneg.: " + str(data["electronegativity"])
		$UI/InfoPanel.visible = true
		
		# Visual feedback on selected node
		for node in elements_nodes.values():
			node.get_surface_override_material(0).emission_energy_multiplier = 2.0
		elements_nodes[atomic_number].get_surface_override_material(0).emission_energy_multiplier = 10.0

func generate_nexus():
	var all_elements = database.get_all_elements()
	for atomic_number in all_elements:
		var data = all_elements[atomic_number]
		create_element_node(atomic_number, data)

func create_element_node(atomic_number: int, data: Dictionary):
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = element_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = data.get("color", Color.WHITE)
	material.emission_enabled = true
	material.emission = data.get("color", Color.WHITE)
	material.emission_energy_multiplier = 2.0
	mesh_instance.set_surface_override_material(0, material)
	
	# Add Collision for picking
	var area = Area3D.new()
	var collision = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.5
	collision.shape = sphere_shape
	area.add_child(collision)
	mesh_instance.add_child(area)
	area.input_event.connect(_on_element_input.bind(atomic_number))
	
	elements_container.add_child(mesh_instance)
	elements_nodes[atomic_number] = mesh_instance
	
	# Add label
	var label = Label3D.new()
	label.text = data["symbol"]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.outline_size = 12
	label.modulate = Color(1, 1, 1, 0.9)
	mesh_instance.add_child(label)
	
	apply_filter_to_node(atomic_number, data, mesh_instance)

func apply_filter_to_node(atomic_number: int, data: Dictionary, node: MeshInstance3D):
	var angle = (data["group"] / 18.0) * TAU
	var radius = 4.0 + (data["period"] * 0.5)
	var height = -data["period"] * 1.5
	
	var target_pos = Vector3(cos(angle) * radius, height, sin(angle) * radius)
	var target_scale = Vector3.ONE * 0.3
	var target_color = data.get("color", Color.WHITE)
	
	match current_filter:
		FilterType.RADIUS:
			var r_scale = data.get("radius", 100) / 100.0 * 0.3
			target_scale = Vector3(r_scale, r_scale, r_scale)
		FilterType.ELECTRONEGATIVITY:
			var en = data.get("electronegativity", 0)
			target_pos.y += en * 1.5
			target_color = Color(en/4.0, 0.2, 1.0 - en/4.0)

	# Smooth transition with Tween
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "position", target_pos, 0.8)
	tween.tween_property(node, "scale", target_scale, 0.8)
	
	var mat = node.get_surface_override_material(0)
	tween.tween_property(mat, "albedo_color", target_color, 0.8)
	tween.tween_property(mat, "emission", target_color, 0.8)
	
	# Adjust label position during tween
	tween.tween_property(node.get_child(1), "position:y", target_scale.y + 0.2, 0.8) # Child 1 is label, 0 is area

func update_all_filters(new_filter: FilterType):
	current_filter = new_filter
	var all_elements = database.get_all_elements()
	for atomic_number in all_elements:
		if elements_nodes.has(atomic_number):
			apply_filter_to_node(atomic_number, all_elements[atomic_number], elements_nodes[atomic_number])

func generate_constellations():
	var constellation_container = Node3D.new()
	add_child(constellation_container)
	
	# Create 12 clusters
	for c in range(12):
		var base_pos = Vector3(randf_range(-60, 60), randf_range(-30, 30), randf_range(-60, 60))
		# Avoid the center where the Nexus is
		if base_pos.length() < 20: base_pos *= 3.0
		
		var points = []
		for p in range(4):
			var offset = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
			var star_pos = base_pos + offset
			points.append(star_pos)
			
			# Spawn a brighter fixed star
			var star = MeshInstance3D.new()
			star.mesh = SphereMesh.new()
			star.mesh.radius = 0.05
			star.mesh.height = 0.1
			star.position = star_pos
			
			var mat = StandardMaterial3D.new()
			mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(1, 1, 1.5, 0.8)
			star.set_surface_override_material(0, mat)
			constellation_container.add_child(star)
			
		# Connect points with lines
		for i in range(points.size() - 1):
			create_line(constellation_container, points[i], points[i+1])

func create_line(container, start, end):
	var mesh_instance = MeshInstance3D.new()
	var immediate_mesh = ImmediateMesh.new()
	var material = StandardMaterial3D.new()
	
	mesh_instance.mesh = immediate_mesh
	material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 1, 1, 0.15)
	material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate_mesh.surface_add_vertex(start)
	immediate_mesh.surface_add_vertex(end)
	immediate_mesh.surface_end()
	
	container.add_child(mesh_instance)

func _process(delta):
	# Gentle rotation for the whole Nexus to show depth
	elements_container.rotate_y(delta * 0.1)
	
	# Auto-orbit camera
	var time = Time.get_ticks_msec() / 1000.0
	$Camera3D.position = Vector3(
		cos(time * 0.2) * 12,
		2 + sin(time * 0.1) * 2,
		sin(time * 0.2) * 12
	)
	$Camera3D.look_at(Vector3.ZERO)
