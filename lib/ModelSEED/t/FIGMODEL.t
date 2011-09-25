#
#===============================================================================
#
#         FILE:  FIGMODEL.t
#
#  DESCRIPTION:  Unit and integration testing for FIGMODEL.pm base object
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Dr. Fritz Mehner (mn), mehner@fh-swf.de
#      COMPANY:  FH Südwestfalen, Iserlohn
#      VERSION:  1.0
#      CREATED:  07/06/11 18:11:15
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use ModelSEED::TestingHelpers;
use Test::More qw(no_plan);

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
