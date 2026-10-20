# Single-threaded fannkuch-redux on fixed-size arrays.
import os, strutils, algorithm

proc fannkuch(n: int): (int, int) =
  var perm, perm1, count: array[32, int]
  for i in 0 ..< n: perm1[i] = i
  var maxFlips, checksum, permCount = 0
  var r = n
  while true:
    while r != 1:
      count[r - 1] = r
      dec r
    perm = perm1
    var flips = 0
    var k = perm[0]
    while k != 0:
      reverse(perm, 0, k)
      inc flips
      k = perm[0]
    maxFlips = max(maxFlips, flips)
    checksum += (if permCount mod 2 == 0: flips else: -flips)
    while true:
      if r == n:
        return (checksum, maxFlips)
      let first = perm1[0]
      for i in 0 ..< r: perm1[i] = perm1[i + 1]
      perm1[r] = first
      dec count[r]
      if count[r] > 0: break
      inc r
    inc permCount

let n = if paramCount() > 0: parseInt(paramStr(1)) else: 7
let (checksum, maxFlips) = fannkuch(n)
echo checksum, "\nPfannkuchen(", n, ") = ", maxFlips
