#pragma once
#include <string>
#include <cstdio>
#include <cstddef>   // size_t
#include <cstdlib>   // malloc
#include <cstring>   // memcpy
#include <utility>   // swap
#undef do_open       // fix perl fuckups
#undef do_close      // fix perl fuckups
#include <ostream>
#include <istream>
#include <algorithm> // min,max
#include <stdexcept>
#include <panda/iterator.h>

namespace panda {

using std::size_t;

class string {
private:
    union {
        char*       buf; // heap pointer (possibly shared)
        const char* ptr; // external pointer
    } _u;
    size_t _capacity; // _u.buf capacity. external pointer mode if capacity == 0
    size_t _length;   // external/buffer string length

    size_t* _buf_refcnt_ptr () { return (size_t*)(_u.buf - sizeof(size_t)); }
    size_t  _buf_refcnt     () { return *_buf_refcnt_ptr(); }
    size_t  _buf_refcnt_dec () { return --*_buf_refcnt_ptr(); }
    size_t  _buf_refcnt_inc () { return ++*_buf_refcnt_ptr(); }
    void    _buf_release    () { if (_capacity && _buf_refcnt_dec() <= 0) free(_buf_refcnt_ptr()); }

    void _realloc (size_t size) {
        char* heap = (char*)std::realloc(_u.buf - sizeof(size_t), size + sizeof(size_t) + 1);
        if (!heap) throw std::bad_alloc();
        _u.buf = heap + sizeof(size_t);
        _capacity = size;
    }

public:
    typedef base_iterator<char*>                  iterator;
    typedef base_iterator<const char*>            const_iterator;
    typedef std::reverse_iterator<iterator>       reverse_iterator;
    typedef std::reverse_iterator<const_iterator> const_reverse_iterator;

    enum ref_t { REF = 0, COPY = 1 };
    static const size_t npos = std::basic_string<char>::npos;

    string ()                                               : _capacity(0), _length(0)  { _u.ptr = ""; }
    string (size_t n, char c)                               : _capacity(0) { assign(n, c); }
    string (const char* p, ref_t ref = REF)                 : _capacity(0) { assign(p, ref); }
    string (const char* p, size_t len, ref_t ref = REF)     : _capacity(0) { assign(p, len, ref); }
    string (const string& s)                                : _capacity(0) { assign(s); }
    string (const string& s, size_t pos, size_t len = npos) : _capacity(0) { assign(s, pos, len); }
    explicit string (size_t n)                              : _capacity(0), _length(0) { reserve(n); }

    size_t      size     () const { return _length; }
    size_t      length   () const { return _length; }
    size_t      capacity () const { return _capacity; }
    bool        empty    () const { return _length == 0; }
    const char* data     () const { return _u.ptr; }
    const char* c_str    () const { return _u.ptr; }
    char*       buf      ()       { retain(); return _u.buf; }

    void dump () {
        std::printf(
            "STRDUMP: DYN=%lu, LEN=%lu, CAP=%lu, DATA='%s', SA/BA=%lu/%lu\n",
            _capacity ? _buf_refcnt() : 0, _length, _capacity, _u.ptr, (unsigned long)this, _capacity ? (unsigned long)_u.buf : 0
        );
    }

    iterator               begin   ()       { iterator it(buf()); return it; }
    iterator               end     ()       { return iterator(buf() + _length); }
    reverse_iterator       rbegin  ()       { return reverse_iterator(end()); }
    reverse_iterator       rend    ()       { return reverse_iterator(begin()); }
    const_iterator         cbegin  () const { return const_iterator(data()); }
    const_iterator         begin   () const { return cbegin(); }
    const_iterator         cend    () const { return const_iterator(data() + _length); }
    const_iterator         end     () const { return cend(); }
    const_reverse_iterator crbegin () const { return const_reverse_iterator(cend()); }
    const_reverse_iterator rbegin  () const { return crbegin(); }
    const_reverse_iterator crend   () const { return const_reverse_iterator(cbegin()); }
    const_reverse_iterator rend    () const { return crend(); }

    string& retain () {
        reserve(_length);
        return *this;
    }

    char* reserve (size_t size) {
        if (size == 0) size++; // zero _capacity (malloced = _capacity + 1) leads to memleaks
        if (!_capacity || (_buf_refcnt() > 1 && _buf_refcnt_dec())) {
            if (size < _length) size = _length;
            char* heap = (char*)std::malloc(size + sizeof(size_t) + 1);
            if (!heap) throw std::bad_alloc();
            *(size_t*)heap = 1; // refcnt = 1
            char* newbuf = heap + sizeof(size_t);
            if (_length) std::memcpy(newbuf, _u.buf, _length);
            newbuf[_length] = 0;
            _u.buf = newbuf;
            _capacity = size;
        }
        else if (_capacity < size) _realloc(size);
        return _u.buf;
    }

    char* resize (size_t size) {
        char* ptr = reserve(size);
        ptr[size] = 0;
        _length = size;
        return ptr;
    }

    char* resize (size_t size, char c) {
        size_t oldlen = _length;
        char* ptr = resize(size);
        if (size > oldlen) std::memset(ptr + oldlen, c, size - oldlen);
        return ptr;
    }

    void shrink_to_fit () {
        if (_capacity <= _length) return;
        if (_buf_refcnt() == 1) _realloc(_length);
        else reserve(_length);
    }

    string& assign (const string& s) {
        _buf_release();
        _u.ptr = s._u.ptr;
        _length = s._length;
        if ((_capacity = s._capacity)) _buf_refcnt_inc();
        return *this;
    }
    string& assign (const string& s, size_t pos, size_t len = npos) {
        if (pos == 0 && len >= s._length) return assign(s);
        if (pos > s._length) throw std::out_of_range("string::assign");
        if (len > s._length - pos) len = s._length - pos;
        return assign(s._u.ptr + pos, len, COPY); // need copy because pointers to partial buffers are not supported
    }
    string& assign (const char* p, ref_t ref = REF) {
        return assign(p, std::strlen(p), ref);
    }
    string& assign (const char* p, size_t len, ref_t ref = REF) {
        if (ref == COPY) {
            _length = 0; // prevent copying old data
            if (!len) clear();
            else std::memcpy(resize(len), p, len);
        }
        else {
            _buf_release();
            _u.ptr = p;
            _length = len;
        }
        return *this;
    }
    string& assign (size_t n, char c) {
        _length = 0; // prevent copying old data
        if (!n) clear();
        else std::memset(resize(n), c, n);
        return *this;
    }

    string& operator= (const string& source) { if (this != &source) assign(source); return *this; }
    string& operator= (const char* ptr)      { return assign(ptr); }
    string& operator= (char c)               { return assign(1, c); }

    string& append (const string& s) {
        return append(s._u.ptr, s._length);
    }
    string& append (const string& s, size_t pos, size_t len = npos) {
        if (pos > s._length) throw std::out_of_range("string::append");
        if (len > s._length - pos) len = s._length - pos;
        return append(s._u.ptr + pos, len);
    }
    string& append (const char* p) {
        return append(p, std::strlen(p));
    }
    string& append (const char* p, size_t n) {
        resize(_length + n);
        std::memcpy(_u.buf + _length - n, p, n);
        return *this;
    }
    string& append (size_t n, char c) {
        resize(_length + n);
        std::memset(_u.buf + _length - n, c, n);
        return *this;
    }
    string& append (char c) {
        return append(1, c);
    }

    string& operator+= (const string& s) { return append(s); }
    string& operator+= (const char* p)   { return append(p); }
    string& operator+= (char c)          { return append(1, c); }
    void    push_back  (char c)          { append(1, c); }
    void    pop_back   ()                { resize(_length-1); }

    string& replace (size_t pos, size_t len, const string& s) {
        return replace(pos, len, s._u.ptr, s._length);
    }
    string& replace (iterator i1, iterator i2, const string& s) {
        return replace(i1 - begin(), i2 - i1, s._u.ptr, s._length);
    }
    string& replace (size_t pos, size_t len, const string& s, size_t pos2, size_t len2 = npos) {
        if (pos2 > s._length) throw std::out_of_range("string::replace");
        if (len2 > s._length - pos2) len2 = s._length - pos2;
        return replace(pos, len, s._u.ptr + pos2, len2);
    }
    string& replace (size_t pos, size_t len, const char* p) {
        return replace(pos, len, p, std::strlen(p));
    }
    string& replace (iterator i1, iterator i2, const char* p) {
        return replace(i1 - begin(), i2 - i1, p, std::strlen(p));
    }
    string& replace (iterator i1, iterator i2, const char* p, size_t n) {
        return replace(i1 - begin(), i2 - i1, p, n);
    }
    string& replace (size_t pos, size_t len, const char* p, size_t n) {
        if (pos > _length) throw std::out_of_range("string::replace");
        if (len > _length - pos) len = _length - pos;
        char* buf = reserve(_length += n - len);
        if (len != n) std::memmove(buf + pos + n, buf + pos + len, _length - n - pos);
        std::memcpy(buf + pos, p, n);
        buf[_length] = 0;
        return *this;
    }
    string& replace (size_t pos, size_t len, size_t n, char c) {
        if (pos > _length) throw std::out_of_range("string::replace");
        if (len > _length - pos) len = _length - pos;
        char* buf = reserve(_length += n - len);
        if (len != n) std::memmove(buf + pos + n, buf + pos + len, _length - n - pos);
        std::memset(buf + pos, c, n);
        buf[_length] = 0;
        return *this;
    }
    string& replace (iterator i1, iterator i2, size_t n, char c) {
        return replace(i1 - begin(), i2 - i1, n, c);
    }

    string& insert (size_t pos, const string& s) {
        return replace(pos, 0, s);
    }
    string& insert (size_t pos, const string& s, size_t pos2, size_t len2 = npos) {
        return replace(pos, 0, s, pos2, len2);
    }
    string& insert (size_t pos, const char* p) {
        return insert(pos, p, std::strlen(p));
    }
    string& insert (size_t pos, const char* p, size_t n) {
        return replace(pos, 0, p, n);
    }
    string& insert (size_t pos, size_t n, char c) {
        return replace(pos, 0, n, c);
    }
    void insert (iterator p, size_t n, char c) {
        insert(p - begin(), n, c);
    }
    iterator insert (iterator p, char c) {
        size_t pos = p - begin();
        insert(pos, 1, c);
        return begin() + pos;
    }

    iterator erase (iterator p) {
        size_t pos = p - begin();
        erase(pos, 1);
        return begin() + pos;
    }
    iterator erase (iterator first, iterator last) {
        size_t pos = first - begin();
        erase(pos, last - first);
        return begin() + pos;
    }
    string& erase (size_t pos = 0, size_t len = npos) {
        if (pos > _length) throw std::out_of_range("string::erase");
        if (len > _length - pos) len = _length - pos;
        if (len == _length) {
            clear();
            return *this;
        }
        _length -= len;
        char* buf = reserve(_length);
        std::memmove(buf + pos, buf + pos + len, _length - pos);
        buf[_length] = 0;
        return *this;
    }

    int compare (size_t pos, size_t len, const char* p, size_t n) const {
        if (pos > _length) throw std::out_of_range("string::compare");
        if (len > _length - pos) len = _length - pos;
        return std::strncmp(_u.ptr + pos, p, std::max(len, n));
    }
    int compare (size_t pos, size_t len, const string& s) const {
        return compare(pos, len, s._u.ptr, s._length);
    }
    int compare (size_t pos, size_t len, const string& s, size_t pos2, size_t len2) const {
        if (pos2 > s._length) throw std::out_of_range("string::compare");
        if (len2 > s._length - pos2) len2 = s._length - pos2;
        return compare(pos, len, s._u.ptr + pos2, len2);
    }
    int compare (const string& s) const {
        return compare(s._u.ptr);
    }
    int compare (const char* p) const {
        return std::strcmp(_u.ptr, p);
    }
    int compare (size_t pos, size_t len, const char* p) const {
        return compare(pos, len, p, std::strlen(p));
    }

    void swap (string& s) {
        std::swap(_u.ptr, s._u.ptr);
        std::swap(_length, s._length);
        std::swap(_capacity, s._capacity);
    }

    const char& at         (size_t pos) const { if (pos >= _length) throw std::out_of_range("string::at"); return _u.ptr[pos]; }
    char&       at         (size_t pos)       { if (pos >= _length) throw std::out_of_range("string::at"); return buf()[pos]; }
    const char& operator[] (size_t pos) const { return _u.ptr[pos]; }
    char&       operator[] (size_t pos)       { return buf()[pos]; }

    const char& front () const { return _u.ptr[0]; }
    char&       front ()       { return buf()[0]; }
    const char& back  () const { return _u.ptr[_length-1]; }
    char&       back  ()       { return buf()[_length-1]; }

    void clear () {
        if (_capacity) resize(0);
        else assign("", 0);
    }

    size_t copy (char* p, size_t len, size_t pos = 0) const {
        if (pos > _length) throw std::out_of_range("string::copy");
        if (len > _length - pos) len = _length - pos;
        std::memcpy(p, _u.ptr + pos, len);
        return len;
    }

    size_t find (const string& str, size_t pos = 0) const {
        return find(str._u.ptr, pos, str._length);
    }
    size_t find (const char* p, size_t pos = 0) const {
        return find(p, pos, std::strlen(p));
    }
    size_t find (const char* p, size_t pos, size_t n) const {
        if (n == 0) return pos <= _length ? pos : npos;
        if (n <= _length)
            for (; pos <= _length - n; ++pos)
                if (_u.ptr[pos] == p[0] && std::strncmp(_u.ptr + pos + 1, p + 1, n - 1) == 0)
                    return pos;
        return npos;
    }
    size_t find (char c, size_t pos = 0) const {
        if (pos > _length) return npos;
        const char* found = (const char*) std::memchr(_u.ptr+pos, c, _length - pos);
        return found ? (found - _u.ptr) : npos;
    }

    size_t rfind (const string& str, size_t pos = npos) const {
        return rfind(str._u.ptr, pos, str._length);
    }
    size_t rfind (const char* p, size_t pos = npos) const {
        return rfind(p, pos, std::strlen(p));
    }
    size_t rfind (const char* p, size_t pos, size_t n) const {
        if (n <= _length) {
            pos = std::min(_length - n, pos);
            do {
                if (std::strncmp(_u.ptr + pos, p, n) == 0) return pos;
            } while (pos-- > 0);
        }
        return npos;
    }
    size_t rfind (char c, size_t pos = npos) const {
        if (size_t slen = _length) {
            if (--slen > pos) slen = pos;
            for (++slen; slen-- > 0; )
                if (_u.ptr[slen] == c)
                    return slen;
        }
        return npos;
    }

    string substr (size_t pos = 0, size_t len = npos) const {
        return string(*this, pos, len);
    }

    operator std::string() const { return std::string(data(), _length); }

    ~string () {
        _buf_release();
    }
};

inline string operator+ (const string& lhs, const string& rhs) { return string(lhs).append(rhs); }
inline string operator+ (const string& lhs, const char*   rhs) { return string(lhs).append(rhs); }
inline string operator+ (const char*   lhs, const string& rhs) { return string(rhs).insert(0, lhs); }
inline string operator+ (const string& lhs, char          rhs) { return string(lhs).append(1, rhs); }
inline string operator+ (char          lhs, const string& rhs) { return string(rhs).insert(0, 1, lhs); }

inline bool operator== (const string& lhs, const string& rhs) { return lhs.compare(rhs) == 0; }
inline bool operator== (const char*   lhs, const string& rhs) { return rhs.compare(lhs) == 0; }
inline bool operator== (const string& lhs, const char*   rhs) { return lhs.compare(rhs) == 0; }

inline bool operator!= (const string& lhs, const string& rhs) { return lhs.compare(rhs) != 0; }
inline bool operator!= (const char*   lhs, const string& rhs) { return rhs.compare(lhs) != 0; }
inline bool operator!= (const string& lhs, const char*   rhs) { return lhs.compare(rhs) != 0; }

inline bool operator<  (const string& lhs, const string& rhs) { return lhs.compare(rhs) < 0; }
inline bool operator<  (const char*   lhs, const string& rhs) { return rhs.compare(lhs) > 0; }
inline bool operator<  (const string& lhs, const char*   rhs) { return lhs.compare(rhs) < 0; }

inline bool operator<= (const string& lhs, const string& rhs) { return lhs.compare(rhs) <= 0; }
inline bool operator<= (const char*   lhs, const string& rhs) { return rhs.compare(lhs) >= 0; }
inline bool operator<= (const string& lhs, const char*   rhs) { return lhs.compare(rhs) <= 0; }

inline bool operator>  (const string& lhs, const string& rhs) { return lhs.compare(rhs) > 0; }
inline bool operator>  (const char*   lhs, const string& rhs) { return rhs.compare(lhs) < 0; }
inline bool operator>  (const string& lhs, const char*   rhs) { return lhs.compare(rhs) > 0; }

inline bool operator>= (const string& lhs, const string& rhs) { return lhs.compare(rhs) >= 0; }
inline bool operator>= (const char*   lhs, const string& rhs) { return rhs.compare(lhs) <= 0; }
inline bool operator>= (const string& lhs, const char*   rhs) { return lhs.compare(rhs) >= 0; }

inline void swap (string& l, string& r) { l.swap(r); }

inline std::ostream& operator<< (std::ostream& os, const string& str) { return os << str.data(); }
inline std::istream& operator>> (std::istream& is, string& str)       { return is >> str.buf(); }

};
