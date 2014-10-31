#pragma once
#include <stdint.h>
#include <stddef.h>
#include <cstring>

#ifndef likely
#  define likely(x)   __builtin_expect((x),1)
#  define unlikely(x) __builtin_expect((x),0)
#endif

namespace panda { namespace lib {

char* itoa (int64_t i);

uint64_t string_hash (const char* str, size_t len);
inline uint64_t string_hash (const char* str) { return string_hash(str, std::strlen(str)); }

uint32_t string_hash32 (const char* str, size_t len);
inline uint32_t string_hash32 (const char* str) { return string_hash32(str, std::strlen(str)); }

char* crypt_xor (const char* source, size_t slen, const char* key, size_t klen, char* dest = NULL);

}};
