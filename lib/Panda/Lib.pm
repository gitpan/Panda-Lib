package Panda::Lib;
use parent 'Panda::Export';
use 5.012;
use Encode();
use Time::HiRes();

=head1 NAME

Panda::Lib - Collection of useful functions and classes with Perl and C interface.

=cut

use Panda::Export
    MERGE_ARRAY_CONCAT => 1,
    MERGE_ARRAY_MERGE  => 2,
    MERGE_COPY_DEST    => 4,
    MERGE_LAZY         => 8,
    MERGE_SKIP_UNDEF   => 16,
    MERGE_DELETE_UNDEF => 32,
    MERGE_COPY_SOURCE  => 64;
use Panda::Export
    MERGE_COPY => MERGE_COPY_DEST | MERGE_COPY_SOURCE;
    
our $VERSION = '0.1.0';

require Panda::XSLoader;
Panda::XSLoader::bootstrap();

*hash_cmp = *compare; # for compability

sub timeout {
    my ($sub, $timeout) = @_;
    my ($ok, $alarm);
    local $SIG{ALRM} = sub {$alarm = 1; die "ALARM!"};
    Time::HiRes::alarm($timeout || 1);
    eval {
        $ok = eval { $sub->(); 1 };
        die $@ if !$ok and !$alarm;
        Time::HiRes::alarm(0);
    };
    return if $alarm;
    die $@ if !$ok;
    return 1;
}

sub encode_utf8_struct {
    my $data = shift;
    if (ref($data) eq 'HASH') {
        foreach my $v (values %$data) {
            if (ref $v) { encode_utf8_struct($v) }
            elsif (utf8::is_utf8($v)) { $v = Encode::encode_utf8($v) }
        }
    }
    elsif (ref($data) eq 'ARRAY') {
        map {
            if (ref $_) { encode_utf8_struct($_) }
            elsif (utf8::is_utf8($_)) { $_ = Encode::encode_utf8($_) }
        } @$data;
    }
}


sub decode_utf8_struct {
    my $data = shift;
    if (ref($data) eq 'HASH') {
        foreach my $v (values %$data) {
            if (ref $v) { decode_utf8_struct($v) }
            elsif (!utf8::is_utf8($v)) { $v = Encode::decode_utf8($v) }
        }
    }
    elsif (ref($data) eq 'ARRAY') {
        map {
            if (ref $_) { decode_utf8_struct($_) }
            elsif (!utf8::is_utf8($_)) { $_ = Encode::decode_utf8($_) }
        } @$data;
    }
}

=head1 DESCRIPTION

Panda::Lib contains a number of very fast useful functions, written in C. You can use it from Perl or directly from XS code.
Also it contains several C++ classes.

=head1 SYNOPSIS

    use Panda::Lib qw/ hash_merge merge compare clone fclone crypt_xor string_hash string_hash32 /;
                       
    $result = hash_merge($dest, $source, $flags);
    $result = merge($dest, $source, $flags);
    $is_equal = compare($hash1, $hash2);
    $is_equal = compare($array1, $array2);
    $cloned = clone($data);
    $cloned = fclone($data);
    $crypted = crypt_xor($data, $key);
    $val = string_hash($str);
    $val = string_hash32($str);

=head1 C SYNOPSIS

    #include <xs/lib.h>
    using namespace xs::lib;
    
    HV* result = hash_merge(hvdest, hvsource, flags);
    SV* result = merge(hvdest, hvsource, flags);
    bool is_equal = hash_cmp(hv1, hv2);
    bool is_equal = av_cmp(av1, av2);
    SV* cloned = clone(sv, with_cross_checks);
    panda::string str = sv2string(sv, ref_type);
    
    #include <panda/lib.h>
    using namespace panda::lib;
    
    char* crypted = crypt_xor(source, slen, key, klen);
    uint32_t val = string_hash32(str, len);
    uint64_t val = string_hash(str, len);
    
    #include <panda/string.h>
    using panda::string;
    
    string abc("lala");
    ... // everything that std::string supports
   
=head1 PERL FUNCTIONS

=head4 hash_merge (\%dest, \%source, [$flags])

Merges hash $source into $dest. Merge is done extremely fast. $source and $dest must be HASHREFS or undefs.
New keys from source are added to dest. Existing keys(values) are replaced. If a key contains HASHREF both in source and dest,
they are merged recursively. Otherwise it gets replaced by value from source. Returns resulting hashref (it may or may not be the
the same ref as $dest, depending on $flags provided).

$flags is a bitmask of these flags:

=over

=item MERGE_ARRAY_CONCAT

By default, if a key contains ARRAYREF both in source and dest, it gets replaced by array from source. If you enable this flag,
such arrays will be concatenated (like: push @{$dest->{key}}, @{$source->{key}).

=item MERGE_ARRAY_MERGE

If a key contains ARRAYREF both in source and dest, it gets merged. It means that $dest->{key}[0] is merged with $source->{key}[0],
and so on. Values are merged using following rules: if both are hashrefs or arrayrefs, they are merged recursively, otherwise
value in dest gets replaced.

=item MERGE_LAZY

If you set this flag, merge process won't override any existing and defined values in dest. Keep in mind that if you also set
MERGE_ARRAY_MERGE, then the same is in effect while merging array elements.

    my $hash1 = {a => 1, b => undef};
    my $hash2 = {a => 2, b => 3, c => undef };
    hash_merge($hash1, $hash2, MERGE_LAZY);
    # $hash1 is {a => 1, b => 3, c => undef };

=item MERGE_SKIP_UNDEF

If enabled, values from source that are undefs won't replace anything in dest. 

    my $hash1 = {a => 1};
    my $hash2 = {a => undef, b => undef, c => 2};
    hash_merge($hash1, $hash2, MERGE_SKIP_UNDEF);
    # $hash1 is {a => 1, c => 2};

=item MERGE_DELETE_UNDEF

If enabled, values from source that are undefs acts as a 'deleters', i.e. the corresponding values get deleted from dest.

    my $hash1 = {a => 1, b => 2};
    my $hash2 = {a => undef};
    hash_merge($hash1, $hash2, MERGE_DELETE_UNDEF);
    # $hash1 is {b => 2};

=item MERGE_COPY_DEST

Makes deep copy of $dest, merges it with source and returns this new hashref.

=item MERGE_COPY_SOURCE

By default, if any value from source replaces value from dest, it doesn't get deep copied. For example:

    my $hash1 = {};
    my $hash2 = {a => [1,2]};
    hash_merge($hash1, $hash2);
    shift @{$hash1->{a}};
    say scalar @{$hash2->{a}}; # prints 1

Moreover, even primitive values are not copied, instead they get aliased for speed. For example:

    my $hash1 = {};
    my $hash2 = {a => 'mystring'};
    hash_merge($hash1, $hash2);
    substr($hash1->{a}, 0, 2);
    say $hash2->{a}; # prints 'string'

If you enable this flag, replacing values from source will be copied (references - deep copied).

=item MERGE_COPY

It is MERGE_COPY_DEST + MERGE_COPY_SOURCE

=back

This is how undefined $source or undefined $dest are handled:

=over

=item If $source is undef

Nothing is merged, however if MERGE_COPY_DEST is set, deep copy of $dest is still returned.
If $dest is also undef, then regardless of MERGE_COPY_DEST flag, empty hashref is returned.

=item If $dest is undef

Empty hashref is created, merged with $source and returned.

=back

=head4 merge ($dest, $source, [$flags])

Acts much like 'hash_merge', but receives any scalar as $dest and $source, not only hashrefs.
Returns merged value which may or may not be the same scalar (modified or not) as $dest.

This function does the same work as 'hash_merge' does for its elements. I.e. if both $dest and $source are HASHREFs then they
are merged via 'hash_merge'. If both are ARRAYREFs, then depending on $flags, $dest are either replaced, concatenated or merged.
Otherwise $source replaces $dest following the rules described in 'hash_merge' function with respect to flags MERGE_COPY_DEST,
MERGE_COPY_SOURCE and MERGE_LAZY.

For example, if $source and $dest are scalars (not refs), and no flags provided, then $dest becomes equal $source.
If MERGE_LAZY is provided and $dest is not an undef, $dest is unchanged.
If MERGE_COPY_DEST is provided then $dest is unchaged and the result is returned in a new scalar.
And so on.

However there is one difference: if $dest and $source are primitive scalars, instead of creating an alias, the $source variable
is copied to $dest (or new result). If MERGE_COPY_SOURCE is disabled, copying is not deep, like $dest = $source.

=head4 clone ($source)

Makes a deep copy of $source and returns it.

Does not handle cross-references: references to the same data will be different references.
If cycled reference presents in $source, it will croak.

Handles CODEREFs and IOREFs, but doesn't clone it, just copies pointer to the same CODE and IO into new reference. All other
data types are cloned normally.

If clone encounters a blessed object and it has 'CLONE' method, the return value of this method is used instead of a default behaviour.
You can call clone($self) again from 'CLONE' callback if you need to, for example to prevent cloning some of your properties:

    sub CLONE {
        my $self = shift;
        my $tmp = delete local $self->{big_obj_backref};
        my $ret = clone($self);
        $ret->{big_obj_backref} = $tmp;
        return $ret;
    }

In this case second 'clone' call won't call CLONE callback on $self and will clone $self in a standart manner.

=head4 fclone ($source)

Same as 'clone' but handles cross-references: references to the same data will be the same references.
If cycled reference presents in $source, it will remain cycled in cloned data.

=head4 compare ($data1, $data2)

Performs deep comparison and returns true if every element of $data1 is equal to corresponding element of $data2.

The rules of equality for two elements (including the top-level $data1 and $data2 itself):

=over

=item If any of two elements is a reference.

=over

=item If any of elements is a blessed object

If they are not objects of the same class, they're not equal

If class has overloaded '==' operation, it is used for checking equality.
If not, objects' underlying data structures are compared.

=item If both elements are hash refs.

Equal if all of the key/value pairs are equal.

=item If both elements are array refs.

Equal if corresponding elements are equal (a[0] equal b[0], etc).

=item If both elements are code refs.

Equal if they are references to the same code.

=item If both elements are IOs (IO refs)

Equal if both IOs contain the same fileno.

=item If both elements are typeglobs

Equal if both are references to the same glob.

=item If both elements are refs to anything.

They are dereferenced and checked again from the beginning.

=item Otherwise (one is ref, another is not) they are not equal

=back

=item If both elements are not references

Equal if perl's 'eq' or '==' (depending on data type) returns true.

=back

=head4 crypt_xor ($string, $key)

Performs round-robin XOR $string with $key. Algorithm is symmetric, i.e.:

    crypt_xor(crypt_xor($string, $key), $key) eq $string
    
=head4 string_hash ($string)

Calculates 64-bit hash value for $string. Currently uses MurMurHash64A algorithm (very fast).

=head4 string_hash32 ($string)

Calculates 32-bit hash value for $string. Currently uses jenkins_one_at_a_time_hash algorithm.

=head1 C FUNCTIONS

=head4 HV* xs::lib::hash_merge (HV* dest, HV* source, IV flags)

=head4 SV* xs::lib::merge (SV* dest, SV* source, IV flags)

=head4 SV* xs::lib::clone (SV* source, bool cross_references)

=head4 bool xs::lib::hv_compare (HV*, HV*)

=head4 bool xs::lib::av_compare (AV*, AV*)

=head4 bool xs::lib::sv_compare (SV*, SV*)

=head4 uint64_t panda::lib::string_hash (const char* str, size_t len)

=head4 uint64_t panda::lib::string_hash (const char* str)

=head4 uint32_t panda::lib::string_hash32 (const char* str, size_t len)

=head4 uint32_t panda::lib::string_hash32 (const char* str)

All functions above behaves like its perl equivalents. See PERL FUNCTIONS docs.

=head4 char* panda::lib::crypt_xor (const char* source, size_t slen, const char* key, size_t klen, char* dest = NULL)

Performs XOR crypt. If 'dest' is null, mallocs and returns new buffer. Buffer must be freed by user manually via 'free'. If 'dest'
is not null, places result into this buffer. It must have enough space to hold the result.

=head4 panda::string xs::lib::sv2string (SV* svstr, panda::string::ref_t ref = panda::string::COPY)

Creates panda::string from SV string. If 'ref' is COPY then content of SV is copied to string. If 'ref' is REF, then returned
string is a copy-on-write string holding SV's buffer. In this case you must NOT change or delete your SV until you're done with string.

Panda::Lib installs a typemap for panda::string, so it is okay to receive it in XS function params without copying.

    using panda::string;
    
    ...
    
    void
    myfunc (string str)
    PPCODE:
        // dont change ST(0), while working with str
        printf("string is %s, len is %d", str.data(), str.length());
        str.retain(); // it ok now to change ST(0), as str is detached from original string.
        ...

=head1 C++ CLASSES

=head2 panda::string

This string is fully compatible with std::string API, however it supports COW (copy-on-write) and therefore runs much faster
in many cases. C++11 supports COW with other strings, but doesn't support COW with external pointers, which is meaningful when
creating a string from literal: string("mystring"), or myhash["mykey"]

=head3 SYNOPSIS

    using panda::string;

    string str("abcd"); // "abcd" is not copied, COW mode.
    str.append("ef"); // str is copied on modification.
    cout << str; // prints 'abcdef'
    
    char* mystr = new char[10];
    memcpy(mystr, "hello, world", 13);
    str.assign(mystr, 12); // COW mode, don't free mystr until you're done with str.
    str.retain(); // abort COW, str is detached, buffer is copied.
    
    string str2(mystr, string::COPY); // no-COW, std::string-like behaviour, mystr is copied to str2.
    str2.resize(5);
    cout << str2; // 'hello'
    
    str = str2; // COW mode, buffer is not copied. Unlike for char* pointers, you can safely destroy str2 at any time
    cout << str; // 'hello'
    str.append('!'); // detach on modification
    cout << str << str2; // 'hello!hello'

panda::string is converted into std::string on demand. Also it can be used in ostream's and istream's << >> operators.

=head3 METHODS

Only new methods or methods with additional params are listed. All other methods have the same syntax and meaning as in std::string.

=head4 string (const char* p, ref_t ref = REF)

=head4 string (const char* p, size_t len, ref_t ref = REF)

If 'ref' is REF, then newly created string will use COW mode with buffer 'p'. It's your responsibility to keep 'p' pointer valid
until you're done with string or changed it anyhow.

If 'ref' is COPY, then 'p' is copied to string and it won't depend on 'p' pointer.

The default is REF, it saves time in such common cases as:

    void myfunc (const string str) { ... }
    myfunc("hello");
    
or

    std::map<string, int> myhash;
    iter = myhash["mykey"];

=head4 char* buf ()

Returns string buffer like 'data' or 'c_str' but this buffer is writable. Therefore if a string was in COW mode, it detaches.
Common case: parse something directly into string:

    string str;
    str.reserve(1000);
    char* buf = str.buf();
    // fill buf
    str.resize(actual_length);
    
=head4 string& retain ()

Detaches string if it's in COW mode. Does nothing otherwise. Returns the string itself.

=head4 string& assign (const char* p, ref_t ref = REF)

=head4 string& assign (const char* p, size_t len, ref_t ref = REF)

'ref' has the same meaning as in constructor.

=head1 TYPEMAPS

=head4 panda::string

=head4 std::string

=head4 string

typemap for panda::string or std::string or anything else you see as 'string' in your local scope. Such a class must have
std::string-compatible API.

=head1 AUTHOR

Pronin Oleg <syber@crazypanda.ru>, Crazy Panda, CP Decision LTD

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

1;
