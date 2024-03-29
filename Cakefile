exec = require("child_process").exec
path = require "path"
fs = require "fs"

lib = "./lib/d.js"
src = "./src/d.coffee"

run = (cmd, cb) ->
	e = exec cmd
	e.on 'close', () -> cb() if typeof cb is "function"
	e.stdout.pipe(process.stdout)
	e.stderr.pipe(process.stderr)

option '-w', '--watch', 'Watch for changes.'
option '-o', '--output', 'Where to output stuff.'
option '-m', '--minify', 'Compress the bundle using Uglify.'
option '-l', '--layout', 'The layout to use with Docco.'

task 'build', 'Build coffeescript source to javascript.', (options) ->
	w = if options.watch then "w" else ""
	o = options.output or "lib/"
	run "coffee -o #{o} -c#{w} src/"

task 'bundle', "Bundle it with browserify.", (options) ->
	o = options.output or process.cwd() + "/dist/"
	run "cake build", () ->
		run "browserify #{lib} -s dee -o #{o}dee.js"
		run "browserify #{lib} -s dee | uglifyjs - -o #{o}dee.min.js"

task 'docs', "Create documentation from source code.", (options) ->
	o = options.output or process.cwd() + "/docs"
	l = options.layout or "parallel"
	run "docco -o #{o} -l #{l} #{src}"

task 'lines', 'Count the lines of code in D.', ->
	code = fs.readFileSync src, "utf-8"
	lines = code.split('\n').filter (line) -> /^[^#]/.test(line) and line.trim()
	console.log "There are #{lines.length} lines of code in D."

task 'readme', 'Generate a readme file based on code.', (options) ->
	o = options.output or "./README.md"
	code = fs.readFileSync src, "utf-8"
	lines = code.split('\n').filter (line) -> /^#/.test(line) or !line.trim()
	prev = null
	md_lines = lines.map (line) -> 
		nl = line.replace(/^#/g, "").trim()
		if /^-{3}$/.test(nl) then nl = ""
		return nl
	md = md_lines.join("\n").replace(/\t/g, "").replace(/[\r\n]{2,}/g, "\n\n")
	fs.writeFileSync o, md