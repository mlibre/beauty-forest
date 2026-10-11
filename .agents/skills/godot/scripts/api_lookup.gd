#!/usr/bin/env -S godot --headless --script
## Query the exact API exposed by the installed Godot editor.
## Run from the skill root with:
##   godot --headless --path scripts --script api_lookup.gd -- <mode> ...
extends SceneTree

const EXIT_USAGE := 64
const EXIT_NOT_FOUND := 65
const SEARCH_LIMIT := 500


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		_print_usage()
		quit(EXIT_USAGE)
		return
	if args[0] in ["-h", "--help", "help"]:
		_print_usage()
		quit(0)
		return

	match args[0]:
		"classes":
			_lookup_classes(args)
		"class":
			_lookup_class(args)
		"member":
			_lookup_member(args)
		"search":
			_search_api(args)
		_:
			push_error("Unknown mode: %s" % args[0])
			_print_usage()
			quit(EXIT_USAGE)


func _print_usage() -> void:
	var version := Engine.get_version_info()
	var version_text := str(version.get("string", "unknown"))
	var version_hash := str(version.get("hash", ""))
	if not version_hash.is_empty():
		version_text += " [hash %s]" % version_hash
	print("Godot API lookup (engine %s)" % version_text)
	print("Usage (from the skill root):")
	print("  godot --headless --path scripts --script api_lookup.gd -- classes [text]")
	print("  godot --headless --path scripts --script api_lookup.gd -- class <ClassName>")
	print("  godot --headless --path scripts --script api_lookup.gd -- member <ClassName> [member]")
	print("  godot --headless --path scripts --script api_lookup.gd -- search <text>")
	print()
	print("The class command prints inheritance and methods, properties/defaults, signals, enums, and constants.")


func _lookup_classes(args: PackedStringArray) -> void:
	var query := args[1].to_lower() if args.size() > 1 else ""
	var matches: Array[String] = []
	for class_id in _sorted_class_list():
		if query.is_empty() or class_id.to_lower().contains(query):
			matches.append(class_id)
	for class_id in matches:
		var parent := ClassDB.get_parent_class(class_id)
		var suffix := " (inherits %s)" % parent if not parent.is_empty() else ""
		print("%s%s" % [class_id, suffix])
	if matches.is_empty():
		_fail("No classes matched %s." % query)
		return
	quit(0)


func _lookup_class(args: PackedStringArray) -> void:
	if args.size() < 2:
		_fail("The class mode requires a class name.")
		return
	var class_id := StringName(args[1])
	if not ClassDB.class_exists(class_id):
		_fail("Class does not exist: %s" % class_id)
		return

	var parent := ClassDB.get_parent_class(class_id)
	var api_type := ClassDB.class_get_api_type(class_id)
	var inheriters := ClassDB.get_inheriters_from_class(class_id)
	inheriters.sort()
	print("CLASS %s" % class_id)
	print("  Inherits: %s" % (parent if not parent.is_empty() else "(none)"))
	print("  API type: %s" % _enum_name("ClassDB", "APIType", api_type))
	print("  Instantiable: %s" % ClassDB.can_instantiate(class_id))
	print("  Enabled: %s" % ClassDB.is_class_enabled(class_id))
	print("  Inheriters: %s" % (", ".join(inheriters) if not inheriters.is_empty() else "(none)"))

	_print_methods(class_id, false)
	_print_properties(class_id, false)
	_print_signals(class_id, false)
	_print_enums(class_id)
	_print_constants(class_id, false)
	quit(0)


func _lookup_member(args: PackedStringArray) -> void:
	if args.size() < 2:
		_fail("The member mode requires a class name.")
		return
	var class_id := StringName(args[1])
	if not ClassDB.class_exists(class_id):
		_fail("Class does not exist: %s" % class_id)
		return
	var query := args[2].to_lower() if args.size() > 2 else ""
	var found := false

	for method in ClassDB.class_get_method_list(class_id, false):
		if query.is_empty() or str(method.get("name", "")).to_lower().contains(query):
			found = true
			print("METHOD %s.%s%s" % [class_id, method.get("name", "?"), _method_signature(method)])
	for property in ClassDB.class_get_property_list(class_id, false):
		var property_name := str(property.get("name", "?"))
		if query.is_empty() or property_name.to_lower().contains(query):
			found = true
			print("PROPERTY %s.%s%s" % [class_id, property_name, _property_signature(class_id, property)])
	for signal_info in ClassDB.class_get_signal_list(class_id, false):
		if query.is_empty() or str(signal_info.get("name", "")).to_lower().contains(query):
			found = true
			print("SIGNAL %s.%s%s" % [class_id, signal_info.get("name", "?"), _callable_signature(signal_info.get("args", []))])
	for enum_name in ClassDB.class_get_enum_list(class_id, false):
		if query.is_empty() or enum_name.to_lower().contains(query):
			found = true
			print("ENUM %s.%s%s" % [class_id, enum_name, _enum_bitfield_suffix(class_id, enum_name)])
			for constant in ClassDB.class_get_enum_constants(class_id, enum_name, false):
				print("  %s.%s.%s = %d" % [class_id, enum_name, constant, ClassDB.class_get_integer_constant(class_id, constant)])
	for constant in ClassDB.class_get_integer_constant_list(class_id, false):
		if query.is_empty() or constant.to_lower().contains(query):
			found = true
			print("CONSTANT %s.%s = %d" % [class_id, constant, ClassDB.class_get_integer_constant(class_id, constant)])

	if not found:
		_fail("No member matched %s in %s." % [query, class_id])
		return
	quit(0)


func _search_api(args: PackedStringArray) -> void:
	if args.size() < 2:
		_fail("The search mode requires text to search for.")
		return
	var query := args[1].to_lower()
	var result_count := 0
	for class_id in _sorted_class_list():
		if class_id.to_lower().contains(query):
			print("CLASS %s" % class_id)
			result_count += 1
		if result_count >= SEARCH_LIMIT:
			break

		for method in ClassDB.class_get_method_list(class_id, true):
			if str(method.get("name", "")).to_lower().contains(query):
				print("METHOD %s.%s%s" % [class_id, method.get("name", "?"), _method_signature(method)])
				result_count += 1
			if result_count >= SEARCH_LIMIT:
				break
		if result_count >= SEARCH_LIMIT:
			break

		for property in ClassDB.class_get_property_list(class_id, true):
			if str(property.get("name", "")).to_lower().contains(query):
				print("PROPERTY %s.%s%s" % [class_id, property.get("name", "?"), _property_signature(class_id, property)])
				result_count += 1
			if result_count >= SEARCH_LIMIT:
				break
		if result_count >= SEARCH_LIMIT:
			break

		for signal_info in ClassDB.class_get_signal_list(class_id, true):
			if str(signal_info.get("name", "")).to_lower().contains(query):
				print("SIGNAL %s.%s%s" % [class_id, signal_info.get("name", "?"), _callable_signature(signal_info.get("args", []))])
				result_count += 1
			if result_count >= SEARCH_LIMIT:
				break
		if result_count >= SEARCH_LIMIT:
			break

		for enum_name in ClassDB.class_get_enum_list(class_id, true):
			var enum_matches := enum_name.to_lower().contains(query)
			if enum_matches:
				print("ENUM %s.%s%s" % [class_id, enum_name, _enum_bitfield_suffix(class_id, enum_name)])
				result_count += 1
			for constant in ClassDB.class_get_enum_constants(class_id, enum_name, true):
				if enum_matches or constant.to_lower().contains(query):
					print("  %s.%s.%s = %d" % [class_id, enum_name, constant, ClassDB.class_get_integer_constant(class_id, constant)])
					result_count += 1
				if result_count >= SEARCH_LIMIT:
					break
			if result_count >= SEARCH_LIMIT:
				break
		if result_count >= SEARCH_LIMIT:
			break

		for constant in ClassDB.class_get_integer_constant_list(class_id, true):
			if constant.to_lower().contains(query):
				print("CONSTANT %s.%s = %d" % [class_id, constant, ClassDB.class_get_integer_constant(class_id, constant)])
				result_count += 1
			if result_count >= SEARCH_LIMIT:
				break
		if result_count >= SEARCH_LIMIT:
			break

	if result_count == 0:
		_fail("No class or member matched %s." % query)
		return
	if result_count >= SEARCH_LIMIT:
		print("... result limit reached (%d); narrow the query or use member mode." % SEARCH_LIMIT)
	quit(0)


func _print_methods(class_id: StringName, no_inheritance: bool) -> void:
	print("\nMETHODS")
	var methods := ClassDB.class_get_method_list(class_id, no_inheritance)
	methods.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	for method in methods:
		print("  %s%s" % [method.get("name", "?"), _method_signature(method)])


func _print_properties(class_id: StringName, no_inheritance: bool) -> void:
	print("\nPROPERTIES")
	var properties := ClassDB.class_get_property_list(class_id, no_inheritance)
	properties.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	for property in properties:
		print("  %s%s" % [property.get("name", "?"), _property_signature(class_id, property)])


func _print_signals(class_id: StringName, no_inheritance: bool) -> void:
	print("\nSIGNALS")
	var signals := ClassDB.class_get_signal_list(class_id, no_inheritance)
	signals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	for signal_info in signals:
		print("  %s%s" % [signal_info.get("name", "?"), _callable_signature(signal_info.get("args", []))])


func _print_enums(class_id: StringName) -> void:
	print("\nENUMS")
	var enums := ClassDB.class_get_enum_list(class_id, false)
	enums.sort()
	for enum_name in enums:
		print("  %s%s" % [enum_name, _enum_bitfield_suffix(class_id, enum_name)])
		for constant in ClassDB.class_get_enum_constants(class_id, enum_name, false):
			print("    %s = %d" % [constant, ClassDB.class_get_integer_constant(class_id, constant)])


func _print_constants(class_id: StringName, no_inheritance: bool) -> void:
	print("\nCONSTANTS")
	var constants := ClassDB.class_get_integer_constant_list(class_id, no_inheritance)
	constants.sort()
	for constant in constants:
		print("  %s = %d" % [constant, ClassDB.class_get_integer_constant(class_id, constant)])


func _method_signature(method: Dictionary) -> String:
	var return_info: Dictionary = method.get("return", {})
	var return_type := _return_type_name(return_info)
	var args: Array = method.get("args", [])
	var default_args: Array = method.get("default_args", [])
	var first_default := args.size() - default_args.size()
	var rendered_args: Array[String] = []
	for index in args.size():
		var argument: Dictionary = args[index]
		var text := "%s: %s" % [argument.get("name", "arg%d" % index), _info_type_name(argument)]
		if index >= first_default:
			var default_index := index - first_default
			if default_index >= 0 and default_index < default_args.size():
				text += " = %s" % _value_text(default_args[default_index])
		rendered_args.append(text)

	var flags := int(method.get("flags", 0))
	var labels: Array[String] = []
	if flags & METHOD_FLAG_STATIC:
		labels.append("static")
	if flags & METHOD_FLAG_VIRTUAL:
		labels.append("virtual")
	if flags & METHOD_FLAG_CONST:
		labels.append("const")
	if flags & METHOD_FLAG_VARARG:
		labels.append("vararg")
	var suffix := " [%s]" % ", ".join(labels) if not labels.is_empty() else ""
	return " -> %s(%s)%s" % [return_type, ", ".join(rendered_args), suffix]


func _property_signature(class_id: StringName, property: Dictionary) -> String:
	var property_name := StringName(property.get("name", "?"))
	var type_name := _type_name(property)
	var getter := ClassDB.class_get_property_getter(class_id, property_name)
	var setter := ClassDB.class_get_property_setter(class_id, property_name)
	var default_value: Variant = ClassDB.class_get_property_default_value(class_id, property_name)
	var accessors: Array[String] = []
	if not getter.is_empty():
		accessors.append("get=%s" % getter)
	if not setter.is_empty():
		accessors.append("set=%s" % setter)
	var access_text := " [%s]" % ", ".join(accessors) if not accessors.is_empty() else ""
	return ": %s%s default=%s" % [type_name, access_text, _value_text(default_value)]


func _callable_signature(args: Array) -> String:
	var rendered_args: Array[String] = []
	for index in args.size():
		var argument: Dictionary = args[index]
		rendered_args.append("%s: %s" % [argument.get("name", "arg%d" % index), _info_type_name(argument)])
	return "(%s)" % ", ".join(rendered_args)


func _type_name(info: Dictionary) -> String:
	return _info_type_name(info)


func _info_type_name(info: Dictionary) -> String:
	if info.has("class_name") and not str(info.get("class_name", "")).is_empty():
		return str(info["class_name"])
	if info.has("enum") and not str(info.get("enum", "")).is_empty():
		return str(info["enum"])
	if info.has("type"):
		var type := int(info["type"])
		return "Variant" if type == TYPE_NIL else type_string(type)
	return "Variant"


func _return_type_name(return_info: Dictionary) -> String:
	# TYPE_NIL without PROPERTY_USAGE_NIL_IS_VARIANT is a genuine void.
	# TYPE_NIL with that usage bit is an untyped Variant (e.g.
	# Tween.interpolate_value and JSON.parse_string, which the official class
	# pages document as returning Variant).
	if return_info.is_empty():
		return "void"
	if int(return_info.get("type", TYPE_NIL)) != TYPE_NIL:
		return _info_type_name(return_info)
	if int(return_info.get("usage", 0)) & PROPERTY_USAGE_NIL_IS_VARIANT:
		return "Variant"
	return "void"


func _enum_bitfield_suffix(class_id: StringName, enum_name: StringName) -> String:
	return " (bitfield)" if ClassDB.is_class_enum_bitfield(class_id, enum_name, false) else ""


func _enum_name(class_id: StringName, enum_name: StringName, value: int) -> String:
	if not ClassDB.class_has_enum(class_id, enum_name, false):
		return str(value)
	for constant in ClassDB.class_get_enum_constants(class_id, enum_name, false):
		if ClassDB.class_get_integer_constant(class_id, constant) == value:
			return "%s.%s.%s" % [class_id, enum_name, constant]
	return str(value)


func _value_text(value: Variant) -> String:
	if value is String or value is StringName:
		return var_to_str(value)
	return str(value)


func _sorted_class_list() -> PackedStringArray:
	var classes := ClassDB.get_class_list()
	classes.sort()
	return classes


func _fail(message: String) -> void:
	push_error(message)
	quit(EXIT_NOT_FOUND)
