use 5.012;
use warnings;
use Test::More;
use Panda::Lib;

my $i = 0;

# there must be no timeout
my $ok = Panda::Lib::timeout(sub { $i++ }, 1); 
ok($ok);
ok($i == 1);

# there must be timeout
$ok = Panda::Lib::timeout(sub { $i++; select undef, undef, undef, 0.2; $i++ }, 0.1);
ok(!$ok);
ok($i == 2);

done_testing();
