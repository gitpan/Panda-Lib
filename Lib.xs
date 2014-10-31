#include <stdint.h>
#include <xs/lib.h>
#include <panda/lib.h>
#include <panda/string.h>

using namespace panda::lib;
using namespace xs::lib;

MODULE = Panda::Lib                PACKAGE = Panda::Lib
PROTOTYPES: DISABLE

uint64_t string_hash (SV* source) {
    STRLEN len;
    const char* str = SvPV(source, len);
    RETVAL = string_hash(str, len);
}

uint32_t string_hash32 (SV* source) {
    STRLEN len;
    const char* str = SvPV(source, len);
    RETVAL = string_hash32(str, len);
}

SV* crypt_xor (SV* source_string, SV* key_string) {
    STRLEN slen, klen;
    char* str = SvPV(source_string, slen);
    char* key = SvPV(key_string, klen);
    RETVAL = newSV(slen+1);
    SvPOK_on(RETVAL);
    SvCUR_set(RETVAL, slen);
    crypt_xor(str, slen, key, klen, SvPVX(RETVAL));
}

SV* hash_merge (HV* dest, HV* source, int flags = 0) {
    HV* result = hash_merge(dest, source, flags);
    if (result == dest) { // hash not changed - return the same RV for speed
        RETVAL = ST(0);
        SvREFCNT_inc_simple_void_NN(RETVAL);
    }
    else RETVAL = newRV_noinc((SV*)result);
}

SV* merge (SV* dest, SV* source, int flags = 0) {
    RETVAL = merge(dest, source, flags);
    if (RETVAL == dest) SvREFCNT_inc_simple_void_NN(RETVAL);
}

SV* clone (SV* source) : ALIAS(fclone = 1) {
    RETVAL = clone(source, ix == 1 ? true : false);
}

bool compare (SV* first, SV* second) {
    RETVAL = sv_compare(first, second);
}

char* itoa (IV i) {
    RETVAL = itoa(i);
}