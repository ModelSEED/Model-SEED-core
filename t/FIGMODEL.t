use strict;
use warnings;
use ModelSEED::TestingHelpers;
use Test::More tests => 3;

my $helper = ModelSEED::TestingHelpers->new();
my $fm = $helper->getDebugFIGMODEL();

# test authenticate / unathenticate
{
    ok $fm->user() eq "PUBLIC", "should return PUBLIC when not logged in";
    $fm->authenticate({ username => "alice", password => "alice"});
    ok $fm->user() eq "alice", "should correctly login as reviewer with authenticate()";
    $fm->logout();
    ok $fm->user() eq "PUBLIC", "should correctly log out with logout() and return PUBLIC as user"; 
}
