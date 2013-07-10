var Backbone = require("backbone"),
	d = require("d");

// Set some initial data
t = new Backbone.Model();

t.set("hello", {
	deep: "value"
});

t.set("other", {
	foo: "bar"
});

d.set("mymodel", t);

// Set up a few reactive contexts
dr = d.reactive(function() {
	console.log("====dr====");
	console.log(d("other.foo"));
	return console.log("====/dr====");
}, {
	path: "mymodel"
});

r = d(function() {
	console.log("\n====r====");
	console.log(d("mymodel.hello.deep"));
	dr();
	return console.log("====/r====\n");
});

o = d(function() {
	console.log("\n====o====");
	console.log(d("_session.deep"));
	dr();
	return console.log("====/o====\n");
});

// Change some data and watch it update!
setTimeout(function() {
	var model;
	model = d.get("mymodel");
	model.set("other", {
		foo: "notbar"
	});
	model.set("hello", {
		deep: "anothervalue"
	});
	d.set("_session", {
		deep: "test"
	});
	r.stop();
	return setTimeout(function() {
		model.set("hello", {
			deep: "thirdvalue"
		});
		model.set("other", {
			foo: "backtobar"
		});
		return d.set("_session", {
			deep: "notsofast"
		});
	}, 1000);
}, 1000);