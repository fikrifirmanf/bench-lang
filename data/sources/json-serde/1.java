// JSON round trip with a hand-written parser (the JDK has none): parse into maps and lists, serialize exactly as
// Python's json.dumps(separators=(',', ':')) does (ASCII-only escapes, shortest round-trip floats), print the MD5.
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

final class app {
  static final class Parser {
    private final String s;
    private int i;

    Parser(String s) {
      this.s = s;
    }

    Object parse() {
      skipSpace();
      char c = s.charAt(i);
      switch (c) {
        case '{': return parseObject();
        case '[': return parseArray();
        case '"': return parseString();
        case 't': i += 4; return Boolean.TRUE;
        case 'f': i += 5; return Boolean.FALSE;
        case 'n': i += 4; return null;
        default: return parseNumber();
      }
    }

    private void skipSpace() {
      while (i < s.length()) {
        char c = s.charAt(i);
        if (c != ' ' && c != '\n' && c != '\r' && c != '\t') return;
        i++;
      }
    }

    private Map<String, Object> parseObject() {
      var map = new LinkedHashMap<String, Object>();
      i++;
      skipSpace();
      if (s.charAt(i) == '}') {
        i++;
        return map;
      }
      for (;;) {
        skipSpace();
        String key = parseString();
        skipSpace();
        i++; // ':'
        map.put(key, parse());
        skipSpace();
        if (s.charAt(i++) == '}') return map;
      }
    }

    private List<Object> parseArray() {
      var list = new ArrayList<Object>();
      i++;
      skipSpace();
      if (s.charAt(i) == ']') {
        i++;
        return list;
      }
      for (;;) {
        list.add(parse());
        skipSpace();
        if (s.charAt(i++) == ']') return list;
      }
    }

    private String parseString() {
      int start = ++i;
      while (s.charAt(i) != '"' && s.charAt(i) != '\\') i++;
      if (s.charAt(i) == '"') return s.substring(start, i++);
      var sb = new StringBuilder(s.substring(start, i));
      while (s.charAt(i) != '"') {
        char c = s.charAt(i++);
        if (c != '\\') {
          sb.append(c);
          continue;
        }
        char e = s.charAt(i++);
        switch (e) {
          case 'b': sb.append('\b'); break;
          case 'f': sb.append('\f'); break;
          case 'n': sb.append('\n'); break;
          case 'r': sb.append('\r'); break;
          case 't': sb.append('\t'); break;
          case 'u': sb.append((char) Integer.parseInt(s.substring(i, i + 4), 16)); i += 4; break;
          default: sb.append(e);
        }
      }
      i++;
      return sb.toString();
    }

    private Object parseNumber() {
      int start = i;
      boolean isFloat = false;
      while (i < s.length()) {
        char c = s.charAt(i);
        if (c == '.' || c == 'e' || c == 'E') isFloat = true;
        else if (!(c == '-' || c == '+' || (c >= '0' && c <= '9'))) break;
        i++;
      }
      String text = s.substring(start, i);
      return isFloat ? (Object) Double.parseDouble(text) : (Object) Long.parseLong(text);
    }
  }

  // Python's repr(float). Double.toString gives the shortest round-trip digits (JDK 19+) in its own layout.
  static void dumpDouble(StringBuilder out, double d) {
    String t = Double.toString(Math.abs(d));
    int e = t.indexOf('E');
    String mantissa = e < 0 ? t : t.substring(0, e);
    int exponent = e < 0 ? 0 : Integer.parseInt(t.substring(e + 1));
    int dot = mantissa.indexOf('.');
    String digits = mantissa.substring(0, dot) + mantissa.substring(dot + 1);
    exponent += dot - 1;
    int lead = 0;
    while (lead < digits.length() - 1 && digits.charAt(lead) == '0') {
      lead++;
      exponent--;
    }
    digits = digits.substring(lead);
    int end = digits.length();
    while (end > 1 && digits.charAt(end - 1) == '0') end--;
    digits = digits.substring(0, end);

    if (d < 0 || (d == 0 && 1 / d < 0)) out.append('-');
    if (exponent >= -4 && exponent < 16) {
      if (exponent < 0) {
        out.append("0.").append("0".repeat(-exponent - 1)).append(digits);
      } else if (digits.length() > exponent + 1) {
        out.append(digits, 0, exponent + 1).append('.').append(digits, exponent + 1, digits.length());
      } else {
        out.append(digits).append("0".repeat(exponent + 1 - digits.length())).append(".0");
      }
    } else {
      out.append(digits.charAt(0));
      if (digits.length() > 1) out.append('.').append(digits, 1, digits.length());
      out.append('e').append(exponent < 0 ? '-' : '+');
      if (Math.abs(exponent) < 10) out.append('0');
      out.append(Math.abs(exponent));
    }
  }

  static void dumpString(StringBuilder out, String s) {
    out.append('"');
    for (int i = 0; i < s.length(); i++) {
      char c = s.charAt(i);
      switch (c) {
        case '"': out.append("\\\""); break;
        case '\\': out.append("\\\\"); break;
        case '\n': out.append("\\n"); break;
        case '\r': out.append("\\r"); break;
        case '\t': out.append("\\t"); break;
        case '\b': out.append("\\b"); break;
        case '\f': out.append("\\f"); break;
        default:
          // Java strings are UTF-16 already, so surrogate pairs come out as Python writes them.
          if (c < 0x20 || c >= 0x80) out.append(String.format("\\u%04x", (int) c));
          else out.append(c);
      }
    }
    out.append('"');
  }

  @SuppressWarnings("unchecked")
  static void dump(StringBuilder out, Object v) {
    if (v == null) {
      out.append("null");
    } else if (v instanceof Boolean b) {
      out.append(b ? "true" : "false");
    } else if (v instanceof Long l) {
      out.append(l);
    } else if (v instanceof Double d) {
      dumpDouble(out, d);
    } else if (v instanceof String s) {
      dumpString(out, s);
    } else if (v instanceof List<?> list) {
      out.append('[');
      for (int i = 0; i < list.size(); i++) {
        if (i > 0) out.append(',');
        dump(out, list.get(i));
      }
      out.append(']');
    } else {
      out.append('{');
      boolean first = true;
      for (var entry : ((Map<String, Object>) v).entrySet()) {
        if (!first) out.append(',');
        first = false;
        dumpString(out, entry.getKey());
        out.append(':');
        dump(out, entry.getValue());
      }
      out.append('}');
    }
  }

  static void printHash(Object v) throws Exception {
    var out = new StringBuilder();
    dump(out, v);
    var md5 = MessageDigest.getInstance("MD5");
    System.out.println(HexFormat.of().formatHex(md5.digest(out.toString().getBytes(StandardCharsets.UTF_8))));
  }

  public static void main(String[] args) throws Exception {
    String fileName = args.length > 0 ? args[0] : "sample";
    int n = args.length > 1 ? Integer.parseInt(args[1]) : 3;
    String json = Files.readString(Path.of(fileName + ".json"));
    if (json.startsWith("﻿")) json = json.substring(1);
    printHash(new Parser(json).parse());
    var array = new ArrayList<Object>(n);
    for (int i = 0; i < n; i++) array.add(new Parser(json).parse());
    printHash(array);
  }
}
