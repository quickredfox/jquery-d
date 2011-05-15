require.paths.unshift require('path').resolve(__dirname,"../src")
if typeof XMLHttpRequest is 'undefined'
    XMLHttpRequest = require( 'xmlhttprequest' ).XMLHttpRequest     
$ = jQuery = require 'jQuery'
D      = require 'd'

analyze = (msg,fn)->
    module.exports[msg] = fn


###
    D functions tested:

    isPromise: [Function],
    step: [Function],
    parallel: [Function],
    through: [Function],
    reduce: [Function],
    negociate: [Function],
    resolved: [Function],
    rejected: [Function],
    deep: [Function],
    delay: [Function],
    timeout: [Function] }
    
###
analyze "D.isDeferred should return a boolean stating if the passed in argument is a deferred response", (test)->
    test.expect 3
    test.ok D.isDeferred( D() ), 'should be deferred'
    test.ok D.isDeferred( $.Deferred() ), 'should be deferred'    
    test.ok !D.isDeferred( D.resolved(true) ), 'should not be a deferred'    
    # timed out because D.resolved() is async
    setTimeout ()->
        test.done()
    , 1


analyze 'D.isPromise() should return a boolean stating if the passed in argument is a promise or not', (test)->
    promises    = [ 
        D().resolve(undefined).promise()
        D().resolve(true).promise()
        D().resolve(Date).promise()
        D().resolve({}).promise()
        D().resolve(false).promise()
        D().resolve(Infinity).promise() 
    ]
    notpromises = [ 
        undefined
        true
        Date
        { promise:()-> true }
        false
        Infinity 
    ]
    test.expect( 12 )
    notpromises.forEach (value)->
        test.ok !D.isPromise(value), "#{$.type(value)} is not a promise"
    promises.forEach (value)->
        test.ok D.isPromise(value), "#{$.type(value)} is a promise"        
    setTimeout test.done, 100

analyze "D.negociate() should only accept a function as argument", (test)->
    test.expect( 2 )
    out = null
    try
        D.negociate( {} )
        test.ok false, 'should throw if argument not a function'
    catch E
        test.ok true, 'should throw if argument not a function'
    try
        
        test.ok true, 'should accept a function argument'
    catch E
        test.ok false, 'should accept a function argument'
    setTimeout test.done, 100
    
analyze "D.negociate() should return a promise.", (test)->    
    test.expect( 1 )
    test.ok D.isPromise( D.negociate( ()-> ) ), 'should return a promise'
    setTimeout test.done, 100
    

analyze "D.negociate()'s return promise should fail if negociator returns a function and succeed otherwise", (test)->    
    test.expect( 2 )
    promise = D.negociate( ()-> return ()-> ).then ()->
        test.ok( false, 'should have failed when returning a function')
    ,()-> test.ok( true, 'failed because we return a function')
    promiseII = D.negociate( ()-> return ).then ()->
        test.ok( true, 'should have passed with undefined')
    ,()-> test.ok( false, 'should have passed with undefined')
    setTimeout test.done, 100
    
analyze "D.resolved() should return a pre-resolved promise to the given value", (test)->
    test.expect(1)
    value = D.resolved( 'resolved' )
    value.done (r)->
        test.equal r, 'resolved', 'resolved to the proper value'
    value.fail (r)->
        test.equal r, 'resolved', 'resolved to the proper value'
    test.done()
    
analyze "D.resolved() should be resolved even with a failed promise as a value", (test)->
    test.expect(1)
    rejected = D.rejected('rejected')
    value = D.resolved( rejected )
    value.done (r)->
        test.deepEqual r, rejected, 'resolved to the proper value'
    value.fail (r)->
        test.deepEqual r, rejected, 'resolved to the proper value'
    test.done()

analyze "D.rejected() should return a pre-rejected promise to the given value", (test)->
    test.expect(1)
    value = D.rejected( 'rejected' )
    value.done (r)->
        test.equal r, 'rejected', 'rejected with the proper value'
    value.fail (r)->
        test.equal r, 'rejected', 'rejected with the proper value'
    test.done()

analyze "D.rejected() should be rejected even with a succesful promise as a value", (test)->
    test.expect(1)
    resolved = D.resolved('resolved')
    value = D.rejected( resolved )
    value.done (r)->
        test.deepEqual r, resolved, 'rejected with the proper value'
    value.fail (r)->
        test.deepEqual r, resolved, 'rejected with the proper value'
    test.done()
    
analyze "success of D.delay should return a promise to resolve the passed-in promise only after a certain period of time", (test)->
    test.expect(2)
    resolved = false
    setTimeout ()->
        test.ok( !resolved, 'should not have resolved in less than a second' )
    , 1000
    setTimeout ()->
        test.ok( resolved, 'should be resolved after 3 seconds' )
        test.done()
    , 3000
    D.delay( D.resolved(true), 2000 ).done ()->
        resolved = true       

analyze "failure of D.delay should return a promise to resolve the passed-in promise only after aa ertain period of time", (test)->
    test.expect(2)
    resolved = false
    setTimeout ()->
        test.ok( !resolved, 'should not have resolved in less than a second' )
    , 1000
    setTimeout ()->
        test.ok( resolved, 'should be resolved after 3 seconds' )
        test.done()
    , 3000
    D.delay( D.rejected(true), 2000 ).fail ()->
        resolved = true 
        
analyze "success of D.timeout should return a promise to fail the passed-in promise if a certain period of time is exhausted", (test)->
    test.expect(1)
    latePromise = D.delay( D.resolved(true), 5000)
    D.timeout( latePromise , 1000 ).then ()->
        test.ok false, 'didnt time out'
        test.done()
    , ()->
        test.ok true, 'timed out before 5 seconds'
        test.done()

analyze "D.step() should run through values in order, resolving each one until full success", (test)->
    test.expect(6)
    promises    = [ 
        D.delay D.resolved(1), 333
        D.delay D.resolved(2), 222
        D.delay D.resolved(3), 111
        D.delay D.resolved(4), 33
        D.delay D.resolved(5), 22
        D.delay D.resolved(6), 11                                            
    ]
    steps = D.step( promises )
    steps.done (values)->
        test.equal values[0], 1, "resolved steps in order"
        test.equal values[1], 2, "resolved steps in order"
        test.equal values[2], 3, "resolved steps in order"
        test.equal values[3], 4, "resolved steps in order"
        test.equal values[4], 5, "resolved steps in order"
        test.equal values[5], 6, "resolved steps in order"
        test.done()
    steps.fail ()-> test.done()
      
analyze "D.step() should fail on first rejection", (test)->
    test.expect(1)
    promises    = [ 
        D.delay D.resolved(1), 333
        D.delay D.resolved(2), 222
        D.delay D.rejected(3), 111
        D.delay D.resolved(4), 33
        D.delay D.resolved(5), 22
        D.delay D.resolved(6), 11                                            
    ]
    steps = D.step( promises )
    steps.fail (values)->
        test.equal values[0], 3, "stopped on first rejection"
        test.done()
    steps.done ()-> test.done()
    
analyze "D.through() should run through values in order, resolving or failing if all is done and errors were returned", (test)->
    test.expect(3)
    promises    = [ 
        D.delay D.resolved(1), 333
        D.delay D.resolved(2), 222
        D.delay D.resolved(3), 111
        D.delay D.rejected(4), 33
        D.delay D.rejected(5), 22
        D.delay D.rejected(6), 11                                            
    ]
    steps = D.through( promises )
    steps.fail (errors)->
        test.equal errors[0], 4, "analyzed all steps in order"
        test.equal errors[1], 5, "analyzed all steps in order"
        test.equal errors[2], 6, "analyzed all steps in order"
        test.done()
    steps.done ()-> test.done()

analyze "D.through() should return all values if nothing fails", (test)->
    test.expect(1)
    promises    = [ 
        D.delay D.resolved(1), 333
        D.delay D.resolved(2), 222
        D.delay D.resolved(3), 111
        D.delay D.resolved(4), 33
        D.delay D.resolved(5), 22
        D.delay D.resolved(6), 11                                            
    ]
    steps = D.through promises
    steps.done (values)->
        test.deepEqual values, [1,2,3,4,5,6], 'returns values resolved in order'
        test.done()
    steps.fail ()-> test.done()

analyze "D.parallel() should return all values in resolution order, resolving or failing if all is done and errors were returned", (test)->
    test.expect(6)
    promises    = [ 
        D.delay D.resolved(1), 333
        D.delay D.resolved(2), 222
        D.delay D.resolved(3), 111
        D.delay D.resolved(4), 33
        D.delay D.resolved(5), 22
        D.delay D.resolved(6), 11                                            
    ]
    steps = D.parallel promises
    steps.done (values)->
        test.ok values.indexOf(1) > -1, 'found all values'
        test.ok values.indexOf(2) > -1, 'found all values'
        test.ok values.indexOf(3) > -1, 'found all values'
        test.ok values.indexOf(4) > -1, 'found all values'
        test.ok values.indexOf(5) > -1, 'found all values'
        test.ok values.indexOf(6) > -1, 'found all values'                                        
        test.done()
    steps.fail ()-> test.done()
analyze "D.parallel() should fail on first error", (test)->
    test.expect(1)
    promises    = [ 
        D.delay D.resolved(1), 333
        D.delay D.resolved(2), 222
        D.delay D.resolved(3), 111
        D.delay D.rejected(4), 33
        D.delay D.rejected(5), 22
        D.delay D.rejected(6), 11                                            
    ]
    steps = D.parallel promises
    steps.fail ( errors )->
        test.ok errors.length > 0, 'failed with error'
        test.done()
    steps.done ()-> test.done()

analyze "D.reduce() should use a reductor function to manipulate results", (test)->
    test.expect(1)
    reductor = (values,value)->
        return if values then values+value else value
    promises = [
            D.delay D.resolved(10), 333
            D.delay D.resolved(20), 111
            D.delay D.resolved(30), 666            
    ]
    steps = D.reduce( promises, reductor )
    steps.done (total)->
        test.ok total, 60 , 'reductor function is applied'
        test.done()
    steps.fail ()-> test.done()

analyze "D.reduce() should fail if reductor throws", (test)->
    test.expect(1)
    reductor = (values,value)->
        throw "error"
    promises = [
            D.delay D.resolved(10), 333
            D.delay D.resolved(20), 111
            D.delay D.resolved(30), 666            
    ]
    steps = D.reduce( promises, reductor )
    steps.fail ()->
        test.ok true , 'threw when reductor threw'
        test.done()
    steps.done ()->
        test.done()
        
analyze "D.reduce() should fail on errors", (test)->
    test.expect(1)
    promises = [
            D.delay D.resolved(10), 333
            D.delay D.rejected(20), 111
            D.delay D.resolved(30), 666            
    ]
    steps = D.reduce( promises )
    steps.fail ()->
        test.ok true , 'failed on errors'
        test.done()
    steps.done ()->
        test.done()

analyze "D.deep() should accept any argument", (test)->
    test.expect(11)
    fn = ()->
    tests = [
        D.deep( true ).then (truth)->
            test.ok truth, 'a boolean'
        , 
        D.deep( 'string' ).then (value)->
            test.equal value, 'string', 'a string'
        , ()-> test.done()
        D.deep( [] ).then (value)->
            test.deepEqual value, [], 'an empty array'
        , ()-> test.done()
        D.deep( {} ).then (value)->
            test.deepEqual value, {}, 'an empty object'
        , ()-> test.done()
        D.deep( 123 ).then (value)->
            test.equal value, 123, 'an number'
        , ()-> test.done()
        D.deep( fn ).then (value)->
            test.deepEqual value, fn , 'an function (see: D.negociate)'
        , ()-> test.done()   
        D.deep(  ).then (value)->
            udef = typeof value is 'undefined'
            test.ok udef , 'an undefined'
        , ()-> test.done()   
        D.deep( null ).then (value)->
            test.equal value , null, 'a null value'
        , ()-> test.done()
        D.deep( Infinity ).then (value)->
            test.equal value , Infinity, 'Infinity'
        , ()-> test.done()
        D.deep( D.resolved(true) ).then (value)->
            test.ok value , 'a promise'
        , ()-> test.done()
        D.deep( new Error() ).then (value)->
            test.ok value , 'an error'
        , ()-> test.done()
        
    ]
    D.through( tests ).always ()-> test.done()
    
analyze "D.deep() should resolve everything resolvable (functions: see D.negociate)", (test)->
    test.expect( 1 )
    expected  = 
        wasresolved: 123456
        wasnotresolved: 654321
        deeper: [ 1, 'b', {c: 'C'}]
        bunch: [ '1','2','3','4','5','6','7','8' ]
    toresolve = 
        wasresolved: 123456
        wasnotresolved: D.delay( D.resolved(654321), 100 )
        deeper: [
            1
            'b'
            { c: D.delay( D.resolved('C'), 100 ) }
        ]
        bunch: [
            D.delay( D.resolved('1'), 333 )
            D.delay( D.resolved('2'), 777 )
            D.delay( D.resolved('3'), 555 )
            D.delay( D.resolved('4'), 666 )
            D.delay( D.resolved('5'), 111 )
            D.delay( D.resolved('6'), 999 )
            D.delay( D.resolved('7'), 222 )
            D.delay( D.resolved('8'), 444 )
        ]
    D.deep( toresolve ).then (value)->
        test.deepEqual value, expected, 'object is fully resolved'
        test.done()
    , ()-> test.done()
    
analyze "D.deep() should fail when something is not resolvable", (test)->
    test.expect( 1 )
    toresolve = 
        wasresolved: 123456
        wasnotresolved: D.delay( D.resolved(654321), 100 )
        deeper: [
            1
            'b'
            { c: D.delay( D.resolved('C'), 100 ) }
        ]
        bunch: [
            D.delay( D.resolved('1'), 1000 )
            D.delay( D.resolved('2'), 1000 )
            D.delay( D.rejected('3'), 1000 )
            D.delay( D.resolved('4'), 1000 )
            D.delay( D.resolved('5'), 1000 )
            D.delay( D.resolved('6'), 1000 )
            D.delay( D.resolved('7'), 1000 )
            D.delay( D.resolved('8'), 1000 )
        ]
    D.deep( toresolve ).then (value)->
        test.done()
    , ()-> 
        test.ok true, 'failed because of a rejection'
        test.done()
        
analyze "D.deep() should execute and resolve negociators and leave functions intact", (test)->
    test.expect(1)
    fn = ()->
    toresolve = {
        fn: fn
        nego: D.negociate ()-> D.resolved( 'negociated' )
    }
    expected = {
        fn: fn
        nego: 'negociated'
    }
    step = D.deep( toresolve )
    step.done (value)->
        test.deepEqual value, expected, 'negociators are resolved and functions left intact'
        test.done()
    step.fail ()-> test.done()

analyze "Assumes that jquery promises work the same as D promises", (test)->
    test.expect(1)
    jp = $.Deferred()
    jp.done ()->
        test.ok true, 'jquery promises seem to work OK'
        test.done()
    jp.fail ()-> test.done()
    jp.resolveWith null, [ true ]
