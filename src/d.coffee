# # D: The Reactive Library
#
# ---
# 
# This library has three hard dependencies: [Backbone](http://backbonejs.org/), [Underscore](http://documentcloud.github.io/underscore) and [node-uuid](https://github.com/broofa/node-uuid). While made for the Node.js environment, this library is compatible with the client using browserify.
Backbone = require "backbone"
_ = require "underscore"
uuid = require "uuid"

# The Major Variable
# ------------------
#
# The variable `d` is global variable to access this library. `d` itself is actually a function that wraps `d.run()` for quick context set up and data retrieval. See `d.run()` for more info.
d = () -> d.run.apply d, arguments
module.exports = d # public api

# Global Model
# ------------
#
# D setups a new Backbone model to house all of the application data. Data might include standard JavaScript variable types or Backbone models and collections. This allows for data to be accessible globally without affecting what it can do. You shouldn't access this model directly; instead use `d.get()` and `d.set()`.
d.model = new Backbone.Model()

# Subscriptions
# -------------
#
# Subscriptions are a connection between a path and multiple contexts. A subscription is created the first time it is requested and is then subscribed to each context that needs it.
d.subs =
	subscriptions: []
	queue: [] # to automate get subscription setup

# `d.subs.create()` creates a new subscription at `path` with `data`. If the subscription already exists, any new data replaces the existing. The created subscription will be attached to a queue that can be accessed later. This method *does not* subscribe data to any context, but sets up the methods to do so.
	create: (path, data, ext = {}) ->
		sub = @find path

		unless sub
			sub =
				id: uuid.v4()
				path: path
				data: data
				contexts: []
			
			_.extend sub, Backbone.Events # eventful
			_.extend sub, ext
			
			sub.add = (ctx, options) ->
				@contexts.push ctx
				if ext.temporary then ctx.cleanup () => d.subs.remove @id

			sub.remove = (ctx, options) ->
				@contexts = _.without @contexts, ctx

			@subscriptions.push sub

		else unless _.isEqual data, sub.data
			ctxs = sub.contexts

			_.each ctxs, (ctx) -> ctx.unsubscribe sub # unsubscribe from current data
			sub.contexts = []
			sub.data = data # Set current data
			_.each ctxs, (ctx) -> ctx.subscribe sub # resubscribe to new data
		
		@queue.push sub
		return sub

# `d.subs.find()` turns a `path` or subscription `id` into a subscription. This is useful for subscription maintenance, including subscribing and unsubscribing from contexts.
	find: (path) ->
		return _.find @subscriptions, (sub) ->
			return sub.path is path or sub.id is path

# `d.subs.remove()` completely removes a subscription from existence. All subscribed contexts are unsubscribed. 
	remove: (id) ->
		return unless sub = @find id
		_.each sub.contexts, (ctx) -> ctx.unsubscribe sub
		index = _.indexOf @subscriptions, sub
		@subscriptions.splice index, 1
	
	clear: () -> @queue = []

# Using Data
# ----------
#
# `d.get()` is a simple function that does many things. The first task of `d.get()` is to retrieve data at `path`. A `path` is a string of parts separated by a `.`. Each part refers a level of the data within `d.model`. For example, a path like `_session.foo.bar` would be resolved as `d.model.get("_session")["foo"]["bar"]`.
#
# `d.get()` sets up a special starting path part `$`. This path will *always* refer to the global model even when the context is scoped.
#
# The second thing `d.get()` does is set up the specified data as a subscription and subscribes it to the current context. Whenever a "change" to data is detected, the context will be rerun.
d.get = (path, options = {}) ->
	ctx = @current
	base = @_trim (if ctx then ctx.path) or ""
	parts = @_parts path, base
	val = @retrieve parts, options

	if options.reactive isnt false and ctx # subscribe path to ctx
		d.subs.clear() # we need a clean space
		@process val, parts, options # process path into subscription
		_.each d.subs.queue, (sub) -> ctx.subscribe sub, options # start subscription
		d.subs.clear() # clean again

	return if val? then val else options.default

# `d.set()`, on the other hand, sets data at `path`. `d.set()` is dynamic enough to translate a string path into a series of models and collections so the right value is always set. This will also automatically resubscribe to any data if the subscription was changed.
d.set = (path, value, options = {}) ->
	parts = @_parts path
	@update parts, value, options

# Reactive Contexts
# -----------------
#
# `d.reactive()` takes a function `fn` to be rerun any time a dependency changes. A dependency is simply any data returned from `d.get()`. `fn` will have `this` pointing to the reactive context. It is given no arguments and expects no return value. `d.reactive()` returns a "reactive context" which is simply a wrapper function for `fn`. A reactive context must be called at least once to initiate its subscriptions.
#
# A neat feature of contexts is their ability to be nested within each other. Any time a parent context is run, all children contexts are stopped and restarted. Reactive contexts can only be placed within a single parent context. If a context is run within a context that isn't it's parent, closing events will not be received and memory will leak.
d.reactive = (fn, options = {}) ->
	self = this

	rfn = () ->
		if rfn.running then return
		rfn.running = true

		old = self.current # cache the old context
		self.current = rfn # set the ctx

		if rfn.first_run
			rfn.parent = old # cache parent on context creation
			
			# clean up when parent does
			if rfn.parent then rfn.parent.cleanup rfn.stop.bind(rfn)

			rfn.trigger "start"
			rfn.first_run = false

		rfn.trigger "run:before" # pre run

		fn.call rfn # run

		rfn.trigger "run" # post run
		rfn.trigger "run:after"

		self.current = old # reset the ctx
		rfn.running = false

# The context also triggers events using Backbone's event API. These events include `start`, `run:before`, `run`, `run:after`, and `stop`.
	_.extend rfn, Backbone.Events # eventful

# Some notable properties of a reactive context include a globally unique id and a base path for scoping. A scoped context requires shorter paths to access the same data. For example, if there is a model at the path `Projects.1` and the context is scoped to it, any further paths will access the model directly. So `Project.1.title` becomes just `title`. Remember the global model can always be accessed with the path `$`.
	rfn.id = uuid.v4() # unique ctx id
	rfn.path = options.path # base path

# Each context defines a `subscribe()` and `unsubscribe()` method. These methods take a subscription and watch (or unwatch) for changes to data. Given the same arguments, `unsubscribe()` should "undo" anything done by `subscribe()`. Each subscription will only be subscribed to once.
	rfn.subscribe = (sub, o = {}) ->
		return if _.contains @subscriptions, sub.id
		subscribe = options.subscribe or d.subscribe
		
		sub.add @, o # tell the subscription about us
		subscribe.call sub, @, o # enable the subscription
		@subscriptions.push sub.id

	rfn.unsubscribe = (sub, o = {}) ->
		if _.isString(sub) then sub = self.subs.find sub
		return unless _.contains @subscriptions, sub.id
		unsubscribe = options.unsubscribe or d.unsubscribe
		
		sub.remove @, o
		unsubscribe.call sub, @, o # disable subscription
		@subscriptions = _.without @subscriptions, sub.id

# Contexts also have a stop method that halts the context completely. All subscriptions are unsubscribed and the context is brought to a normalized state. A context can be restarted by calling it again.
	rfn.stop = (o = {}) ->
		_.each @subscriptions, (id) => @unsubscribe id
		reset()
		@trigger "stop"

# Reactive contexts come with an easy clean up utility that helps to run some function whenever the context is stopped or re-run. This is useful for deep contexts that need to be destroyed regularly.
	rfn.cleanup = (fn) ->
		onstop = () =>
			@off "stop", onstop
			@off "run:before", onstop
			fn()

		@on "stop", onstop
		@on "run:before", onstop

	reset = () ->
		rfn.subscriptions = []
		rfn.parent = null
		rfn.first_run = true

	reset()
	return rfn

# Useful Utilities
# ----------------
#
# `d.run()` is the marriage of `d.get()` and `d.reactive()` in a simple package. If just a `path` is given, `d.get()` is used to retrieve the data and set up subscriptions. If `fn` is given, a reactive context is created. If `fn` is used with `path`, the context is scoped to `path`.
d.run = (path, fn, options) ->
	if _.isObject(fn) and !_.isFunction(fn) and !options then [options, fn] = [fn, null]
	if _.isFunction(path) and !fn then [fn, path] = [path, null]
	options ?= {}

	if _.isFunction(fn)
		if path then _.extend options, { path: path }
		(r = @reactive(fn, options))()
		return r
	else return @get path, options

# `d.depend()` forces the current context to subscribe to `data`. This allows contexts to subscribe to `data` even if `data` doesn't exist in `d.model`. It creates a temporary subscription that is destroyed on context close. This method is hackable.
d.depend = (data, options = {}) ->
	if ctx = @current
		sub = @subs.create uuid.v4(), data, { temporary: true }
		ctx.subscribe sub, options
		d.subs.clear() # clean up
		return

# Hackable Methods
# ----------------
#
# Several methods within this library are "hackable" and can be modified. This is useful for when core data needs to be controlled by something other than Backbone or context specific functionality is desired.
#
# ---
#
# `d.retrieve()` is responsible for getting the value at path. `parts` is an array of path partitions, always relative to `d.model`.
d.retrieve = (parts, options = {}) ->
	cur = @model

	if _.some(parts, (p) =>
		unless _.isObject(cur) then return true
		else if @_isBackboneData(cur) then cur = cur.get(p)
		else cur = cur[p]
		return false
	) then return undefined

	return cur

# `d.update()` sets a `value` at path. It also handles the firing of update events so reactive contexts can be rerun.
d.update = (parts, value, options = {}) ->
	lo = @model
	cur = @model
	path = []

	_.each parts, (p) =>
		if @_isBackboneData(cur)
			lo = cur
			cur = cur.get(p)
			path = []
		else if _.isObject(cur)
			cur = cur[p]
		
		path.push p

	rp = _.rest path
	child = lo.get path[0]

	if rp.length
		unless _.isObject(child) then child = {}
		else child = _.clone child
		@_deep child, rp.join("."), value
	else child = value

	lo.set path[0], child

# `d.process()` sets up subscriptions given a `value` and path `parts`. This should **only** create subscriptions, not subscribe them to any contexts. Even though this function will be rerun multiple times for the same subscriptions, the API will not duplicate subscriptions.
d.process = (value, parts, options = {}) ->
	obj = @model
	base = ""
	paths = []
	subpath = []

	add = (part) ->
		if _.isEmpty(base) then base = part
		else base += "." + part

	flush = () =>
		@subs.create base, obj
		_.each subpath, add
		subpath = []

	_.each parts, (p) =>
		paths.push p
		val = @retrieve paths
		subpath.push p

		if @_isBackboneData val
			flush() # flush the cache
			obj = val # set the major object

	flush() # flush one last time

# `d.subscribe()` is the default subscribe method used by subscriptions. `this` within the method will refer to the subscription using it. By passing `fn`, this method should set the proper events to call the context any time it needs to update.
d.subscribe = (fn, options = {}) ->
	data = @data
	
	if data instanceof Backbone.Model
		fn.listenTo data, "change", fn
	else if data instanceof Backbone.Collection
		fn.listenTo data, "add", fn
		fn.listenTo data, "remove", fn
		fn.listenTo data, "sort", fn

# `d.unsubscribe()` is the default unsubscribe method used by subscriptions. It is called in the same fashion as `d.subscribe()`. Given the same arguments, it should completely reverse anything done by the subscribe method.
d.unsubscribe = (fn, options = {}) ->
	if d._isBackboneData(@data) then fn.stopListening @data

# Helpers
# ----------------
#

# `d.join()` takes any number of string arguments and concats them together to form a path.
d.join = () -> _.chain(arguments).toArray().flatten().compact().map((p) -> d._trim(p)).value().join(".")

# `d._parts()` takes a string `path` and divides it into an array of path parts. Optionally pass `base` to prefix it to path in the event `$` is not use.
d._parts = (path, base) ->
	path = d._trim path
	if /^\$/.test(path) then path = path.replace /^\$\.?/, ""
	else if base then path = base + "." + path
	return _.compact @_keysplit path

# `d._keysplit()` takes a string and separates it by `sep`. You can use `sep` in the path by prefixing it with `avoid`.
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

# `d._deep()` gets or sets a `value` at `key` deeply within an object. When setting a `value` and `key` doesn't exist, objects are created to make it fit.
d._deep = (obj, key, value) ->
	keys = _.compact @_keysplit key
	i = 0
	n = keys.length

	if arguments.length > 2 # set value
		root = obj
		n--
		while i < n
			key = keys[i++]
			obj = obj[key] = (if _.isObject(obj[key]) then obj[key] else {})
		obj[keys[i]] = value
		value = root

	else # get value
		continue while (obj = obj[keys[i++]])? and i < n
		value = (if i < n then undefined else obj)
	
	return value

# `d._trim()` normalizes a path by removing any leading or trailing separators.
d._trim = (str, sep = ".") ->
	len = sep.length
	ss = () -> String.prototype.substr.apply str, arguments
	while ss(0, len) is sep then str = ss len
	while ss(-1 * len) is sep then str = ss 0, str.length - len
	return str

# `d._isBackboneData()` tests `obj` as a Backbone model or collection. Useful in determining if data can take events or needs to be accessed in a different way.
d._isBackboneData = (obj) ->
	return _.isObject(obj) and (obj instanceof Backbone.Model or obj instanceof Backbone.Collection)