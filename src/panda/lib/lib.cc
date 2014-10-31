#include <new>
#include <cstdlib>
#include <panda/lib/lib.h>

namespace panda { namespace lib {

char* itoa (int64_t i) {
    const int INT_DIGITS = 19; /* enough for 64 bit integer */
    static char buf[INT_DIGITS + 2]; /* Room for INT_DIGITS digits, - and '\0' */
    char *p = buf + INT_DIGITS + 1;   /* points to terminating '\0' */
    if (i >= 0) {
        do {
            *--p = '0' + (i % 10);
            i /= 10;
        } while (i != 0);
        return p;
    }
    else {            /* i < 0 */
        do {
            *--p = '0' - (i % 10);
            i /= 10;
        } while (i != 0);
        *--p = '-';
    }
    return p;
}

uint64_t string_hash (const char* str, size_t len) { // MurMurHash64A
    const uint64_t seed = 7;
    const uint64_t m = 0xc6a4a7935bd1e995LLU;
    const int r = 47;

    const uint64_t * data = (const uint64_t *) str;
    const uint64_t * end = data + (len/8);
    
    uint64_t h = seed ^ (len * m);

    while (data != end) {
        uint64_t k = *data++;
        k *= m;
        k ^= k >> r;
        k *= m;

        h ^= k;
        h *= m;
    }

    const unsigned char * data2 = (const unsigned char*) data;
    switch (len & 7) {
    case 7: h ^= uint64_t(data2[6]) << 48;
    case 6: h ^= uint64_t(data2[5]) << 40;
    case 5: h ^= uint64_t(data2[4]) << 32;
    case 4: h ^= uint64_t(data2[3]) << 24;
    case 3: h ^= uint64_t(data2[2]) << 16;
    case 2: h ^= uint64_t(data2[1]) << 8;
    case 1: h ^= uint64_t(data2[0]);
            h *= m;
    };

    h ^= h >> r;
    h *= m;
    h ^= h >> r;

    return h;
}

uint32_t string_hash32 (const char *key, size_t len) { // jenkins_one_at_a_time_hash
    uint32_t hash, i;
    for (hash = i = 0; i < len; ++i) {
        hash += key[i];
        hash += (hash << 10);
        hash ^= (hash >> 6);
    }
    hash += (hash << 3);
    hash ^= (hash >> 11);
    hash += (hash << 15);
    return hash;
}

char* crypt_xor (const char* source, size_t slen, const char* key, size_t klen, char* dest) {
    unsigned char* buf;
    if (dest) buf = (unsigned char*) dest;
    else {
        buf = (unsigned char*) std::malloc(slen+1); // space for '0'
        if (!buf) throw std::bad_alloc();
    }
    for (int i = 0; i < slen; ++i) dest[i] = ((unsigned char) source[i]) ^ ((unsigned char) key[i % klen]);
    dest[slen] = 0;
    return (char*) dest;
}

}}
