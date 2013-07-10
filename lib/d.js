// Generated by CoffeeScript 1.6.3
(function() {
  var Backbone, d, uuid, _;

  Backbone = require("backbone");

  _ = require("underscore");

  uuid = require("uuid");

  d = function() {
    return d.run.apply(d, arguments);
  };

  module.exports = d;

  d.model = new Backbone.Model();

  d.subs = {
    subscriptions: [],
    queue: [],
    create: function(path, data, ext) {
      var ctxs, sub, subscribe, unsubscribe;
      if (ext == null) {
        ext = {};
      }
      sub = this.find(path);
      if (!sub) {
        sub = {
          id: uuid.v4(),
          path: path,
          data: data,
          contexts: []
        };
        _.extend(sub, ext);
        _.defaults(sub, _.pick(d, ["subscribe", "unsubscribe"]));
        subscribe = ext.subscribe || d.subscribe;
        unsubscribe = ext.unsubscribe || d.unsubscribe;
        sub.subscribe = function(ctx, options) {
          var onstop,
            _this = this;
          subscribe.apply(this, arguments);
          this.contexts.push(ctx);
          if (ext.temporary) {
            onstop = function() {
              return d.subs.remove(_this.id);
            };
            ctx.on("stop", onstop);
            return ctx.on("run:before", onstop);
          }
        };
        sub.unsubscribe = function(ctx, options) {
          unsubscribe.apply(this, arguments);
          return this.contexts = _.without(this.contexts, ctx);
        };
        this.subscriptions.push(sub);
      } else if (!_.isEqual(data, sub.data)) {
        ctxs = sub.contexts;
        _.each(ctxs, function(ctx) {
          return sub.unsubscribe(ctx);
        });
        sub.contexts = [];
        sub.data = data;
        _.each(ctxs, function(ctx) {
          return sub.subscribe(ctx);
        });
      }
      this.queue.push(sub);
      return sub;
    },
    find: function(path) {
      return _.find(this.subscriptions, function(sub) {
        return sub.path === path || sub.id === path;
      });
    },
    remove: function(id) {
      var index, sub;
      if (!(sub = this.find(id))) {
        return;
      }
      _.each(sub.contexts, function(ctx) {
        return sub.unsubscribe(ctx);
      });
      index = _.indexOf(this.subscriptions, sub);
      return this.subscriptions.splice(index, 1);
    },
    clear: function() {
      return this.queue = [];
    }
  };

  d.get = function(path, options) {
    var base, ctx, parts, val;
    if (options == null) {
      options = {};
    }
    ctx = this.current;
    base = this._trim((ctx ? ctx.path : void 0) || "");
    parts = this._parts(path, base);
    val = this.retrieve(parts, options);
    if (options.reactive !== false && ctx) {
      d.subs.clear();
      this.process(val, parts, options);
      _.each(d.subs.queue, function(sub) {
        return ctx.subscribe(sub);
      });
      d.subs.clear();
    }
    if (val != null) {
      return val;
    } else {
      return options["default"];
    }
  };

  d.set = function(path, value, options) {
    var parts;
    if (options == null) {
      options = {};
    }
    parts = this._parts(path);
    return this.update(parts, value, options);
  };

  d.reactive = function(fn, options) {
    var reset, rfn, self;
    if (options == null) {
      options = {};
    }
    self = this;
    rfn = function() {
      var onstop, parent;
      if (rfn.running) {
        return;
      }
      parent = self.current;
      self.current = rfn;
      if (parent && !_.contains(rfn.parents, parent.id)) {
        rfn.parents.push(parent.id);
        onstop = function() {
          rfn.parents = _.without(rfn.parents, parent.id);
          if (!(rfn.parents.length || rfn.root)) {
            return rfn.stop();
          }
        };
        parent.on("stop", onstop);
        parent.on("run:before", onstop);
        rfn.trigger("start");
      }
      if (!parent) {
        rfn.root = true;
      }
      rfn.trigger("run:before");
      rfn.running = true;
      fn.call(rfn);
      rfn.trigger("run");
      rfn.running = false;
      rfn.trigger("run:after");
      return self.current = parent;
    };
    _.extend(rfn, Backbone.Events);
    rfn.id = uuid.v4();
    rfn.path = options.path;
    rfn.subscribe = function(sub, options) {
      if (options == null) {
        options = {};
      }
      if (_.contains(this.subscriptions, sub.id)) {
        return;
      }
      sub.subscribe(this, options);
      return this.subscriptions.push(sub.id);
    };
    rfn.unsubscribe = function(sub, options) {
      if (options == null) {
        options = {};
      }
      if (_.isString(sub)) {
        sub = self.subs.find(sub);
      }
      if (!_.contains(this.subscriptions, sub.id)) {
        return;
      }
      sub.unsubscribe(this, options);
      return this.subscriptions = _.without(this.subscriptions, sub.id);
    };
    rfn.stop = function(o) {
      var _this = this;
      if (o == null) {
        o = {};
      }
      _.each(this.subscriptions, function(id) {
        return _this.unsubscribe(id);
      });
      reset();
      return this.trigger("stop");
    };
    reset = function() {
      rfn.subscriptions = [];
      rfn.parents = [];
      return rfn.root = false;
    };
    reset();
    return rfn;
  };

  d.run = function(path, fn, options) {
    var r, _ref, _ref1;
    if (_.isObject(fn) && !_.isFunction(fn) && !options) {
      _ref = [fn, null], options = _ref[0], fn = _ref[1];
    }
    if (_.isFunction(path) && !fn) {
      _ref1 = [path, null], fn = _ref1[0], path = _ref1[1];
    }
    if (options == null) {
      options = {};
    }
    if (_.isFunction(fn)) {
      if (path) {
        _.extend(options, {
          path: path
        });
      }
      (r = this.reactive(fn, options))();
      return r;
    } else {
      return this.get(path, options);
    }
  };

  d.depend = function(data, options) {
    var ctx, sub;
    if (options == null) {
      options = {};
    }
    if (ctx = this.current) {
      sub = this.subs.create(uuid.v4(), {
        obj: data,
        subpath: null
      }, {
        temporary: true
      });
      ctx.subscribe(sub, options);
      d.subs.clear();
    }
  };

  d.retrieve = function(parts, options) {
    var cur,
      _this = this;
    if (options == null) {
      options = {};
    }
    cur = this.model;
    if (_.some(parts, function(p) {
      if (!_.isObject(cur)) {
        return true;
      } else if (_this._isBackboneData(cur)) {
        cur = cur.get(p);
      } else {
        cur = cur[p];
      }
      return false;
    })) {
      return void 0;
    }
    return cur;
  };

  d.update = function(parts, value, options) {
    var child, cur, lo, path, rp,
      _this = this;
    if (options == null) {
      options = {};
    }
    lo = this.model;
    cur = this.model;
    path = [];
    _.each(parts, function(p) {
      if (_this._isBackboneData(cur)) {
        lo = cur;
        cur = cur.get(p);
        path = [];
      } else if (_.isObject(cur)) {
        cur = cur[p];
      }
      return path.push(p);
    });
    rp = _.rest(path);
    child = lo.get(path[0]);
    if (rp.length) {
      if (!_.isObject(child)) {
        child = {};
      } else {
        child = _.clone(child);
      }
      this._deep(child, rp.join("."), value);
    } else {
      child = value;
    }
    return lo.set(path[0], child);
  };

  d.process = function(value, parts, options) {
    var add, base, flush, obj, paths, subpath,
      _this = this;
    if (options == null) {
      options = {};
    }
    obj = this.model;
    base = "";
    paths = [];
    subpath = [];
    add = function(part) {
      if (_.isEmpty(base)) {
        return base = part;
      } else {
        return base += "." + part;
      }
    };
    flush = function() {
      if (subpath.length) {
        add(subpath[0]);
      }
      _this.subs.create(base, {
        obj: obj,
        subpath: subpath[0] || null
      }, options);
      return subpath = [];
    };
    _.each(parts, function(p) {
      var val;
      paths.push(p);
      val = _this.retrieve(paths);
      subpath.push(p);
      if (_this._isBackboneData(val)) {
        flush();
        return obj = val;
      }
    });
    return flush();
  };

  d.subscribe = function(fn, options) {
    var attr, data, subpath;
    if (options == null) {
      options = {};
    }
    data = this.data.obj;
    subpath = this.data.subpath;
    if (_.isEqual(data, d.model) && !subpath) {

    } else if (data instanceof Backbone.Model) {
      attr = subpath ? ":" + subpath : "";
      return fn.listenTo(data, "change" + attr, fn);
    } else if (data instanceof Backbone.Collection) {
      fn.listenTo(data, "add", fn);
      fn.listenTo(data, "remove", fn);
      return fn.listenTo(data, "sort", fn);
    }
  };

  d.unsubscribe = function(fn, options) {
    var data, subpath;
    if (options == null) {
      options = {};
    }
    data = this.data.obj;
    subpath = this.data.subpath;
    if (_.isEqual(data, d.model) && !subpath) {

    } else if (d._isBackboneData(data)) {
      return fn.stopListening(data);
    }
  };

  d._parts = function(path, base) {
    path = d._trim(path);
    if (/^\$/.test(path)) {
      path = path.replace(/^\$\.?/, "");
    } else if (base) {
      path = base + "." + path;
    }
    return _.compact(this._keysplit(path));
  };

  d._keysplit = function(str, sep, avoid) {
    var i, len, part, parts, rawParts;
    if (sep == null) {
      sep = ".";
    }
    if (avoid == null) {
      avoid = "\\";
    }
    rawParts = str.split(sep);
    parts = [];
    i = 0;
    len = rawParts.length;
    while (i < len) {
      part = "";
      while (rawParts[i].slice(-1) === avoid) {
        part += rawParts[i++].slice(0, -1) + sep;
      }
      parts.push(part + rawParts[i]);
      i++;
    }
    return parts;
  };

  d._deep = function(obj, key, value) {
    var i, keys, n, root;
    keys = _.compact(this._keysplit(key));
    i = 0;
    n = keys.length;
    if (arguments.length > 2) {
      root = obj;
      n--;
      while (i < n) {
        key = keys[i++];
        obj = obj[key] = (_.isObject(obj[key]) ? obj[key] : {});
      }
      obj[keys[i]] = value;
      value = root;
    } else {
      while (((obj = obj[keys[i++]]) != null) && i < n) {
        continue;
      }
      value = (i < n ? void 0 : obj);
    }
    return value;
  };

  d._trim = function(str, sep) {
    var len, ss;
    if (sep == null) {
      sep = ".";
    }
    len = sep.length;
    ss = function() {
      return String.prototype.substr.apply(str, arguments);
    };
    while (ss(0, len) === sep) {
      str = ss(len);
    }
    while (ss(-1 * len) === sep) {
      str = ss(0, str.length - len);
    }
    return str;
  };

  d._isBackboneData = function(obj) {
    return _.isObject(obj) && (obj instanceof Backbone.Model || obj instanceof Backbone.Collection);
  };

}).call(this);