# # D: The Reactive Library

Backbone = require "backbone-deep-model"
_ = require "underscore"

d = () -> d.run.apply d, arguments
module.exports = d

debug = () -> if d.debug then console.log.apply console, arguments

d.model = new Backbone.DeepModel
# d.debug = true

d.reactive = (fn, options = {}) ->
	self = this

	# rfn or rfn.run must be called first
	rfn = () -> rfn.run()

	rfn.path = options.path # base path
	_.extend rfn, Backbone.Events
	(reset = () ->
		_.extend rfn,
			parent: null
			firstRun: true
			running: false
			stopped: true
	)()

	rfn.run = () ->
		if @running then return
		@running = true
		@stopped = false

		old = self.current # cache the old context
		self.current = rfn # set the ctx

		if @firstRun
			@parent = old or null # cache parent on context creation
			if @parent then @parent.cleanup () => @stop()
			@trigger "start"
			@firstRun = false

		@trigger "run:before" # pre run

		fn.call rfn # run

		@trigger "run" # post run
		@trigger "run:after"

		self.current = old # reset the ctx
		@running = false

	rfn.invalidate = () ->
		if @invalid then return # no need to re-enqueue
		@invalid = true

		setTimeout () => # defer
			unless @stopped then @run() # run fn
			@trigger "invalid"
			@invalid = false
		, 0

	rfn.stop = () ->
		@stopped = true
		@invalidate() # mainly for the event
		@trigger "stop"
		reset()

	# same as @on("invalid") so maybe not necessary
	rfn.cleanup = (fn) ->
		onstop = () =>
			@off "stop", onstop
			@off "run:before", onstop
			fn()

		@on "stop", onstop
		@on "run:before", onstop

	rfn.subscribe = (path, options = {}) ->
		{path, parts} = d._pathOrPart path
		debug "subscribing >", path
		d.bind "change:#{path}", @invalidate, @

	rfn.unsubscribe = (path, options = {}) ->
		{path, parts} = d._pathOrPart path
		debug "unsubscribing >", path
		d.unbind "change:#{path}", @invalidate

	return rfn

d.get = (path, options = {}) ->
	parts = d._parts path
	{path, parts} = d._pathOrPart parts
	val = d.retrieve parts, options
	ctx = d.current

	if options.reactive isnt false and ctx
		ctx.subscribe path, options
		ctx.cleanup () -> ctx.unsubscribe path, options

	return val

d.retrieve = (parts, options = {}) ->
	{parts} = d._pathOrPart parts

	cur = d.model
	_parts = []
	path = []
	subpath = []

	push = (data) ->
		_parts.push
			path: path
			subpath: subpath
			fullpath: d.join path, subpath
			data: cur
		
		path = path.concat subpath
		subpath = []
		cur = data

	_.each parts, (part) ->
		subpath.push part
		val = cur.get d.join subpath
		if d._isBackboneData(val) then push val
	
	push() # last push

	return if options.complex is true then _parts
	else d._complexToValue _parts

d.set = (path, value, options = {}) ->
	{path, parts} = d._pathOrPart path
	_parts = d.retrieve parts, { complex: true }
	return unless mod = _.last _parts

	unless mod.subpath.length and _parts.length >= 2 then mod = _.first _.last _parts, 2
	return unless mod.subpath.length

	# add events to all incoming backbone data
	if d._isBackboneData(value) then value.on "all", d.event path

	# set value
	mod.data.set d.join(mod.subpath), value

d.event = (path) ->
	return (event, args...) ->
		{event, name, attr} = d._eventParse event
		return if attr.substr(-1) is "*" # ignore backbone deep dynamic paths
		isBase = _.isEmpty attr # base means event was emitted without attr
		fp = d.join path, attr
		debug "event >", "#{name}:#{fp}"
		d.trigger fp, name, isBase

		# other events trigger change on the tree (mimic both isBases)
		if name isnt "change"
			d.trigger fp, "change", true # always register change with parents
			return unless (model = args[0]) and (id = model.id)
			d.trigger d.join(fp, id), "change", false # only register lower events if we can

d.model.on "all", d.event ""
d._paths = {}

d.bind = (event, fn, context) ->
	return unless _.isString(event) and _.isFunction(fn)
	{event, name, attr} = d._eventParse event
	d._paths[attr] = {} unless _.has d._paths, attr
	evts = d._paths[attr]
	evts[name] = [] unless _.has evts, name
	evts[name].push { fn, context }

d.unbind = (event, fn) ->
	return unless _.isString(event)
	{event, name, attr} = d._eventParse event
	return unless _.isObject evts = d._paths[attr]
	unless _.isFunction(fn) then delete evts[name]
	else evts[name] = _.filter evts[name], (s) -> s.fn isnt fn

d.on = d.bind
d.off = d.unbind

d.trigger = (attr, name = "change", isBase) ->
	return if _.isEmpty parts = d.retrieve d.split(attr), complex: true
	{subpath, path} = _.last parts

	# isnt base, and empty subpath, get second to last
	if !isBase and _.isEmpty(subpath)
		return if parts.length < 2 # something is very wrong here
		{subpath, path} = _.first _.last parts, 2

	execFns = (subs, path) ->
		return unless _.isArray subs
		val = d.retrieve d.split path
		_.each subs, (s) ->
			ctx = s.context or null
			s.fn.call ctx, val, attr

	if name is "change" # change event cause updates on most of the tree
		if isBase # basic change event on an object (ie no subpath)
			# all parents including self
			_.each d._paths, (evts, p) ->
				execFns evts[name], p if p is attr.substr(0, p.length)
		else
			# all children, but not self
			_.each d._paths, (evts, p) ->
				execFns evts[name], p if attr isnt p and attr is p.substr(0, attr.length)

			# all variations of subpath including self
			base = d.join path
			_.each subpath, (p) ->
				base = d.join base, p
				return unless _.isObject evts = d._paths[base]
				execFns evts[name], base
					
	else # these events do not
		return unless _.isObject evts = d._paths[attr]
		execFns evts[name], attr

d.run = (path, fn, options) ->
	if _.isObject(fn) and !_.isFunction(fn) and !options then [options, fn] = [fn, null]
	if _.isFunction(path) and !fn then [fn, path] = [path, null]
	options ?= {}

	if _.isFunction(fn)
		if path then _.extend options, { path: path }
		(r = @reactive(fn, options))()
		return r
	else return @get path, options

# helpers

d.join = () ->
	_.chain(arguments)
		.toArray()
		.flatten()
		.compact()
		.filter((p) -> _.isString p)
		.map((p) -> d.trim p)
		.value()
		.join(".")

d.split = (path, base) ->
	path = d.trim path
	if path is "@" then path = base
	else if /^\$/.test(path) then path = path.replace /^\$\.?/, ""
	else if base then path = d.join base, path
	if /^\$/.test(path) then path = path.replace /^\$\.?/, "" # remove excess from base
	return _.compact @_keysplit path

d.trim = (str, sep = ".") ->
	len = sep.length
	ss = () -> String.prototype.substr.apply str, arguments
	while ss(0, len) is sep then str = ss len
	while ss(-1 * len) is sep then str = ss 0, str.length - len
	return str

d._parts = (path) ->
	ctx = @current
	base = @trim (if ctx then ctx.path) or ""
	return @split path, base

d._keysplit = (str, sep = ".", avoid = "\\") ->
	rawParts = str.split sep
	parts = []
	i = 0
	len = rawParts.length

	while i < len
		part = ""
		while rawParts[i].slice(-1) is avoid
			part += rawParts[i++].slice(0, -1) + sep  
		parts.push part + rawParts[i]
		i++
	
	return parts

d._isBackboneData = (obj) ->
	return _.isObject(obj) and (obj instanceof Backbone.Model or obj instanceof Backbone.Collection)

d._complexToValue = (obj) ->
	last = _.last(obj)
	return unless last.subpath.length then last.data
	else last.data.get d.join last.subpath

d._eventParse = (str) ->
	return unless m = /^([^:]+)(?:\:(.*))?$/.exec str
	[event, name, attr] = m
	attr ?= ""
	return {event, name, attr}

d._pathOrPart = (parts) ->
	if _.isString(parts) then parts = d.split parts
	return { path: d.join(parts), parts }