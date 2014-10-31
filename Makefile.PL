use strict;
use Panda::Install;

write_makefile(
    NAME      => 'Panda::Lib',
    PREREQ_PM => {'Panda::Export' => 0},
    CPLUS     => 1,
    SRC       => 'src',
    INC       => '-Isrc',
    BIN_DEPS  => 'Panda::XS',
    BIN_SHARE => {
        INCLUDE  => {'src' => '/'},
        TYPEMAPS => {'typemap' => ''},
    },
    TEST_REQUIRES => {'Test::Fatal' => 0, 'JSON::XS' => 0},
    #OPTIMIZE  => '-g -O2',
);
