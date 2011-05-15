
jQuery.D ( or "D" ) v0.0.1
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

Anyways, read along... or move along.

---

API
====

D()
---

Same as $.Deferred constructor (no prototype enhancements)


---

D.isPromise( value )
--------------------------------------------------

Detects if a value is a promise

@param value {mixed} Value to validate

---

D.isDeferred( value )
--------------------------------------------------

Detects if a value is a deferred response

@param value {mixed} Value to validate

---

D.step( values )
--------------------------------------------------

Promises to resolve an array of values in sequence if all values pass or to fail
on first rejection.

@param values {Array} An array of values, promises or mixed values

---

D.parallel( values )
--------------------------------------------------

Promises to resolve an array of values in parallel if all values pass or to fail
on first rejection.

@param values {Array} An array of values, promises or mixed values

---

D.through( values )
--------------------------------------------------

Promises to fully resolve an array of values in sequence if all values pass or to fail
when all values have been analyzed if errors were encoutered

@param values {Array} An array of values, promises or mixed values

---

D.reduce( values , reductor ) 
--------------------------------------------------

Promises to resolve an array of values in sequence, applying a reductor function for
each itteration or to fail on first error met.

The reductor function works much like Array.reduce's reductor in that it receives as
a first argument, the accumulated resutls and in the second the current result. 
Accumulated results take on the shape of reductor's output. 

@param values {Array} An array of values, promises or mixed values
@param reductor {Function} A function  that accepts 2 arguments and returns output for next complete resolution


---

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

---

D.resolved( value ) 
--------------------------------------------------

Returns a pre-resolved promise, resolving to "value". 

Note: If value is a resolved promise, it will be returned as-is

@param value {Mixed} The value to resolve with

---

D.rejected( value )
--------------------------------------------------

Returns a pre-rejected promise, rejecting with "value". 

Note: If value is a rejected promise, it will be returned as-is

@param value {Mixed} The value to reject with

---

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

---

D.delay( promise, microseconds )
--------------------------------------------------

Makes certain a promise is not resolve or rejected before "microseconds" has been exhausted

@param promise {Promise} The promise to delay
@param microseconds {Number} By how many microseconds it should be delayed

---

D.timeout( promise, microseconds )
--------------------------------------------------

Makes certain a promise is rejected if not rejected or resolved within "microseconds"

@param promise {Promise} The promise to delay
@param microseconds {Number} How many microseconds to wait before expiring

