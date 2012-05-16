#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'ModelSEED::FIGMODEL' ) || print "Bail out!\n";
}

diag( "Testing ModelSeedCore $ModelSEED::FIGMODEL::VERSION, Perl $], $^X" );
