import std/asyncdispatch
import std/os
import std/strutils



##
## # Channel[T]
##
## As far as I know Nim's asyncdispatch has many features but lacks an awaitable
## channel type. It uses Futures as the work horse of async communication instead.
##
## I craeted a very simple async-awaitable channel type so I can match the
## reference Go implementation this benchmark originated from.
##

type Channel[T] = object
  ## An simple one-item, async-awaitable Channel.
  untilIsEmpty: Future[void]
  untilIsFull: Future[void]
  val: T


proc newChannel[T](): ref Channel[T] =
  ## Initializer. Allocate a new ref Channel object on the heap.
  result = new Channel[T]
  result[].untilIsEmpty = newFuture[void]()
  result[].untilIsFull = newFuture[void]()
  result[].untilIsEmpty.complete()


proc send[T](chan: ref Channel[T], val: T) {.async.} =
  # Accept val if empty, otherwise, suspend until empty.
  await chan[].untilIsEmpty
  chan[].untilIsEmpty = newFuture[void]()
  chan[].val = val
  chan[].untilIsFull.complete()


proc recv[T](chan: ref Channel[T]): Future[T] {.async.} =
  # Return held val if full, otherwise, suspend until full.
  await chan[].untilIsFull
  chan[].untilIsFull = newFuture[void]()
  result = chan[].val
  chan[].untilIsEmpty.complete()



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


proc generate(chan: ref Channel[int]) {.async.} =
  ## Send the sequence 2, 3, 4, ... to cannel `chan`.
  for i in 2 .. int.high:
    await chan.send(i)


proc filter(inChan, outChan: ref Channel[int], prime: int) {.async.} =
  ## Copy the values from channel `inChan` to channel `outChan`, removing those
  ## divisible by `prime`.
  while true:
    let i = await inChan.recv() # revieve value from `inChan`
    if i mod prime != 0:
      await outChan.send(i) # send `i` to `outChan`


proc main(n: int) {.async.} =
  ## The prime sieve: Daisy-chain filter processes.
  var firstChan = newChannel[int]() # craete a new channel
  asyncCheck generate(firstChan) # launch generate coroutine
  for i in 0 ..< n:
    let prime = await firstChan.recv()
    echo prime
    var secondChan = newChannel[int]()
    asyncCheck filter(firstChan, secondChan, prime)
    firstChan = secondChan


when isMainModule:

  let n = if paramCount() > 0: parseInt(paramStr(1)) else: 100
  waitFor main(n)


