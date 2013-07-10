var express = require("express"),
	fs = require("fs"),
	path = require("path"),
	browserify = require("browserify");

var app = express();

app.get("/bundle.js", function(req, res) {
	var b = browserify();
	b.require(path.resolve(__dirname, "../lib/d.js"), { expose: "d" });
	b.add(path.resolve(__dirname, "./test.js"));
	b.bundle().pipe(res);
});

app.get("*", function(req, res) {
	res.send(fs.readFileSync(__dirname + "/index.html", "utf-8"));
});

app.listen(3000, function() {
	console.log("Express listening on port 3000.");
});