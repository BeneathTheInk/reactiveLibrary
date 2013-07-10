# D: The Reactive Library

This library has three hard dependencies: [Backbone](http://backbonejs.org/), [Underscore](http://documentcloud.github.io/underscore) and [node-uuid](https://github.com/broofa/node-uuid). While made for the Node.js environment, this library is compatible with the client using browserify.

The Major Variable
------------------

The variable `d` is global variable to access this library. `d` itself is actually a function that wraps `d.run()` for quick context set up and data retrieval. See `d.run()` for more info.

Global Model
------------

D setups a new Backbone model to house all of the application data. Data might include standard JavaScript variable types or Backbone models and collections. This allows for data to be accessible globally without affecting what it can do. You shouldn't access this model directly; instead use `d.get()` and `d.set()`.

Subscriptions
-------------

Subscriptions are a connection between a path and multiple contexts. A subscription is created the first time it is requested and is then subscribed to each context that needs it.

`d.subs.create()` creates a new subscription at `path` with `data`. If the subscription already exists, any new data replaces the existing. The created subscription will be attached to a queue that can be accessed later. This method *does not* subscribe data to any context, but sets up the methods to do so.

`d.subs.find()` turns a `path` or subscription `id` into a subscription. This is useful for subscription maintenance, including subscribing and unsubscribing from contexts.

`d.subs.remove()` completely removes a subscription from existence. All subscribed contexts are unsubscribed.

Using Data
----------

`d.get()` is a simple function that does many things. The first task of `d.get()` is to retrieve data at `path`. A `path` is a string of parts separated by a `.`. Each part refers a level of the data within `d.model`. For example, a path like `_session.foo.bar` would be resolved as `d.model.get("_session")["foo"]["bar"]`.

`d.get()` sets up a special starting path part `$`. This path will *always* refer to the global model even when the context is scoped.

The second thing `d.get()` does is set up the specified data as a subscription and subscribes it to the current context. Whenever a "change" to data is detected, the context will be rerun.

`d.set()`, on the other hand, sets data at `path`. `d.set()` is dynamic enough to translate a string path into a series of models and collections so the right value is always set. This will also automatically resubscribe to any data if the subscription was changed.

Reactive Contexts
-----------------

`d.reactive()` takes a function `fn` to be rerun any time a dependency changes. A dependency is simply any data returned from `d.get()`. `fn` will have `this` pointing to the reactive context. It is given no arguments and expects no return value. `d.reactive()` returns a "reactive context" which is simply a wrapper function for `fn`.

A neat feature of contexts is their ability to be nested within each other. Any time a parent context is run, all children contexts are stopped and restarted.

A reactive context must be called at least once to initiate its subscriptions. In this way, contexts are highly transportable and can be placed in more than one location, including multiple parent contexts. The context will automatically clean up after itself, only completely stopping when *all* parent contexts have also been stopped.

The context also triggers events using Backbone's event API. These events include `start`, `run:before`, `run`, `run:after`, and `stop`.

Some notable properties of a reactive context include a globally unique id and a base path for scoping. A scoped context requires shorter paths to access the same data. For example, if there is a model at the path `Projects.1` and the context is scoped to it, any further paths will access the model directly. So `Project.1.title` becomes just `title`. Remember the global model can always be accessed with the path `$`.

Each context defines a `subscribe()` and `unsubscribe()` method. These methods take a subscription and watch (or unwatch) for changes to data. Given the same arguments, `unsubscribe()` should "undo" anything done by `subscribe()`. Each subscription will only be subscribed to once.

Contexts also have a stop method that halts the context completely. All subscriptions are unsubscribed and the context is brought to a normalized state. A context can be restarted by calling it again.

Useful Utilities
----------------

`d.run()` is the marriage of `d.get()` and `d.reactive()` in a simple package. If just a `path` is given, `d.get()` is used to retrieve the data and set up subscriptions. If `fn` is given, a reactive context is created. If `fn` is used with `path`, the context is scoped to `path`.

`d.depend()` forces the current context to subscribe to `data`. This allows contexts to subscribe to `data` even if `data` doesn't exist in `d.model`. It creates a temporary subscription that is destroyed on context close. This method is hackable.

Hackable Methods
----------------

Several methods within this library are "hackable" and can be modified. This is useful for when core data needs to be controlled by something other than Backbone or context specific functionality is desired.

`d.retrieve()` is responsible for getting the value at path. `parts` is an array of path partitions, always relative to `d.model`.

`d.update()` sets a `value` at path. It also handles the firing of update events so reactive contexts can be rerun.

`d.process()` sets up subscriptions given a `value` and path `parts`. This should **only** create subscriptions, not subscribe them to any contexts. Even though this function will be rerun multiple times for the same subscriptions, the API will not duplicate subscriptions.

`d.subscribe()` is the default subscribe method used by subscriptions. `this` within the method will refer to the subscription using it. By passing `fn`, this method should set the proper events to call the context any time it needs to update.

`d.unsubscribe()` is the default unsubscribe method used by subscriptions. It is called in the same fashion as `d.subscribe()`. Given the same arguments, it should completely reverse anything done by the subscribe method.

Helpers
----------------

`d._parts()` takes a string `path` and divides it into an array of path parts. Optionally pass `base` to prefix it to path in the event `$` is not use.

`d._keysplit()` takes a string and separates it by `sep`. You can use `sep` in the path by prefixing it with `avoid`.

`d._deep()` gets or sets a `value` at `key` deeply within an object. When setting a `value` and `key` doesn't exist, objects are created to make it fit.

`d._trim()` normalizes a path by removing any leading or trailing separators.

`d._isBackboneData()` tests `obj` as a Backbone model or collection. Useful in determining if data can take events or needs to be accessed in a different way.