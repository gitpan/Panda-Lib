#!/usr/bin/perl
use 5.012;
use lib 'blib/lib', 'blib/arch';
use feature 'say';
use Benchmark qw/timethis timethese/;
use Panda::Lib qw/hash_merge clone fclone crypt_xor compare :const/;
use JSON::XS qw/encode_json decode_json/;
use Data::Dumper qw/Dumper/;
use Storable qw/dclone/;
use Devel::Peek;
use DBIx::Class;

say "START";

compare(qr/abc/, qr/abc1/);
exit;

{
    package ABCD;
#    use overload
#        '=='     => \&my_eq,
#        fallback => 1;
    
    sub new { my $class = shift; my @vals = @_; return bless \@vals, $class; }
    
    sub my_eq {
        my ($self, $other) = @_;
        return $self->[0] + $self->[1] == $other->[0] + $other->[1];
    }
}

my $o1 = new ABCD(2,3);
my $o2 = new ABCD(1,4);
my $o3 = new ABCD(3,4);

my $a = {map {$_ => $_} 'a'..'z'};
my $b = {map {$_ => $_} 'a'..'z'};
my $c = {map {$_ => ord($_)} 'a'..'z'};
my $d = {map {$_ => ord($_)} 'a'..'z'};
my $s1 = '{"max_qid"=>11,"clover"=>{"fillup_multiplier"=>"1.3","finish_date"=>12345676}}';
my $s2 = '{"clover"=>{"finish_date"=>12345676,"fillup_multiplier"=>"1.3"},"max_qid"=>11}';
$s1 = eval $s1;
$s2 = eval $s2;
my $e = {a => $o1, b => $o3};
my $f = {a => $o2, b => $o3};
my $x = [1..100];
my $y = [1..100];

compare($a, $b) for 1..3000000;

say compare($a, $b);
say compare($c, $d);
say compare($s1, $s2);
say compare($e, $f);
say compare($x, $y);

timethese(-1, {
    #array_simple     => sub { compare($x, $y); },
    hash_simple_strs => sub { compare($a, $b); },
    #hash_simple_nums => sub { compare($c, $d); },
    #hash_mixed       => sub { compare($s1, $s2); },
    #hash_objs        => sub { compare($e, $f); },
}) if 0;

__END__

package AAA;

sub clone { return (bless {b => 1 }, 'AAA') }

package main;

my $h = {a => 1};
my $o1 = bless {a => 1}, 'AAA';
my $o2 = bless {a => 1}, 'DBIx::Class';

timethis(-10, sub { clone($o1) });

exit;

bench_clone();

if (0) {
    my $h1 = encode_json({a => 1, b => 2, c => [1,2,3], d => {a => 1, b => 2, c => {a => 1, b => 2}, d => [12,13,14]}});
    my $h2 = encode_json({a => 1, b => 2, c => [1,2,3], d => {a => 1, b => 2, c => {a => 1, b => 2}, d => undef}});
    
    while (1) { 
        my $h1c = decode_json($h1); 
        my $h2c = decode_json($h2);
        hash_merge($h1c, $h2c, MERGE_COPY);
        #hash_merge($h1c, $h2c);
    }
    
    exit();
    
    #hash_merge_test();
    #exit();
}


if (0) {
    my $aa = {x => "string"};
    my $bb = {x => [], y => [], z => []};
    timethis(-1, sub {
        #hash_merge($aa, $bb, MERGE_COPY);
        hash_merge({x => "string", y => "string", z => "string"}, $bb);
    });
    #say Dumper($ret);
    
    exit();
}

sub bench_clone {
    my $prim1 = 1000;
    my $prim2 = 1.5;
    my $prim3 = "abcd";
    my $prim4 = "abcd" x 100000;
    
    my $arr_small = [1,2,3];
    my $arr_big   = [(1) x 10000];
    
    my $hash_small = {a => 1, b => 2.5, c => 3};
    my $hash_big   = {map {("abc$_" => $_)} 1..1000};
    
    my $mix_small = {a => 1, b => 2.5, c => [1,2,3], d => [1, {a => 1, b => 2}]};
    my $mix_big   = {map { ("abc$_" => $mix_small) } 1..1000};
    
    my $js = JSON::XS->new->utf8->allow_nonref;
    
    timethis(-1, sub { clone($mix_small) });
    timethis(-1, sub { clone($mix_small) });
    timethis(-1, sub { clone($mix_small) });
    timethis(-1, sub { clone($mix_small) });
    timethis(-1, sub { clone($mix_small) });
    
    timethese(-1, {
        smart_json => sub { state $a = encode_json($mix_small); decode_json($a) },
        mixsmall_panda => sub { clone($mix_small) },
    });
    
    say "clone";
    timethese(-1, {
        prim1 => sub { clone($prim1) },
        prim2 => sub { clone($prim2) },
        prim3 => sub { clone($prim3) },
        prim4 => sub { clone($prim4) },
        arrsm => sub { clone($arr_small) },
        arrbg => sub { clone($arr_big) },
        hashs => sub { clone($hash_small) },
        hashb => sub { clone($hash_big) },
        mixsm => sub { clone($mix_small) },
        mixbg => sub { clone($mix_big) },
    });
    
    
    say "clone_full";
    timethese(-1, {
        prim1 => sub { fclone($prim1) },
        prim2 => sub { fclone($prim2) },
        prim3 => sub { fclone($prim3) },
        prim4 => sub { fclone($prim4) },
        arrsm => sub { fclone($arr_small) },
        arrbg => sub { fclone($arr_big) },
        hashs => sub { fclone($hash_small) },
        hashb => sub { fclone($hash_big) },
        mixsm => sub { fclone($mix_small) },
        mixbg => sub { fclone($mix_big) },
    });    
    
    say "JSON";
    timethese(-1, {
        prim1 => sub { $js->decode($js->encode($prim1)) },
        prim2 => sub { $js->decode($js->encode($prim2)) },
        prim3 => sub { $js->decode($js->encode($prim3)) },
        prim4 => sub { $js->decode($js->encode($prim4)) },
        arrsm => sub { decode_json(encode_json($arr_small)) },
        arrbg => sub { decode_json(encode_json($arr_big)) },
        hashs => sub { decode_json(encode_json($hash_small)) },
        hashb => sub { decode_json(encode_json($hash_big)) },
        mixsm => sub { decode_json(encode_json($mix_small)) },
        mixbg => sub { decode_json(encode_json($mix_big)) },
    });
    
    say "storable";
    timethese(-1, {
        prim1 => sub { dclone([$prim1]) },
        prim2 => sub { dclone([$prim2]) },
        prim3 => sub { dclone([$prim3]) },
        prim4 => sub { dclone([$prim4]) },
        arrsm => sub { dclone($arr_small) },
        arrbg => sub { dclone($arr_big) },
        hashs => sub { dclone($hash_small) },
        hashb => sub { dclone($hash_big) },
        mixsm => sub { dclone($mix_small) },
        mixbg => sub { dclone($mix_big) },
    });
    
    exit();
}

sub hash_merge_test {
    my $h1d = {a => 1, b => 2, c => 3, d => 4};
    my $h1s = {c => 'c', d => 'd', e => 'e', f => 'f'};
    my $h2d = {a => 1, b => 2, c => {aa => 1, bb => 2}};
    my $h2s = {a => 10, d => 123, c => {cc => 3}};
    my $h3d = { map {$_ => ("0123456789" x 10000)} 1..1000 };
    my $h3s = { map {$_ => ("0123456789" x 10000)} 1000..2000 };
 
    timethese(-1, {
        xs1   => sub { hash_merge($h1d, $h1s) },
        perl1 => sub { merge_hash($h1d, $h1s) },
        xs2   => sub { hash_merge($h2d, $h2s) },
        perl2 => sub { merge_hash($h2d, $h2s) },
        xs3   => sub { hash_merge($h3d, $h3s) },
        perl3 => sub { merge_hash($h3d, $h3s) },
    });
}

sub merge_hash {
    my ($hash1, $hash2) = (shift, shift);

    while (my ($k, $v2) = each %$hash2) {
        my $v1 = $hash1->{$k};
        if (ref($v1) eq 'HASH' && ref($v2) eq 'HASH') { merge_hash($v1, $v2) }
        else { $hash1->{$k} = $v2 }
    }

    $hash2;
}

say "END";

1;
