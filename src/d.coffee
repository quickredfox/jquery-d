###
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
    
###

$ = jQuery = require 'jquery'
D = (fn)->
    $.Deferred.call(this,fn)
D::=$.Deferred::
D.version = 'v0.0.1'


fargs = (args)-> Array::slice.call( args )

coerce = (values)->
    values.map (value)->
        if D.isPromise value
            return value
        else
            return D().resolveWith( null, value ).promise()

pushValue = (values,value)->
    if typeof values is "undefined"
        values = []
    values.push value
    return values
    
pushError = (errors,error)->
    if typeof errors is "undefined"
        errors = []
    errors.push error
    return errors
 
sequence = ( promises=[], initial=D(), passthrough = false, setValue =pushValue, setError = pushError, result = {values:[],errors:[] } )->        
    if promises.length is 0 
        return initial.resolveWith( null, [ result.values ] ).promise()    
    promise = promises.shift()
    promise.done   ( value )-> 
        result.values = setValue result.values, value
    promise.fail   ( error )->   
        result.errors = setError result.errors, error 
    promise.always ( )->
        if promise.isRejected() and not passthrough
            initial.rejectWith( null, [ result.errors ] )
        else
            if promises.length isnt 0 
                sequence promises, initial, passthrough, setValue, setError, result
            else
                if result.errors.length is 0
                    initial.resolveWith null, [ result.values ]
                else
                    initial.rejectWith null, [ result.errors ]
                    
parallel = ( promises=[], initial = D(), passthrough = true, expected = null, ran = 0,values=[], errors=[] )->
    expected = if expected is null then promises.length else expected
    promises.forEach (promise)->
        promise.done   (value)->  values.push( value )
        promise.fail  (error)->  
            errors.push( error )
            if passthrough is false 
                initial.rejectWith( null, [ errors ] )
        promise.always ()->  
            if ++ran is expected
                unless passthrough
                    return if errors.length is 0 then initial.resolveWith null, [ values ]  else initial.rejectWith null, [ errors ] 
                else
                    return initial.resolveWith( null, [ values.reduce( (p,n)-> p||n) , errors.reduce( (p,n)-> p||n ) ] )
    return initial.promise()
    
Negociator = (fn)->
    negociation = D(  )
    promise     = negociation.promise()
    negotiated  = false
    $.extend promise, ['done','then','fail','always'].reduce (object,name)->
        ref = object[name]
        object[name] = ()->
            if !negotiated
                negotiated = true
                try
                    result = fn.call( null, negociation )
                catch E
                    return negociation.rejectWith null, [ E ]
                if D.isPromise result
                    result.done ()->
                        negociation.resolveWith null, arguments 
                    result.fail ()->
                        negociation.rejectWith  null, arguments 
                else if typeof result is 'function'
                    negociation.rejectWith null, [ new TypeError('negociators cannot return functions') ]
                else
                    negociation.resolveWith null, [ result ]
            object[name] = ref
            object[name].apply object[name], arguments
        return object
    , promise
    return promise

###
    D.isPromise( value )
    --------------------------------------------------
    
    Detects if a value is a promise
    
    @param value {mixed} Value to validate
###    
D.isPromise = (value)-> 
    Boolean(value and value.promise and 'function' is typeof value.promise and value.promise().promise )   

###
    D.isDeferred( value )
    --------------------------------------------------
    
    Detects if a value is a deferred response
    
    @param value {mixed} Value to validate
###
D.isDeferred = (value)->
    Boolean(value and value.resolveWith and 'function' is typeof value.resolveWith and  value.rejectWith and 'function' is typeof value.rejectWith )   

###
    D.step( values )
    --------------------------------------------------
    
    Promises to resolve an array of values in sequence if all values pass or to fail
    on first rejection.
    
    @param values {Array} An array of values, promises or mixed values
###
D.step = ( values )->
    values = coerce(values)
    operation = D()
    sequence values, operation
    return operation.promise()
    
###
    D.parallel( values )
    --------------------------------------------------
    
    Promises to resolve an array of values in parallel if all values pass or to fail
    on first rejection.
    
    @param values {Array} An array of values, promises or mixed values
###
D.parallel = ( values )->
    values = coerce(values)
    operation = D()
    parallel values, operation, false
    return operation.promise()

###
    D.through( values )
    --------------------------------------------------
    
    Promises to fully resolve an array of values in sequence if all values pass or to fail
    when all values have been analyzed if errors were encoutered
    
    @param values {Array} An array of values, promises or mixed values
###
D.through = ( values )->
    values = coerce(values)
    operation = D()
    sequence values, operation, true
    return operation.promise()

###
    D.reduce( values , reductor ) 
    --------------------------------------------------
    
    Promises to resolve an array of values in sequence, applying a reductor function for
    each itteration or to fail on first error met.
    
    The reductor function works much like Array.reduce's reductor in that it receives as
    a first argument, the accumulated resutls and in the second the current result. 
    Accumulated results take on the shape of reductor's output. 
    
    @param values {Array} An array of values, promises or mixed values
    @param reductor {Function} A function  that accepts 2 arguments and returns output for next complete resolution

###
D.reduce = ( values, joinFn=pushValue, errFn=pushError )->
    values = coerce(values)
    operation = D()
    valuereductor = ()->
        ret = null
        try
            ret = joinFn.apply null, arguments
        catch E
            operation.rejectWith null, [ E ]
    errorreductor = ()->
        ret = null
        try
            ret = errFn.apply null, arguments
        catch E
            operation.rejectWith null, [ E ]
    sequence values, operation, true, valuereductor, errorreductor
    return operation.promise()

###
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
###
D.negociate = (fn)->
    if typeof fn isnt 'function' 
        throw new TypeError('negociate expects a negociator function') 
    else
        negociator = Negociator(fn)
    return negociator

###
    D.resolved( value ) 
    --------------------------------------------------
    
    Returns a pre-resolved promise, resolving to "value". 
    
    Note: If value is a resolved promise, it will be returned as-is
    
    @param value {Mixed} The value to resolve with
###
D.resolved = (value)->
    return value if D.isPromise( value ) and value.isResolved()
    p = D()
    p.resolveWith null, [ value ]
    return p.promise()

###
    D.rejected( value )
    --------------------------------------------------
    
    Returns a pre-rejected promise, rejecting with "value". 

    Note: If value is a rejected promise, it will be returned as-is
    
    @param value {Mixed} The value to reject with
###    
D.rejected = (value)->
    return value if D.isPromise( value ) and value.isRejected()
    p = D()
    p.rejectWith null, [ value ]
    return p.promise()

###
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
###
D.deep = ( values )->
    operation = D()
    todo = []
    if $.isPlainObject(values) or $.type(values) is 'array'
        $.each values, (key, value)->
            if D.isPromise value
                value.done (real)->
                    values[key] = real
                value.fail (e)-> #operation.reject
                    values[key] = new Error "deep promise failed: #{e}"
                todo.push value
            else if $.isPlainObject(values) or $.type(values) is 'array'
                todo.push D.deep(value)
    D.through( todo ).then ()->
        operation.resolveWith null, [values]
    , (errors)->
        operation.rejectWith null, [ errors, values ]
    return operation.promise()

###
    D.delay( promise, microseconds )
    --------------------------------------------------
    
    Makes certain a promise is not resolve or rejected before "microseconds" has been exhausted
    
    @param promise {Promise} The promise to delay
    @param microseconds {Number} By how many microseconds it should be delayed
###
D.delay = (promise,time)->
    delayed = D()
    promise.done ()->
        args = fargs arguments    
        setTimeout ()->
            delayed.resolveWith null, args
        , time
    promise.fail ()->
        args = fargs arguments    
        setTimeout ()->
            delayed.rejectWith null, args
        , time
    return delayed.promise()

###
    D.timeout( promise, microseconds )
    --------------------------------------------------
    
    Makes certain a promise is rejected if not rejected or resolved within "microseconds"
    
    @param promise {Promise} The promise to delay
    @param microseconds {Number} How many microseconds to wait before expiring
###
D.timeout = (promise,time)->
    timed = D()
    TO = setTimeout ()->
        timed.rejectWith null, [ 'timeout' ]
    , time
    promise.done ()-> 
        clearTimeout TO
        timed.resolveWith null, arguments
    promise.fail ()->
        timed.rejectWith  null, arguments
    return timed.promise()

$.D = module.exports = D
$.D::=module.exports::=D::
