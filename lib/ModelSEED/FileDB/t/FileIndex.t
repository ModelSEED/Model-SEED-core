# Unit tests for FileIndex.pm 
use strict;
use warnings;
use ModelSEED::FileDB::FileIndex;
use Test::More;
use File::Temp qw(tempfile tempdir);
use Data::UUID;
use Data::Dumper;
use Cwd qw(cwd);
my $testCount = 0;
{
    my $dir = tempdir();
    # Test for index-file creation
    my $db = ModelSEED::FileDB::FileIndex->new({filename => "$dir/foo"});
    ok defined $db, "Should get file index when index file not present.";
    # Test getting non-existant objects
    is $db->has_object({ uuid => 'foo'}), 0, "No objects defined";
    is $db->has_object({ user_alias => 'foo/bar'}), 0, "No objects defined";

    is $db->get_object({ uuid => 'foo'}), undef, "No objects defined";
    is $db->get_object({ user_alias => 'foo/bar'}), undef, "No objects defined";
    $testCount += 5;
}

# Test saving, getting, updating objects via uuid
{ 
    my $dir = tempdir();
    my $db = ModelSEED::FileDB::FileIndex->new({filename => "$dir/index"});
    my $uuid = Data::UUID->new()->create_str();
    my $o1 = { uuid => $uuid, name => 'foo' };
    my $rtv = $db->save_object({ object => $o1, user => 'alice'});
    my $cwd = cwd;
    # Save tests (new)
    is $uuid, $rtv, "Save returns uuid, new object has correct uuid";
    ok !-f "$cwd/$uuid", "Save does not save to current directory";
    # Get tests (existing)
    is $db->has_object({uuid => $uuid, user => 'alice'}), 1, "Should now have object";
    my $o1Copy = $db->get_object({ uuid => $uuid, user => 'alice'});
    is_deeply $o1Copy, $o1, "Should get back object with same structure";
    # Update the object
    my $o2 = $o1Copy;
    $o2->{name} = "bar";
    my $newUUID = $db->save_object({user => 'alice', object => $o1Copy});
    isnt $newUUID, $uuid, "Overwrite should actually create new object";
    my $o2Copy = $db->get_object({ uuid => $newUUID, user => 'alice'});
    is_deeply $o2, $o2Copy, "Should get back object with the same structure";
    $o1Copy = $db->get_object({ uuid => $uuid, user => 'alice'});
    is_deeply $o1Copy, $o1, "Should get back object with same structure";

    $testCount += 7;
}

{
    # Testing get_user_uuids
    my $dir = tempdir();
    my $db = ModelSEED::FileDB::FileIndex->new({filename => "$dir/index"});
    my $names = [ qw( alice bob charles ) ];
    my $ids = [ 0..3 ];
    foreach my $name (@$names) {
        foreach my $id (@$ids) {
            my $uuid = Data::UUID->new()->create_str();
            my $data = { uuid => $uuid, id => $id };
            my $d = $db->save_object({user => $name, object => $data});
            is $uuid, $d, "Should create new objects for each user";
            $testCount += 1;
        }
        my $ids = $db->get_user_uuids($name);
        is @$ids, 4, "Should get correct number of object uuids";
        $testCount += 1;
    }
}

# Test aliases, permissions, and deleting
{
    my $stuff = "";
}

# Test concurrency via forking

done_testing($testCount);
