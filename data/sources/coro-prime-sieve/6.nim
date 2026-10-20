import yasync
import chronos
import std/os
import std/strutils


##
## Channel implementation copied from the `yasync` repo, testcase `test7.nim`
##

type
  Channel[T] = object
    waitingCont: ptr Cont[T]
    sendingCont: ptr Cont[void]
    val: T

proc send[T](c: var Channel[T], v: T, env: ptr Cont[void]) {.asyncRaw.} =
  doAssert(c.sendingCont == nil, "Too many senders")
  if c.waitingCont == nil:
    c.val = v
    c.sendingCont = env
  else:
    let cont = c.waitingCont
    c.waitingCont = nil
    cont.complete(v)
    env.complete()

proc recv[T](c: var Channel[T], env: ptr Cont[T]) {.asyncRaw.} =
  doAssert(c.waitingCont == nil, "Too many receivers")
  if c.sendingCont == nil:
    c.waitingCont = env
  else:
    let cont = c.sendingCont
    c.sendingCont = nil
    env.complete(c.val)
    cont.complete()

proc newChannel[T](): ref Channel[T] =
  new(result)


##
## # Benchmark
##
## Below, "Concurrent Prime Sieve" that matches Go reference implementation.
##
##   [X] Uses coroutines.
##   [X] Uses a coroutine scheduler.
##   [X] Uses an async channel for communitating between coroutines.
##   [X] Same 3 functions, structured like the reference.
##

proc generate(chan: ref Channel[int]) {.yasync.async.} =
  ## Send the sequence 2, 3, 4, ... to cannel `chan`.
  for i in 2 .. int.high:
    await chan[].send(i)

proc filter(inChan, outChan: ref Channel[int], prime: int) {.yasync.async.} =
  ## Copy the values from channel `inChan` to channel `outChan`, removing those
  ## divisible by `prime`.
  while true:
    let i = await inChan[].recv() # revieve value from `inChan`
    if i mod prime != 0:
      await outChan[].send(i) # send `i` to `outChan`

proc main(n: int) {.yasync.async.} =
  ## The prime sieve: Daisy-chain filter processes.
  var firstChan = newChannel[int]() # craete a new channel
  discard generate(firstChan) # launch generate coroutine
  for i in 0 ..< n:
    let prime = await firstChan[].recv()
    echo prime
    var secondChan = newChannel[int]()
    discard filter(firstChan, secondChan, prime)
    firstChan = secondChan

when isMainModule:

  let n = if paramCount() > 0: parseInt(paramStr(1)) else: 100
  var env: asyncCallEnvType(main(n))
  asyncLaunchWithEnv(env, main(n))


