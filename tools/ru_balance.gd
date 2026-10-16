extends SceneTree
## godot --headless --path . --script res://tools/ru_balance.gd -- [--seeds N] [--bold]
## Plays N games with RuBot and prints the summary line used in docs/RU_BALANCE.md.


func _init() -> void:
	var seeds := 200
	var args := OS.get_cmdline_user_args()
	var i := args.find("--seeds")
	if i >= 0 and i + 1 < args.size():
		seeds = int(args[i + 1])
	print(RuBalance.report(RuBalance.run(seeds, 1000, args.has("--bold"))))
	quit()
