class_name NavigationBaker
extends RefCounted
## Запекание сетки навигации врагов по мешам комнат (№80, №81). Отдельный класс без зависимостей от автозагрузок: им
## пользуются сборщик зоны и проверка одной комнаты.


## Запекает сетку по мешам под узлом source_root. Параметры берутся из ZoneSettings.
static func bake(source_root: Node, settings: ZoneSettings) -> NavigationMesh:
	return bake_roots([source_root], settings)


## То же по нескольким корням сразу (хаб №89: зал, прилавки, касса, станции; игрока с его мешами в сетку класть нельзя) и с выбором,
## что читать: меши (зоны) или коллизии статических тел (хаб: не читает геометрию с видеокарты и работает без окна).
static func bake_roots(source_roots: Array[Node], settings: ZoneSettings, geometry_type: NavigationMesh.ParsedGeometryType = NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES) -> NavigationMesh:
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.cell_size = settings.nav_cell_size
	mesh.cell_height = settings.nav_cell_height
	mesh.agent_height = settings.nav_agent_height
	mesh.agent_radius = settings.nav_agent_radius
	mesh.agent_max_climb = settings.nav_agent_max_climb
	mesh.agent_max_slope = settings.nav_agent_max_slope
	mesh.geometry_parsed_geometry_type = geometry_type
	var source: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	# Каждый разбор очищает данные, поэтому корни разбираются по отдельности и склеиваются.
	for source_root: Node in source_roots:
		var part: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(mesh, part, source_root)
		source.merge(part)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	return mesh
