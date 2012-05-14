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
use ModelSEED::Store::Private;
use Test::More tests => 4;                      # last test to print


my $pvt = ModelSEED::Store::Private->new();

my $store = ModelSEED::Store->new({ username => "sdevoid", password => "marcopolo", private => $pvt});
ok defined $store, "Should create class";
ok defined $store->user, "Should create user object";

my $bio = $store->create("Biochemistry");
ok defined $bio, "Should create biochemistry object";
is $store, $bio->parent(), "Parent of created object should be the store";



