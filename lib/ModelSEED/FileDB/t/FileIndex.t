# Unit tests for FileIndex.pm 
use strict;
use warnings;
use ModelSEED::FileDB::FileIndex;
use Test::More;
use File::Temp qw(tempfile tempdir);
use Data::UUID;
use Data::Dumper;
use Cwd qw(cwd);
use Time::HiRes qw(time sleep);
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

# Testing get_user_uuids
{
    my $dir = tempdir();
    my $db = ModelSEED::FileDB::FileIndex->new({filename => "$dir/index"});
    my $names = [ qw( alice bob ) ];
    my $ids = [ 0..1 ];
    foreach my $name (@$names) {
        foreach my $id (@$ids) {
            my $uuid = Data::UUID->new()->create_str();
            my $data = { uuid => $uuid, id => $id };
            my $d = $db->save_object({user => $name, object => $data});
            is $uuid, $d, "Should create new objects for each user";
            $testCount += 1;
        }
        my $ids = $db->get_user_uuids($name);
        is @$ids, 2, "Should get correct number of object uuids";
        $testCount += 1;
    }
}

# Test aliases, permissions, and deleting
{
    my $dir = tempdir();
    my $db = ModelSEED::FileDB::FileIndex->new({filename => "$dir/index"});
    my $uuid = Data::UUID->new()->create_str();
    my $o1 = { uuid => $uuid, name => 'foo' };
    $db->save_object({ object => $o1, user => 'alice' });

    my $perm = { public => 0, users => { alice => { read => 1, admin => 1 }}};
    is_deeply $db->get_permissions({ user => 'alice', uuid => $uuid }), $perm,
        "Object has correct permissions after saving";

    ok !$db->has_object({ user => 'bob', uuid => $uuid }),
        "User cannot access object without permissions";

    ok !$db->delete_object({ user => 'bob', uuid => $uuid }),
        "User without permissions cannot delete object";
    is_deeply $db->get_object({ user => 'alice', uuid => $uuid }), $o1,
        "Object still exists after unauthorized delete";

    $perm->{users}->{bob} = {read => 1, admin => 0};
    $db->set_permissions({ user => 'alice', uuid => $uuid, permissions => $perm });
    ok $db->has_object({ user => 'bob', uuid => $uuid }), "Granting read permission works";

    ok !$db->set_permissions({ user => 'bob', uuid => $uuid, permissions => {} }),
        "User without admin cannot change permissions";

    $perm->{users}->{bob}->{admin} = 1;
    $db->set_permissions({ user => 'alice', uuid => $uuid, permissions => $perm });

    $perm->{public} = 1;
    ok $db->set_permissions({ user => 'bob', uuid => $uuid, permissions => $perm }),
        "Granting admin permissions works correctly";
    ok $db->has_object({ uuid => $uuid }), "Public objects can be read by anyone";

    $db->set_alias({ user => 'alice', uuid => $uuid, alias => 'master' });
    is_deeply $db->get_object({ user => 'alice', user_alias => 'alice/master' }), $o1,
        "Correct object returned by alias for user";
    is_deeply $db->get_object({ user_alias => 'alice/master' }), $o1,
        "Correct object returned by alias for public object";

    my $o2 = {hello => "world"};
    my $uuid2 = $db->save_object({ user => 'alice', object => $o2 });

    $db->delete_object({ user => 'alice', uuid => $uuid });
    ok !$db->has_object({ user => 'alice', uuid => $uuid }), "Deleting object, removed access";
    ok $db->has_object({ user => 'bob', uuid => $uuid }),
        "Deleting object, other user still has access";
    $db->delete_object({ user => 'bob', uuid => $uuid });
    ok !$db->has_object({ uuid => $uuid }), "Object removed from index";

    $db->rebuild_data;
    is_deeply $db->get_object({ user => 'alice', uuid => $uuid2 }), $o2,
        "Existing data ok after rebuild";

    my $o3 = {goodbye => "moon"};
    my $uuid3 = $db->save_object({ user => 'alice', object => $o3 });

    is_deeply $db->get_object({ user => 'alice', uuid => $uuid3 }), $o3,
        "Adding data ok after rebuild";

    $testCount += 15;
}

# Test concurrency via forking
{
    my $dir = tempdir();

    my $pid = fork();
    my $db = ModelSEED::FileDB::FileIndex->new({filename => "$dir/index"});

    if ($pid) {
	sleep 0.010;
	my $time = time;
	$db->get_object({ user => 'alice', uuid => '0' });
	cmp_ok time - $time, '>', 0.5, "Looks like concurrency (locking) is working";
    } else {
	# get a lock and sleep
	$db->_sleep_test(1);
	exit;
    }

    $testCount += 1;
}

done_testing($testCount);
