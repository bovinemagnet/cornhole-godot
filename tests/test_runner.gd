extends SceneTree

# Each entry is a test-suite script. Each suite is a RefCounted subclass with
# methods named test_* that return "" on success or a failure message string.
# Run from the project root with:
#   godot --headless --script tests/test_runner.gd

const TEST_SCRIPTS: Array = [
	preload("res://tests/test_math_util.gd"),
	preload("res://tests/test_prop_grid.gd"),
	preload("res://tests/test_audio_util.gd"),
]


func _init() -> void:
	var pass_count := 0
	var fail_count := 0
	var failures: Array = []

	for script in TEST_SCRIPTS:
		var suite: Object = script.new()
		var suite_name: String = script.resource_path.get_file().get_basename()
		print("[%s]" % suite_name)
		for method_info in suite.get_method_list():
			var method_name: String = method_info.name
			if not method_name.begins_with("test_"):
				continue
			var error: String = String(suite.callv(method_name, []))
			if error.is_empty():
				pass_count += 1
				print("  PASS  %s" % method_name)
			else:
				fail_count += 1
				failures.append("%s.%s: %s" % [suite_name, method_name, error])
				print("  FAIL  %s -- %s" % [method_name, error])

	print("")
	print("RESULTS: %d passed, %d failed" % [pass_count, fail_count])
	if not failures.is_empty():
		print("")
		print("FAILURES:")
		for line in failures:
			print("  " + line)

	quit(0 if fail_count == 0 else 1)
