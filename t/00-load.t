#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'ModelSeedCore' ) || print "Bail out!\n";
}

diag( "Testing ModelSeedCore $ModelSeedCore::VERSION, Perl $], $^X" );
