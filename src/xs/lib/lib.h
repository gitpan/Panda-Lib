#pragma once
#include <xs/xs.h>
#include <panda/string.h>

namespace xs { namespace lib {

inline panda::string sv2string (SV* svstr, panda::string::ref_t ref = panda::string::COPY) {
    STRLEN len;
    char* ptr = SvPV(svstr, len);
    return panda::string(ptr, len, ref);
}

}}
