GODOT ?= godot

.PHONY: web serve-web
web:
	python3 tools/build_web.py --godot "$(GODOT)"

serve-web:
	python3 tools/serve_web.py --directory export/web
