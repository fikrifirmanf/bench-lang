// JSON round trip with a std::variant tree: parse, serialize exactly as Python's
// json.dumps(separators=(',', ':')) does (ASCII-only escapes, shortest round-trip floats), print the MD5.
#include <charconv>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iterator>
#include <memory>
#include <string>
#include <string_view>
#include <utility>
#include <variant>
#include <vector>

#include "md5.h"

struct Value;
using Array = std::vector<Value>;
using Object = std::vector<std::pair<std::string, Value>>;
struct Null {};

struct Value {
    std::variant<Null, bool, long long, double, std::string, std::unique_ptr<Array>, std::unique_ptr<Object>> data;
};

class Parser {
  public:
    explicit Parser(std::string_view text) : p_(text.data()) {}

    Value parse() {
        skip_space();
        switch (*p_) {
            case '{': return {std::make_unique<Object>(parse_object())};
            case '[': return {std::make_unique<Array>(parse_array())};
            case '"': return {parse_string()};
            case 't': p_ += 4; return {true};
            case 'f': p_ += 5; return {false};
            case 'n': p_ += 4; return {Null{}};
            default: return parse_number();
        }
    }

  private:
    void skip_space() {
        while (*p_ == ' ' || *p_ == '\n' || *p_ == '\r' || *p_ == '\t') p_++;
    }

    Array parse_array() {
        Array items;
        p_++;
        skip_space();
        if (*p_ == ']') {
            p_++;
            return items;
        }
        for (;;) {
            items.push_back(parse());
            skip_space();
            if (*p_++ == ']') return items;
        }
    }

    Object parse_object() {
        Object members;
        p_++;
        skip_space();
        if (*p_ == '}') {
            p_++;
            return members;
        }
        for (;;) {
            skip_space();
            std::string key = parse_string();
            skip_space();
            p_++;  // ':'
            members.emplace_back(std::move(key), parse());
            skip_space();
            if (*p_++ == '}') return members;
        }
    }

    static unsigned hex4(const char *p) {
        unsigned v = 0;
        std::from_chars(p, p + 4, v, 16);
        return v;
    }

    static void put_utf8(std::string &out, unsigned cp) {
        if (cp < 0x80) {
            out += static_cast<char>(cp);
        } else if (cp < 0x800) {
            out += static_cast<char>(0xc0 | cp >> 6);
            out += static_cast<char>(0x80 | (cp & 0x3f));
        } else if (cp < 0x10000) {
            out += static_cast<char>(0xe0 | cp >> 12);
            out += static_cast<char>(0x80 | ((cp >> 6) & 0x3f));
            out += static_cast<char>(0x80 | (cp & 0x3f));
        } else {
            out += static_cast<char>(0xf0 | cp >> 18);
            out += static_cast<char>(0x80 | ((cp >> 12) & 0x3f));
            out += static_cast<char>(0x80 | ((cp >> 6) & 0x3f));
            out += static_cast<char>(0x80 | (cp & 0x3f));
        }
    }

    std::string parse_string() {
        std::string out;
        for (p_++; *p_ != '"';) {
            if (*p_ != '\\') {
                out += *p_++;
                continue;
            }
            char c = p_[1];
            p_ += 2;
            switch (c) {
                case 'b': out += '\b'; break;
                case 'f': out += '\f'; break;
                case 'n': out += '\n'; break;
                case 'r': out += '\r'; break;
                case 't': out += '\t'; break;
                case 'u': {
                    unsigned cp = hex4(p_);
                    p_ += 4;
                    if (cp >= 0xd800 && cp < 0xdc00 && p_[0] == '\\' && p_[1] == 'u') {
                        unsigned low = hex4(p_ + 2);
                        if (low >= 0xdc00 && low < 0xe000) {
                            cp = 0x10000 + ((cp - 0xd800) << 10) + (low - 0xdc00);
                            p_ += 6;
                        }
                    }
                    put_utf8(out, cp);
                    break;
                }
                default: out += c;
            }
        }
        p_++;
        return out;
    }

    Value parse_number() {
        const char *start = p_;
        bool is_float = false;
        if (*p_ == '-') p_++;
        while ((*p_ >= '0' && *p_ <= '9') || *p_ == '.' || *p_ == 'e' || *p_ == 'E' || *p_ == '+' || *p_ == '-') {
            if (*p_ == '.' || *p_ == 'e' || *p_ == 'E') is_float = true;
            p_++;
        }
        if (is_float) {
            double d;
            std::from_chars(start, p_, d);
            return {d};
        }
        long long i;
        std::from_chars(start, p_, i);
        return {i};
    }

    const char *p_;
};

// Python's repr(float): shortest round-trip digits, positional for 1e-4 <= |x| < 1e16.
static void dump_float(std::string &out, double x) {
    char buf[64];
    auto [end, ec] = std::to_chars(buf, buf + sizeof buf, x, std::chars_format::scientific);
    std::string_view sci(buf, static_cast<size_t>(end - buf));
    bool negative = sci.front() == '-';
    if (negative) sci.remove_prefix(1);
    size_t e = sci.find('e');
    std::string digits;
    for (char c : sci.substr(0, e))
        if (c != '.') digits += c;
    int exponent = std::atoi(std::string(sci.substr(e + 1)).c_str());

    if (negative) out += '-';
    if (exponent >= -4 && exponent < 16) {
        if (exponent < 0) {
            out += "0.";
            out.append(static_cast<size_t>(-exponent - 1), '0');
            out += digits;
        } else if (static_cast<int>(digits.size()) > exponent + 1) {
            out.append(digits, 0, static_cast<size_t>(exponent) + 1);
            out += '.';
            out.append(digits, static_cast<size_t>(exponent) + 1, std::string::npos);
        } else {
            out += digits;
            out.append(static_cast<size_t>(exponent + 1) - digits.size(), '0');
            out += ".0";
        }
    } else {
        out += digits[0];
        if (digits.size() > 1) {
            out += '.';
            out.append(digits, 1, std::string::npos);
        }
        std::snprintf(buf, sizeof buf, "e%c%02d", exponent < 0 ? '-' : '+', std::abs(exponent));
        out += buf;
    }
}

static void dump_string(std::string &out, const std::string &s) {
    char buf[16];
    out += '"';
    for (size_t i = 0; i < s.size();) {
        auto c = static_cast<unsigned char>(s[i]);
        if (c >= 0x80) {
            // Python escapes every non-ASCII character as \uXXXX (UTF-16 surrogate pairs above U+FFFF).
            int extra = c >= 0xf0 ? 3 : c >= 0xe0 ? 2 : 1;
            unsigned cp = c & (0x3f >> extra);
            for (int k = 1; k <= extra; k++) cp = cp << 6 | (static_cast<unsigned char>(s[i + k]) & 0x3f);
            i += static_cast<size_t>(extra) + 1;
            if (cp >= 0x10000) {
                cp -= 0x10000;
                std::snprintf(buf, sizeof buf, "\\u%04x\\u%04x", 0xd800 + (cp >> 10), 0xdc00 + (cp & 0x3ff));
            } else {
                std::snprintf(buf, sizeof buf, "\\u%04x", cp);
            }
            out += buf;
            continue;
        }
        i++;
        switch (c) {
            case '"': out += "\\\""; break;
            case '\\': out += "\\\\"; break;
            case '\n': out += "\\n"; break;
            case '\r': out += "\\r"; break;
            case '\t': out += "\\t"; break;
            case '\b': out += "\\b"; break;
            case '\f': out += "\\f"; break;
            default:
                if (c < 0x20) {
                    std::snprintf(buf, sizeof buf, "\\u%04x", c);
                    out += buf;
                } else {
                    out += static_cast<char>(c);
                }
        }
    }
    out += '"';
}

template <class... Fs>
struct Overloaded : Fs... {
    using Fs::operator()...;
};

static void dump(std::string &out, const Value &v) {
    std::visit(Overloaded{
                   [&](Null) { out += "null"; },
                   [&](bool b) { out += b ? "true" : "false"; },
                   [&](long long i) { out += std::to_string(i); },
                   [&](double d) { dump_float(out, d); },
                   [&](const std::string &s) { dump_string(out, s); },
                   [&](const std::unique_ptr<Array> &a) {
                       out += '[';
                       for (size_t i = 0; i < a->size(); i++) {
                           if (i) out += ',';
                           dump(out, (*a)[i]);
                       }
                       out += ']';
                   },
                   [&](const std::unique_ptr<Object> &o) {
                       out += '{';
                       for (size_t i = 0; i < o->size(); i++) {
                           if (i) out += ',';
                           dump_string(out, (*o)[i].first);
                           out += ':';
                           dump(out, (*o)[i].second);
                       }
                       out += '}';
                   },
               },
               v.data);
}

static void print_hash(const std::string &text) {
    uint8_t digest[16];
    md5(text.data(), text.size(), digest);
    for (uint8_t byte : digest) std::printf("%02x", byte);
    std::printf("\n");
}

int main(int argc, char **argv) {
    std::string name = argc > 1 ? argv[1] : "sample";
    int n = argc > 2 ? std::atoi(argv[2]) : 3;
    std::ifstream file(name + ".json", std::ios::binary);
    std::string text((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    std::string_view json(text);
    if (json.starts_with("\xef\xbb\xbf")) json.remove_prefix(3);

    std::string out;
    dump(out, Parser(json).parse());
    print_hash(out);

    auto array = std::make_unique<Array>();
    for (int i = 0; i < n; i++) array->push_back(Parser(json).parse());
    out.clear();
    dump(out, Value{std::move(array)});
    print_hash(out);
}
