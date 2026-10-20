import chronos
import std/os
import std/strutils







proc generate(chan: AsyncQueue[int]) {.async.} =
  ## Send the sequence 2, 3, 4, ... to cannel `chan`.
  for i in 2 .. int.high:
    await chan.addFirst(i)


proc filter(inChan, outChan: AsyncQueue[int], prime: int) {.async.} =
  ## Copy the values from channel `inChan` to channel `outChan`, removing those
  ## divisible by `prime`.
  while true:
    let i = await inChan.popLast() # revieve value from `inChan`
    if i mod prime != 0:
      await outChan.addFirst(i) # send `i` to `outChan`


proc main(n: int) {.async.} =
  ## The prime sieve: Daisy-chain filter processes.
  var firstChan = newAsyncQueue[int](1) # craete a new channel
  asyncCheck generate(firstChan) # launch generate coroutine
  for i in 0 ..< n:
    let prime = await firstChan.popLast()
    echo prime
    var secondChan = newAsyncQueue[int](1)
    asyncCheck filter(firstChan, secondChan, prime)
    firstChan = secondChan


when isMainModule:

  let n = if paramCount() > 0: parseInt(paramStr(1)) else: 100
  waitFor main(n)


