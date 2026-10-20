# k-nucleotide: counts every k-mer of the THREE sequence in a Table keyed by 2-bit packed codes.
import os, strutils, strformat, tables, algorithm

proc codeOf(c: char): uint64 =
  case c
  of 'A': 0
  of 'C': 1
  of 'G': 2
  else: 3

proc countKmers(seq: seq[uint8], k: int): CountTable[uint64] =
  result = initCountTable[uint64]()
  let mask = (1'u64 shl (2 * k)) - 1
  var key = 0'u64
  for i, c in seq:
    key = ((key shl 2) or c.uint64) and mask
    if i + 1 >= k: result.inc(key)

proc unpack(key: uint64, k: int): string =
  result = newString(k)
  var rest = key
  for i in countdown(k - 1, 0):
    result[i] = "ACGT"[int(rest and 3)]
    rest = rest shr 2

let fileName = if paramCount() > 0: paramStr(1) else: "25000_in"
var text = ""
var inThree = false
for line in lines(fileName):
  if inThree:
    if line.startsWith('>'): break
    text.add(line.strip.toUpperAscii)
  elif line.startsWith(">THREE"):
    inThree = true
var sequence = newSeq[uint8](text.len)
for i, c in text: sequence[i] = codeOf(c).uint8

var output = ""
for k in 1 .. 2:
  let total = float(sequence.len - k + 1)
  var sorted: seq[(string, int)]
  for key, count in countKmers(sequence, k): sorted.add((unpack(key, k), count))
  sorted.sort(proc (a, b: (string, int)): int =
    if a[1] != b[1]: cmp(b[1], a[1]) else: cmp(a[0], b[0]))
  for (kmer, count) in sorted:
    output.add(&"{kmer} {count.float * 100.0 / total:.3f}\n")
  output.add("\n")
for kmer in ["GGT", "GGTA", "GGTATT", "GGTATTTTAATT", "GGTATTTTAATTTATAGT"]:
  var key = 0'u64
  for c in kmer: key = (key shl 2) or codeOf(c)
  output.add(&"{countKmers(sequence, kmer.len)[key]}\t{kmer}\n")
stdout.write(output)
