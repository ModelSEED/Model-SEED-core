# Unit tests for Private.pm
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile tempdir);
use ModelSEED::Store::Private;
use ModelSEED::MS::User;

my $RESERVED_META = "__system__";

my $testCount = 0;
# test initialization
{
    my $dir = tempdir();

    my $user1 = 'pfrybarger';
    my $user_obj1 = ModelSEED::MS::User->new({
        login => $user1,
        password => 'pass'
    });
    my $user2 = 'chenry';
    my $user_obj2 = ModelSEED::MS::User->new({
        login => $user2,
        password => 'pass'
    });
    my $type = 'test';
    my $alias1 = "$user1/main";
    my $alias2 = "$user2/test";

    my $private = ModelSEED::Store::Private->new({
	db_class  => 'ModelSEED::Database::FileDB',
	db_config => {
	    directory => $dir
	}
     });

    ok defined $private, "Private data store successfully created";
    ok !$private->has_object($user1, $type, $alias1), "No objects in database";

    ok $private->create_user($user_obj1), "Saved user to database";
    is_deeply $user_obj1->serializeToDB,
      $private->get_user($user1)->serializeToDB,
      "Got user from database";

    my $obj1 = {
	hello => 'world',
	deep => { hash => { of => { arbitrary => 'length' } } }
    };

    my $obj2 = {
	foo => 'bar'
    };

    ok $private->save_object($user1, $type, $alias1, $obj1), "Saved object to database";

    my $data = $private->get_data($user1, $type, $alias1);

    if (!defined($data)) {
        die "Nope";
    }

    is_deeply $private->get_data($user1, $type, $alias1), $obj1, "Got object from database";

    $private->create_user($user_obj2);
    ok !$private->has_object($user2, $type, $alias1), "User 2 does not have permission on object";

    ok $private->add_viewer($user1, $type, $alias1, $user2), "add_viewer returned success";
    is_deeply $obj1, $private->get_data($user2, $type, $alias1), "User 2 has permission on object";

    ok !$private->save_object($user2, $type, $alias1, $obj1), "User can't save object to another users alias space";

    $private->save_object($user2, $type, $alias2, $obj1);
    is_deeply $obj1, $private->get_data($user2, $type, $alias2), "User can save to own alias space";

    # test get_object (not only get_data)

    # test parents/ancestors
    #    $private->save_object($user1, $type, $alias1, $obj2);

    # test get_aliases_for_type
    my $aliases = {};
    for (my $i=0; $i<20; $i++) {
	$aliases->{"alias_$i"} = 1;
	$private->save_object($user1, 'my_type', "$user1/alias_$i", {
	    "hello_$i" => "world_$i"
        })
    }

    my $ret_aliases = {};
    map {$ret_aliases->{$_} = 1} @{$private->get_aliases_for_type($user1, 'my_type')};

    is_deeply $aliases, $ret_aliases, "Testing get_aliases_for_type";

    $private->set_public($user1, $type, $alias1, 1);
    ok $private->has_object('public', $type, $alias1), "Public objects accessible by anyone";

    # test metadata
    is $private->get_metadata($user1, $type, $alias1, $RESERVED_META), undef,
      "Can't get system metadata";
    ok !$private->set_metadata($user1, $type, $alias1, $RESERVED_META, "test"),
      "Can't set system metadata";
    ok !$private->remove_metadata($user1, $type, $alias1, $RESERVED_META),
      "Can't remove system metadata";

    $private->set_metadata($user1, $type, $alias1, "size", "1000");
    is $private->get_metadata($user1, $type, $alias1, "size"), "1000",
      "Saved metadata successfully";

    $private->remove_metadata($user1, $type, $alias1, "size");
    is $private->get_metadata($user1, $type, $alias1, "size"), undef,
      "Removed metadata successfully";

    $testCount += 18;
}

done_testing($testCount);
