(function() {
  /*
      jQuery.D ( or "D" ) v0.0.2
      ==========================
      
      Exports "D" or jQuery.D which "subclasses" jQuery.Deferred adding 
      a few utility methods to work with promises.
      
      Started off as an experimental somewhat [Q](http://github.com/kriskowal/q) inspired lib
      and then decided to totally go in my own direction because quite frankly I'm not up to 
      the comp-sci level needed to do any better, and this will work good enough for me if 
      tested throughly, which I'm focusing on (as well as learning how to test things).
      
      It does seemingly work though, and the uses I have for it dont necessarily require 
      ultimate performance optimisations so until something better pops up, this could also 
      be useful for you. For practice purposes maybe?
      
      The main reason any of this exists is for D.deep(). I dont think it maps directly to 
      Q-utils's deep() method but it works to my understanding of what a $.whenDeep should do.
      
      In fact, I realy needed to bundle multiple calls to a 3-rd party service or multiple 3-rd party
      services into one simple logical aspect that I could work with...
      
      You've probably often seen examples of promises being used to bundle two ajax calls, well here's
      how one could do it using D.deep()
      
  
      Dastardly
  
          var session = ...;
          var fetchTwitterProfile = $.ajax( { url: 'http://api.twitter.com/...' } );
          var fetchTwitterTimeline = $.ajax( { url: 'http://api.twitter.com/...' } );
          var merged = $.Deferred()
          $.when( fetchTwitterProfile, fetchTwitterTimeline ).done( function( results ){
              userPreview = {
                  session: session,
                  profile: results[0],
                  timeline: results[1]
              }
              merged.resolveWith( null, [ userPreview ] );
          });
          merged.then( function(){ // etc. } ) 
          
      Ah! 
  
          var userPreview = {
              session: { id: 1 }, // data we already have
              profile:  $.ajax( { url: 'http://api.twitter.com/...' } ),
              timeline: $.ajax( { url: 'http://api.twitter.com/...' } )
          };
          $.D.deep( userPreview ).done(function( fullyResolved ){
              fullyResolved === {
                  session: { id: 1 }, // data we already had
                  profile: { // JSON output from twitter user fetch  },
                  timeline: { // JSON output from twitter timeline fetch  }
              }
          });
          
      So D.deep() can pretty much handle any complex call structure, but I also figured that
      if the case was as simple as above, you might need something more suited.
      
      
          var fetches = [ $.ajax( { url: 'http://api.twitter.com/...' } ), $.ajax( { url: 'http://api.twitter.com/...' } )]
          reduction   = $.D.reduce( fetches, function(accumulator,result){
              if( typeof accumulator is 'undefined' ){
                  if( result.screen_name ){
                      accumulator = result.screen_name;
                      accumulator.session = session;
                  }else if(result.length && result.length > 0){
                      accumulator.public_timeline = result;
                  }else{
                      accumulator.public_timeline = [];
                  }
                  return accumulator
              };
          })
          reduction.done(function( value ){
              value.screen_name // twitter user screen name
              value.public_timeline // collection of tweets
          })
      
      I also introduced a concept I call "negociators". A negociator is a function that 
      accepts a promise as it's sole argument and is duty-bound to either return a value 
      or a promise but never a function. A negociator is signed using $.negociate() which 
      returns a negociation promise. When the first callback of any type is attached to 
      the negociation promise it automaticall xecutes the negociator and returns a promise
      for the result. 
      
      This allows us to slip some logic into our promise collections like such:
      
          loader.update = function(n){
              console.log("Progress: "+n)
              return this;
          }
          updates = 0;
          var n1 = function(negociation){ return loader.show().update(++updates) }
          var n2 = function(negociation){ return loader.update(++updates) }
          var promises = [
              $.ajax( { url: 'http://api.twitter.com/...' } ),
              $.D.negociate( n1 ),
              $.ajax( { url: 'http://api.twitter.com/...' } ),
              $.D.negociate( n2 ),
              $.ajax( { url: 'http://api.twitter.com/...' } ),
              $.D.negociate( n2 ),
          ]
  
  
      Anyways, read along... or move along.
      
      ---
  
      API
      ====
      
      D()
      ---
      
      Same as $.Deferred constructor (no prototype enhancements)
      
  */  var $, D, Negociator, coerce, fargs, isEnum, isNode, jQuery, parallel, pushError, pushValue, sequence;
  isNode = typeof process !== "undefined" && process.versions && !!process.versions.node;
  if (isNode) {
    $ = jQuery = require('jquery');
  } else {
    $ = jQuery = window.jQuery;
  }
  D = function(fn) {
    return $.Deferred.call(this, fn);
  };
  D.prototype = $.Deferred.prototype;
  D.version = 'v0.0.2';
  fargs = function(args) {
    return Array.prototype.slice.call(args);
  };
  coerce = function(values) {
    return values.map(function(value) {
      if (D.isPromise(value)) {
        return value;
      } else {
        return D().resolveWith(null, [value]).promise();
      }
    });
  };
  pushValue = function(values, value) {
    if (typeof values === "undefined") {
      values = [];
    }
    values.push(value);
    return values;
  };
  pushError = function(errors, error) {
    if (typeof errors === "undefined") {
      errors = [];
    }
    errors.push(error);
    return errors;
  };
  sequence = function(promises, initial, passthrough, setValue, setError, result) {
    var promise;
    if (promises == null) {
      promises = [];
    }
    if (initial == null) {
      initial = D();
    }
    if (passthrough == null) {
      passthrough = false;
    }
    if (setValue == null) {
      setValue = pushValue;
    }
    if (setError == null) {
      setError = pushError;
    }
    if (result == null) {
      result = {
        values: [],
        errors: []
      };
    }
    if (promises.length === 0) {
      return initial.resolveWith(null, [result.values]).promise();
    }
    promise = promises.shift();
    promise.done(function(value) {
      return result.values = setValue(result.values, value);
    });
    promise.fail(function(error) {
      return result.errors = setError(result.errors, error);
    });
    return promise.always(function() {
      if (promise.isRejected() && !passthrough) {
        return initial.rejectWith(null, [result.errors]);
      } else {
        if (promises.length !== 0) {
          return sequence(promises, initial, passthrough, setValue, setError, result);
        } else {
          if (result.errors.length === 0) {
            return initial.resolveWith(null, [result.values]);
          } else {
            return initial.rejectWith(null, [result.errors]);
          }
        }
      }
    });
  };
  parallel = function(promises, initial, passthrough, expected, ran, values, errors) {
    if (promises == null) {
      promises = [];
    }
    if (initial == null) {
      initial = D();
    }
    if (passthrough == null) {
      passthrough = true;
    }
    if (expected == null) {
      expected = null;
    }
    if (ran == null) {
      ran = 0;
    }
    if (values == null) {
      values = [];
    }
    if (errors == null) {
      errors = [];
    }
    expected = expected === null ? promises.length : expected;
    promises.forEach(function(promise) {
      promise.done(function(value) {
        return values.push(value);
      });
      promise.fail(function(error) {
        errors.push(error);
        if (passthrough === false) {
          return initial.rejectWith(null, [errors]);
        }
      });
      return promise.always(function() {
        if (++ran === expected) {
          if (!passthrough) {
            if (errors.length === 0) {
              return initial.resolveWith(null, [values]);
            } else {
              return initial.rejectWith(null, [errors]);
            }
          } else {
            return initial.resolveWith(null, [
              values.reduce(function(p, n) {
                return p || n;
              }), errors.reduce(function(p, n) {
                return p || n;
              })
            ]);
          }
        }
      });
    });
    return initial.promise();
  };
  Negociator = function(fn) {
    var negociation, negotiated, promise;
    negociation = D();
    promise = negociation.promise();
    negotiated = false;
    $.extend(promise, ['done', 'then', 'fail', 'always'].reduce(function(object, name) {
      var ref;
      ref = object[name];
      object[name] = function() {
        var result;
        if (!negotiated) {
          negotiated = true;
          try {
            result = fn.call(null, negociation);
          } catch (E) {
            return negociation.rejectWith(null, [E]);
          }
          if (D.isPromise(result)) {
            result.done(function() {
              return negociation.resolveWith(null, arguments);
            });
            result.fail(function() {
              return negociation.rejectWith(null, arguments);
            });
          } else if (typeof result === 'function') {
            negociation.rejectWith(null, [new TypeError('negociators cannot return functions')]);
          } else {
            negociation.resolveWith(null, [result]);
          }
        }
        object[name] = ref;
        return object[name].apply(object[name], arguments);
      };
      return object;
    }, promise));
    return promise;
  };
  /*
      D.isPromise( value )
      --------------------------------------------------
      
      Detects if a value is a promise
      
      @param value {mixed} Value to validate
  */
  D.isPromise = function(value) {
    var ispromise;
    ispromise = value && 'function' === typeof value.promise;
    ispromise = ispromise && 'function' === typeof value.done;
    ispromise = ispromise && 'function' === typeof value.fail;
    return Boolean(ispromise);
  };
  /*
      D.isDeferred( value )
      --------------------------------------------------
      
      Detects if a value is a deferred response
      
      @param value {mixed} Value to validate
  */
  D.isDeferred = function(value) {
    return Boolean(value && value.resolveWith && 'function' === typeof value.resolveWith && value.rejectWith && 'function' === typeof value.rejectWith);
  };
  /*
      D.step( values )
      --------------------------------------------------
      
      Promises to resolve an array of values in sequence if all values pass or to fail
      on first rejection.
      
      @param values {Array} An array of values, promises or mixed values
  */
  D.step = function(values) {
    var operation;
    values = coerce(values);
    operation = D();
    try {
      sequence(values, operation);
    } catch (E) {
      operation.reject(E);
    }
    return operation.promise();
  };
  /*
      D.parallel( values )
      --------------------------------------------------
      
      Promises to resolve an array of values in parallel if all values pass or to fail
      on first rejection.
      
      @param values {Array} An array of values, promises or mixed values
  */
  D.parallel = function(values) {
    var operation;
    values = coerce(values);
    operation = D();
    parallel(values, operation, false);
    return operation.promise();
  };
  /*
      D.through( values )
      --------------------------------------------------
      
      Promises to fully resolve an array of values in sequence if all values pass or to fail
      when all values have been analyzed if errors were encoutered
      
      @param values {Array} An array of values, promises or mixed values
  */
  D.through = function(values) {
    var operation;
    values = coerce(values);
    operation = D();
    sequence(values, operation, true);
    return operation.promise();
  };
  /*
      D.reduce( values , reductor ) 
      --------------------------------------------------
      
      Promises to resolve an array of values in sequence, applying a reductor function for
      each itteration or to fail on first error met.
      
      The reductor function works much like Array.reduce's reductor in that it receives as
      a first argument, the accumulated resutls and in the second the current result. 
      Accumulated results take on the shape of reductor's output. 
      
      @param values {Array} An array of values, promises or mixed values
      @param reductor {Function} A function  that accepts 2 arguments and returns output for next complete resolution
  
  */
  D.reduce = function(values, joinFn, errFn) {
    var errorreductor, operation, valuereductor;
    if (joinFn == null) {
      joinFn = pushValue;
    }
    if (errFn == null) {
      errFn = pushError;
    }
    values = coerce(values);
    operation = D();
    valuereductor = function() {
      var ret;
      ret = null;
      try {
        return ret = joinFn.apply(null, arguments);
      } catch (E) {
        return operation.rejectWith(null, [E]);
      }
    };
    errorreductor = function() {
      var ret;
      ret = null;
      try {
        return ret = errFn.apply(null, arguments);
      } catch (E) {
        return operation.rejectWith(null, [E]);
      }
    };
    sequence(values, operation, true, valuereductor, errorreductor);
    return operation.promise();
  };
  /*
      D.negociate( negociator )
      --------------------------------------------------
      
      Takes a function and turns it into a negociator.
      
      A negociator is a function that promises to return a deferred promise. 
      A negociator is "executed" only once and as soon as any callback is applied
      A negociator accepts it's negociation promise as a first argument, which can 
      then be rejected or resolved
  
      Note: This allows us to slip some negociations into a promise resolving workflow, which 
      must be executed at a specific time in the sequence. 
      
      @param negociator {Function} A function that does not return a function (usually return a value or promise)
  */
  D.negociate = function(fn) {
    var negociator;
    if (typeof fn !== 'function') {
      throw new TypeError('negociate expects a negociator function');
    } else {
      negociator = Negociator(fn);
    }
    return negociator;
  };
  /*
      D.resolved( value ) 
      --------------------------------------------------
      
      Returns a pre-resolved promise, resolving to "value". 
      
      Note: If value is a resolved promise, it will be returned as-is
      
      @param value {Mixed} The value to resolve with
  */
  D.resolved = function(value) {
    var p;
    if (D.isPromise(value) && value.isResolved()) {
      return value;
    }
    p = D();
    p.resolveWith(null, [value]);
    return p.promise();
  };
  /*
      D.rejected( value )
      --------------------------------------------------
      
      Returns a pre-rejected promise, rejecting with "value". 
  
      Note: If value is a rejected promise, it will be returned as-is
      
      @param value {Mixed} The value to reject with
  */
  D.rejected = function(value) {
    var p;
    if (D.isPromise(value) && value.isRejected()) {
      return value;
    }
    p = D();
    p.rejectWith(null, [value]);
    return p.promise();
  };
  /*
      D.deep( values )
      --------------------------------------------------
      
      Takes any argument, and promises to either return it fully and deeply resolved, otherwise fails.
      
      Practical example: 
      
          TwitterPreview = {
              profile: $.ajax( { url: <url to fetch user data> }),
              timeline: $.ajax( { url: <url to fetch user public timeline> })
          }
          fetchPreview = $.deep( TwitterPreview )
          fetchPreview.done( function(){
              TwitterPreview.profile = {...}    //=> api JSON response for user profile
              TwitterPreview.timeline = {...}  //=> api JSON response for public timeline
          })
      
      @param values {Mixed} Something to be deeply resolved
  */
  isEnum = function(o) {
    return $.isPlainObject(o) || $.type(o) === 'array';
  };
  D.deep = function(values) {
    var operation, todo;
    operation = D();
    todo = [];
    if (isEnum(values)) {
      $.each(values, function(key, value) {
        if (D.isPromise(value)) {
          value.done(function(real) {
            return values[key] = real;
          });
          value.fail(function(e) {
            return values[key] = new Error("deep promise failed: " + e);
          });
          return todo.push(value);
        } else if (isEnum(value)) {
          return todo.push(D.deep(value));
        } else {
          return values[key] = value;
        }
      });
    }
    D.through(todo).then(function() {
      return operation.resolveWith(null, [values]);
    }, function(errors) {
      return operation.rejectWith(null, [errors, values]);
    });
    return operation.promise();
  };
  /*
      D.delay( promise, microseconds )
      --------------------------------------------------
      
      Makes certain a promise is not resolve or rejected before "microseconds" has been exhausted
      
      @param promise {Promise} The promise to delay
      @param microseconds {Number} By how many microseconds it should be delayed
  */
  D.delay = function(promise, time) {
    var delayed;
    delayed = D();
    promise.done(function() {
      var args;
      args = fargs(arguments);
      return setTimeout(function() {
        return delayed.resolveWith(null, args);
      }, time);
    });
    promise.fail(function() {
      var args;
      args = fargs(arguments);
      return setTimeout(function() {
        return delayed.rejectWith(null, args);
      }, time);
    });
    return delayed.promise();
  };
  /*
      D.timeout( promise, microseconds )
      --------------------------------------------------
      
      Makes certain a promise is rejected if not rejected or resolved within "microseconds"
      
      @param promise {Promise} The promise to delay
      @param microseconds {Number} How many microseconds to wait before expiring
  */
  D.timeout = function(promise, time) {
    var TO, timed;
    timed = D();
    TO = setTimeout(function() {
      return timed.rejectWith(null, ['timeout']);
    }, time);
    promise.done(function() {
      clearTimeout(TO);
      return timed.resolveWith(null, arguments);
    });
    promise.fail(function() {
      return timed.rejectWith(null, arguments);
    });
    return timed.promise();
  };
  if (isNode) {
    $.D = module.exports = D;
    $.D.prototype = module.exports.prototype = D.prototype;
  } else {
    $.D = D;
    $.D.prototype = D.prototype;
  }
}).call(this);
