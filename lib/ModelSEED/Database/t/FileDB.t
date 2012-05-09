# Unit tests for FileDB.pm
use strict;
use warnings;

use File::Temp qw(tempfile tempdir);
use Test::More;
use Try::Tiny;

use ModelSEED::Database::FileDB;

my $test_count = 0;
{
    my $dir = tempdir();
    my $db = ModelSEED::Database::FileDB->new({ directory => $dir });

    ok defined($db), "FileDB created successfully";

    # test the refstring handler for user types
    my $uref1 = 'user';
    my $uref2 = 'user.paul';
    my $uref3 = 'user.paul.test';

    is_deeply ModelSEED::Database::FileDB::_handle_refstring($uref1),
      { type => 'user' },
      "Handled user refstring (no user) correctly: $uref1";
    is_deeply ModelSEED::Database::FileDB::_handle_refstring($uref2),
      { type => 'user', id => 'paul' },
      "Handled user refstring (with user) correctly: $uref2";

    try {
        ModelSEED::Database::FileDB::_handle_refstring($uref3);
    } catch {
        ok 1, "Handled user refstring (extra alias, dies) correctly: $uref3";
    };

    my $uuid = '00000000-0000-0000-0000-000000000000';

    # test the refstring handler for obj types
    my $ref1 = 'biochemistry';
    my $ref2 = 'biochemistry.user';
    my $ref3 = 'biochemistry.user.alias';
    my $ref4 = 'biochemistry.' . $uuid;

    is_deeply ModelSEED::Database::FileDB::_handle_refstring($ref1),
      { type => 'biochemistry' },
      "Handled type refstring (no alias/uuid) correctly: $ref1";
    is_deeply ModelSEED::Database::FileDB::_handle_refstring($ref2),
      { type => 'biochemistry', id => { type => 'alias', user => 'user' }},
      "Handled type refstring (only user) correctly: $ref2";
    is_deeply ModelSEED::Database::FileDB::_handle_refstring($ref3),
      { type => 'biochemistry', id => { type => 'alias', user => 'user', alias => 'alias'}},
      "Handled type refstring (user/alias) correctly: $ref3";
    is_deeply ModelSEED::Database::FileDB::_handle_refstring($ref4),
      { type => 'biochemistry', id => { type => 'uuid', uuid => $uuid}},
      "Handled type refstring (uuid) correctly: $ref4";

    my $notype = 'notype';
    try {
        ModelSEED::Database::FileDB::_handle_refstring($notype);
    } catch {
        ok 1, "Handled unknown type in refstring (dies) correctly: $notype";
    };

    $test_count += 9;
}

done_testing($test_count);
