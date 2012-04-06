#
#===============================================================================
#
#         FILE: FileDB.t
#
#  DESCRIPTION: Tests for the FileDB
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Scott Devoid (), devoid@ci.uchicago.edu
#      COMPANY: University of Chicago / Argonne Nat. Lab.
#      VERSION: 1.0
#      CREATED: 03/21/2012 14:03:48
#     REVISION: ---
#===============================================================================
use strict;
use warnings;
use ModelSEED::FileDB;
use File::Temp qw(tempdir);
use File::Basename qw(dirname);
use Test::More;
use Test::Exception;
use Data::UUID;
my $testCount = 0;

# Test initalization, basic expectations
{
    my $dir = tempdir();
    my $db = ModelSEED::FileDB->new({directory => $dir});
    ok defined($db), "Should initalize correctly";
    ok defined($db->indexes), "Should have indexes";
    ok defined($db->types),   "Should have types";
    foreach my $type (@{$db->types}) {
        my $idx = $db->indexes->{$type};
        ok defined($idx), "Should have index for type $type";
        is(dirname($idx->filename), $db->directory,
            "Should have existing file for index $type : "
                . $db->indexes->{$type}->filename);
        $testCount += 2;
    }
    $testCount += 3;
}

# Test missing directory
{
    my $dir = tempdir();
    rmdir $dir;
    dies_ok { ModelSEED::FileDB->new({directory => $dir}) }
    "Initialize on missing directory should die";
    $testCount += 1;
}

# Test Basic query behavior (taken from FileDB::FileIndex.t)
{
    my $dir   = tempdir();
    my $types = [qw(animal vegetable mineral)];
    my $db    = ModelSEED::FileDB->new({directory => $dir, types => $types});
    is_deeply $db->types, $types, "Types should be same";
    my $uuid = Data::UUID->new()->create_str();
    my $o1   = {uuid => $uuid, name => 'llama'};
    my $rtv  = $db->save_object('animal', {object => $o1, user => 'alice'});
    ok defined($rtv), "Should return from save_object";
    my $o1Copy = $db->get_object('animal', {user => 'alice', uuid => $uuid});
    ok $db->has_object('animal', {user => 'alice', uuid => $uuid}),
        "Should have object that we just saved";
    is_deeply $o1Copy, $o1, "Should get back llama!";
    $o1->{name} = 'bear';
    my $newUUID
        = $db->save_object('animal', {user => 'alice', object => $o1});
    isnt $newUUID, $uuid, "Overwrite should actually create new object";
    ok $db->has_object('animal', {user => 'alice', uuid => $uuid}),
        "Should still have object that we saved";
    ok $db->has_object('animal', {user => 'alice', uuid => $newUUID}),
        "Should also have object that we re-saved";
    $testCount += 7;
}
done_testing($testCount);
