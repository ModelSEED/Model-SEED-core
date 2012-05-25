#
#===============================================================================
#
#         FILE: Store.t
#
#  DESCRIPTION: Tests for Store.pm
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Scott Devoid (), devoid@ci.uchicago.edu
#      COMPANY: University of Chicago / Argonne Nat. Lab.
#      VERSION: 1.0
#      CREATED: 04/30/2012 17:32:46
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use ModelSEED::Store;
use ModelSEED::Auth::Basic;
use Test::More tests => 4;                      # last test to print


my $auth  = ModelSEED::Auth::Basic->new(username => "bob", password => "password");
my $store = ModelSEED::Store->new(auth => $auth);
ok defined $store, "Should create class";
ok defined $store->auth, "Should create auth object";

my $bio = $store->create("Biochemistry");
ok defined $bio, "Should create biochemistry object";
is $store, $bio->parent(), "Parent of created object should be the store";



