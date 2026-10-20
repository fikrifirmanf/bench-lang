// JSON round trip: parse into a tree, serialize compactly exactly as Python's json.dumps(separators=(',', ':'))
// does (ASCII-only escapes, shortest round-trip floats), and print the MD5 of the text.
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "md5.h"

typedef enum { J_NULL, J_FALSE, J_TRUE, J_INT, J_FLOAT, J_STRING, J_ARRAY, J_OBJECT } Kind;

typedef struct Value Value;
struct Value {
    Kind kind;
    union {
        long long integer;
        double number;
        struct {
            char *chars;  // decoded UTF-8
            size_t length;
        } string;
        struct {
            Value *items;  // objects store key, value, key, value, ...
            size_t count;
        } list;
    };
};

typedef struct {
    const char *p;
} Parser;

static void skip_space(Parser *ps) {
    while (*ps->p == ' ' || *ps->p == '\n' || *ps->p == '\r' || *ps->p == '\t') ps->p++;
}

static unsigned hex4(const char *p) {
    unsigned v = 0;
    for (int i = 0; i < 4; i++) {
        char c = p[i];
        v = v * 16 + (unsigned)(c <= '9' ? c - '0' : (c | 0x20) - 'a' + 10);
    }
    return v;
}

static size_t put_utf8(char *out, unsigned cp) {
    if (cp < 0x80) {
        out[0] = (char)cp;
        return 1;
    }
    if (cp < 0x800) {
        out[0] = (char)(0xc0 | cp >> 6);
        out[1] = (char)(0x80 | (cp & 0x3f));
        return 2;
    }
    if (cp < 0x10000) {
        out[0] = (char)(0xe0 | cp >> 12);
        out[1] = (char)(0x80 | ((cp >> 6) & 0x3f));
        out[2] = (char)(0x80 | (cp & 0x3f));
        return 3;
    }
    out[0] = (char)(0xf0 | cp >> 18);
    out[1] = (char)(0x80 | ((cp >> 12) & 0x3f));
    out[2] = (char)(0x80 | ((cp >> 6) & 0x3f));
    out[3] = (char)(0x80 | (cp & 0x3f));
    return 4;
}

static void parse_string(Parser *ps, Value *v) {
    const char *start = ++ps->p;
    const char *end = start;
    while (*end != '"') end += *end == '\\' ? 2 : 1;
    char *out = malloc((size_t)(end - start) + 1);
    size_t n = 0;
    for (const char *p = start; p < end;) {
        if (*p != '\\') {
            out[n++] = *p++;
            continue;
        }
        char c = p[1];
        p += 2;
        switch (c) {
            case 'b': out[n++] = '\b'; break;
            case 'f': out[n++] = '\f'; break;
            case 'n': out[n++] = '\n'; break;
            case 'r': out[n++] = '\r'; break;
            case 't': out[n++] = '\t'; break;
            case 'u': {
                unsigned cp = hex4(p);
                p += 4;
                if (cp >= 0xd800 && cp < 0xdc00 && p[0] == '\\' && p[1] == 'u') {
                    unsigned low = hex4(p + 2);
                    if (low >= 0xdc00 && low < 0xe000) {
                        cp = 0x10000 + ((cp - 0xd800) << 10) + (low - 0xdc00);
                        p += 6;
                    }
                }
                n += put_utf8(out + n, cp);
                break;
            }
            default: out[n++] = c;
        }
    }
    v->kind = J_STRING;
    v->string.chars = out;
    v->string.length = n;
    ps->p = end + 1;
}

static void parse_value(Parser *ps, Value *v);

static void parse_list(Parser *ps, Value *v, char close, bool object) {
    size_t capacity = 8, count = 0;
    Value *items = malloc(sizeof(Value) * capacity);
    ps->p++;
    skip_space(ps);
    if (*ps->p == close) {
        ps->p++;
    } else {
        for (;;) {
            if (count + 2 > capacity) {
                capacity *= 2;
                items = realloc(items, sizeof(Value) * capacity);
            }
            skip_space(ps);
            if (object) {
                parse_string(ps, &items[count++]);
                skip_space(ps);
                ps->p++;  // ':'
            }
            parse_value(ps, &items[count++]);
            skip_space(ps);
            if (*ps->p++ == close) break;  // otherwise ','
        }
    }
    v->kind = object ? J_OBJECT : J_ARRAY;
    v->list.items = items;
    v->list.count = count;
}

static void parse_number(Parser *ps, Value *v) {
    const char *p = ps->p;
    bool is_float = false;
    const char *q = p;
    if (*q == '-') q++;
    while ((*q >= '0' && *q <= '9') || *q == '.' || *q == 'e' || *q == 'E' || *q == '+' || *q == '-') {
        if (*q == '.' || *q == 'e' || *q == 'E') is_float = true;
        q++;
    }
    if (is_float) {
        v->kind = J_FLOAT;
        v->number = strtod(p, NULL);
    } else {
        v->kind = J_INT;
        v->integer = strtoll(p, NULL, 10);
    }
    ps->p = q;
}

static void parse_value(Parser *ps, Value *v) {
    skip_space(ps);
    switch (*ps->p) {
        case '{': parse_list(ps, v, '}', true); break;
        case '[': parse_list(ps, v, ']', false); break;
        case '"': parse_string(ps, v); break;
        case 't': v->kind = J_TRUE; ps->p += 4; break;
        case 'f': v->kind = J_FALSE; ps->p += 5; break;
        case 'n': v->kind = J_NULL; ps->p += 4; break;
        default: parse_number(ps, v);
    }
}

static void release(Value *v) {
    if (v->kind == J_STRING) free(v->string.chars);
    if (v->kind == J_ARRAY || v->kind == J_OBJECT) {
        for (size_t i = 0; i < v->list.count; i++) release(&v->list.items[i]);
        free(v->list.items);
    }
}

typedef struct {
    char *data;
    size_t length, capacity;
} Buffer;

static void reserve(Buffer *b, size_t extra) {
    if (b->length + extra <= b->capacity) return;
    while (b->length + extra > b->capacity) b->capacity = b->capacity ? b->capacity * 2 : 1 << 16;
    b->data = realloc(b->data, b->capacity);
}

static void append(Buffer *b, const char *s, size_t n) {
    reserve(b, n);
    memcpy(b->data + b->length, s, n);
    b->length += n;
}

// Python's repr(float): the shortest digits that round-trip, positional for 1e-4 <= |x| < 1e16.
static void append_float(Buffer *b, double x) {
    char tmp[40];
    // Round-tripping is monotonic in the digit count, so binary-search the smallest count in 1..17.
    int low = 1, high = 17;
    while (low < high) {
        int mid = (low + high) / 2;
        snprintf(tmp, sizeof tmp, "%.*e", mid - 1, x);
        if (strtod(tmp, NULL) == x) high = mid; else low = mid + 1;
    }
    snprintf(tmp, sizeof tmp, "%.*e", low - 1, x);
    char digits[24];
    int ndigits = 0;
    const char *p = tmp;
    bool negative = *p == '-';
    if (negative) p++;
    for (; *p != 'e'; p++)
        if (*p != '.') digits[ndigits++] = *p;
    int exponent = atoi(p + 1);
    while (ndigits > 1 && digits[ndigits - 1] == '0') ndigits--;

    char out[64];
    int n = 0;
    if (negative) out[n++] = '-';
    if (exponent >= -4 && exponent < 16) {
        if (exponent < 0) {
            out[n++] = '0';
            out[n++] = '.';
            for (int i = -1; i > exponent; i--) out[n++] = '0';
            for (int i = 0; i < ndigits; i++) out[n++] = digits[i];
        } else {
            for (int i = 0; i <= exponent; i++) out[n++] = i < ndigits ? digits[i] : '0';
            out[n++] = '.';
            if (ndigits > exponent + 1) {
                for (int i = exponent + 1; i < ndigits; i++) out[n++] = digits[i];
            } else {
                out[n++] = '0';
            }
        }
    } else {
        out[n++] = digits[0];
        if (ndigits > 1) {
            out[n++] = '.';
            for (int i = 1; i < ndigits; i++) out[n++] = digits[i];
        }
        n += snprintf(out + n, sizeof out - (size_t)n, "e%c%02d", exponent < 0 ? '-' : '+', abs(exponent));
    }
    append(b, out, (size_t)n);
}

static void append_string(Buffer *b, const char *s, size_t length) {
    reserve(b, length * 6 + 2);
    char *out = b->data + b->length;
    *out++ = '"';
    for (size_t i = 0; i < length;) {
        unsigned char c = (unsigned char)s[i];
        if (c >= 0x80) {
            // Python escapes every non-ASCII character as \uXXXX (UTF-16 surrogate pairs above U+FFFF).
            unsigned cp;
            int extra = c >= 0xf0 ? 3 : c >= 0xe0 ? 2 : 1;
            cp = c & (0x3f >> extra);
            for (int k = 1; k <= extra; k++) cp = cp << 6 | ((unsigned char)s[i + k] & 0x3f);
            i += (size_t)extra + 1;
            if (cp >= 0x10000) {
                cp -= 0x10000;
                out += sprintf(out, "\\u%04x\\u%04x", 0xd800 + (cp >> 10), 0xdc00 + (cp & 0x3ff));
            } else {
                out += sprintf(out, "\\u%04x", cp);
            }
            continue;
        }
        i++;
        switch (c) {
            case '"': *out++ = '\\'; *out++ = '"'; break;
            case '\\': *out++ = '\\'; *out++ = '\\'; break;
            case '\n': *out++ = '\\'; *out++ = 'n'; break;
            case '\r': *out++ = '\\'; *out++ = 'r'; break;
            case '\t': *out++ = '\\'; *out++ = 't'; break;
            case '\b': *out++ = '\\'; *out++ = 'b'; break;
            case '\f': *out++ = '\\'; *out++ = 'f'; break;
            default:
                if (c < 0x20) out += sprintf(out, "\\u%04x", c); else *out++ = (char)c;
        }
    }
    *out++ = '"';
    b->length = (size_t)(out - b->data);
}

static void dump(Buffer *b, const Value *v) {
    char tmp[32];
    switch (v->kind) {
        case J_NULL: append(b, "null", 4); break;
        case J_TRUE: append(b, "true", 4); break;
        case J_FALSE: append(b, "false", 5); break;
        case J_INT: append(b, tmp, (size_t)snprintf(tmp, sizeof tmp, "%lld", v->integer)); break;
        case J_FLOAT: append_float(b, v->number); break;
        case J_STRING: append_string(b, v->string.chars, v->string.length); break;
        case J_ARRAY:
            append(b, "[", 1);
            for (size_t i = 0; i < v->list.count; i++) {
                if (i) append(b, ",", 1);
                dump(b, &v->list.items[i]);
            }
            append(b, "]", 1);
            break;
        case J_OBJECT:
            append(b, "{", 1);
            for (size_t i = 0; i < v->list.count; i += 2) {
                if (i) append(b, ",", 1);
                dump(b, &v->list.items[i]);
                append(b, ":", 1);
                dump(b, &v->list.items[i + 1]);
            }
            append(b, "}", 1);
            break;
    }
}

static void print_hash(const Buffer *b) {
    uint8_t digest[16];
    md5(b->data, b->length, digest);
    for (int i = 0; i < 16; i++) printf("%02x", digest[i]);
    printf("\n");
}

int main(int argc, char **argv) {
    const char *name = argc > 1 ? argv[1] : "sample";
    int n = argc > 2 ? atoi(argv[2]) : 3;
    char path[256];
    snprintf(path, sizeof path, "%s.json", name);
    FILE *fp = fopen(path, "rb");
    if (!fp) {
        perror(path);
        return 1;
    }
    fseek(fp, 0, SEEK_END);
    size_t size = (size_t)ftell(fp);
    fseek(fp, 0, SEEK_SET);
    char *text = malloc(size + 1);
    if (fread(text, 1, size, fp) != size) return 1;
    text[size] = '\0';
    fclose(fp);
    const char *json = strncmp(text, "\xef\xbb\xbf", 3) == 0 ? text + 3 : text;

    Buffer out = {0};
    Value value;
    Parser ps = {json};
    parse_value(&ps, &value);
    dump(&out, &value);
    print_hash(&out);
    release(&value);

    Value array = {.kind = J_ARRAY};
    array.list.count = (size_t)n;
    array.list.items = malloc(sizeof(Value) * (size_t)(n > 0 ? n : 1));
    for (int i = 0; i < n; i++) {
        Parser p = {json};
        parse_value(&p, &array.list.items[i]);
    }
    out.length = 0;
    dump(&out, &array);
    print_hash(&out);
    release(&array);
    return 0;
}
