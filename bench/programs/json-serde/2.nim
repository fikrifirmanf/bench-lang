# JSON round trip with std/json: parse, serialize exactly as Python's json.dumps(separators=(',', ':')) does
# (ASCII-only escapes, shortest round-trip floats), print the MD5. 1.nim hashes pretty-printed text instead.
import os, strutils, json, tables, unicode
import checksums/md5

# Python's repr(float): shortest round-trip digits (Nim's `$` gives those), positional for 1e-4 <= |x| < 1e16.
proc addPyFloat(output: var string, x: float) =
  var s = $abs(x)
  var mantissa = s
  var exponent = 0
  let e = s.find('e')
  if e >= 0:
    mantissa = s[0 ..< e]
    exponent = parseInt(s[e + 1 .. ^1])
  let dot = mantissa.find('.')
  var digits = if dot >= 0: mantissa[0 ..< dot] & mantissa[dot + 1 .. ^1] else: mantissa
  exponent += (if dot >= 0: dot else: mantissa.len) - 1
  var lead = 0
  while lead < digits.len - 1 and digits[lead] == '0':
    inc lead
    dec exponent
  digits = digits[lead .. ^1]
  while digits.len > 1 and digits[^1] == '0': digits.setLen(digits.len - 1)

  if x < 0 or (x == 0 and 1 / x < 0): output.add('-')
  if exponent >= -4 and exponent < 16:
    if exponent < 0:
      output.add("0." & repeat('0', -exponent - 1) & digits)
    elif digits.len > exponent + 1:
      output.add(digits[0 .. exponent] & "." & digits[exponent + 1 .. ^1])
    else:
      output.add(digits & repeat('0', exponent + 1 - digits.len) & ".0")
  else:
    output.add(digits[0])
    if digits.len > 1: output.add("." & digits[1 .. ^1])
    output.add((if exponent < 0: "e-" else: "e+") & align($abs(exponent), 2, '0'))

proc addJsonString(output: var string, s: string) =
  output.add('"')
  for rune in s.runes:
    let cp = int(rune)
    case cp
    of int('"'): output.add("\\\"")
    of int('\\'): output.add("\\\\")
    of int('\n'): output.add("\\n")
    of int('\r'): output.add("\\r")
    of int('\t'): output.add("\\t")
    of 8: output.add("\\b")
    of 12: output.add("\\f")
    else:
      if cp < 0x20 or (cp >= 0x80 and cp < 0x10000):
        output.add("\\u" & toHex(cp, 4).toLowerAscii)
      elif cp >= 0x10000:
        let v = cp - 0x10000
        output.add("\\u" & toHex(0xd800 + (v shr 10), 4).toLowerAscii & "\\u" & toHex(0xdc00 + (v and 0x3ff), 4).toLowerAscii)
      else:
        output.add(char(cp))
  output.add('"')

proc dump(output: var string, node: JsonNode) =
  case node.kind
  of JNull: output.add("null")
  of JBool: output.add(if node.bval: "true" else: "false")
  of JInt: output.add($node.num)
  of JFloat: output.addPyFloat(node.fnum)
  of JString: output.addJsonString(node.str)
  of JArray:
    output.add('[')
    for i, item in node.elems:
      if i > 0: output.add(',')
      output.dump(item)
    output.add(']')
  of JObject:
    output.add('{')
    var first = true
    for key, value in node.fields:
      if not first: output.add(',')
      first = false
      output.addJsonString(key)
      output.add(':')
      output.dump(value)
    output.add('}')

proc printHash(node: JsonNode) =
  var text = newStringOfCap(1 shl 20)
  text.dump(node)
  echo getMD5(text)

let fileName = if paramCount() > 0: paramStr(1) else: "sample"
let n = if paramCount() > 1: parseInt(paramStr(2)) else: 3
var jsonStr = readFile(fileName & ".json")
if jsonStr.startsWith("\xef\xbb\xbf"): jsonStr = jsonStr[3 .. ^1]
printHash(parseJson(jsonStr))
var array = newJArray()
for i in 0 ..< n: array.add(parseJson(jsonStr))
printHash(array)
