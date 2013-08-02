var Backbone = require("backbone-deep-model"),
	d = require("d");

// Set some initial data
t = new Backbone.DeepModel();

t.set("hello", {
	deep: "value"
});

t.set("other", {
	foo: "bar"
});

d.set("mymodel", t);
d.set("test.asdf.qwer", 1234);
console.log(d.model.toJSON());

d.bind("change:mymodel", function() {
	console.log(arguments);
});
//t.on("all", function(event) { console.log("mymodel", event); });

// Set up a few reactive contexts
r = d(function() {
	console.log("\n====r====");
	console.log(d("test.asdf"));
	d("mymodel", function() {
		console.log("====dr====");
		console.log(d("other.foo"));
		return console.log("====/dr====");
	});
	return console.log("====/r====\n");
});

o = d(function() {
	console.log("\n====o====");
	console.log(d("_session.deep"));
	return console.log("====/o====\n");
});

// Change some data and watch it update!
setTimeout(function() {
	var model;
	model = d.get("mymodel");
	console.log(model);
	model.set("other", {
		foo: "notbar"
	});
	model.set("hello", {
		deep: "anothervalue"
	});
	d.set("_session", {
		deep: "test"
	});
	d.set("test.asdf.lol", "value");
	return setTimeout(function() {
		r.stop();
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