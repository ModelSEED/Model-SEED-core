# Unit tests for ModelSEED::Database::MongoDB
use strict;
use warnings;
use Test::More;
use ModelSEED::Database::MongoDB;
use ModelSEED::Auth::Basic;
use ModelSEED::Auth::Public;
use ModelSEED::Reference;
use Data::UUID;
use Data::Dumper;
my $test_count = 0;

sub _uuid {
    return Data::UUID->new->create_str();
}

# Basic object initialization
{
    my $mongo = ModelSEED::Database::MongoDB->new({ db_name => 'test' });
    ok defined($mongo), "Should create a class instance";
    ok defined($mongo->conn), "Should have connection to database";
    ok defined($mongo->db), "Should have database object";
    $test_count += 3;
}

{
    my $rules = {
        biochemistry => {
            "compounds" => {
                collection => "compounds",
                parent_tag => "_parent_biochemistry",
                type       => "array"
            }
        }
    };
    my $db = ModelSEED::Database::MongoDB->new( db_name => 'test', split_rules => $rules);
    my $type = "biochemistry";
    # Delete the database to get it clean and fresh
    $db->db->drop();
    my $ref1 = ModelSEED::Reference->new({
        ref => "biochemistry/alice/one"
    });
    my $ref2 = ModelSEED::Reference->new({
        ref => "biochemistry/alice/two"
    });
    my $auth = ModelSEED::Auth::Basic->new({
            username => "alice",
            password => "password",
    });
    my $pub = ModelSEED::Auth::Public->new();
    my $obj1 = { uuid => _uuid(), compounds => [{ uuid => _uuid() }] };
    my $obj2 = { uuid => _uuid(), compounds => [{ uuid => _uuid() }] };
    # Tests on non-existant objects
    ok !$db->has_data($ref1), "Database is empty";
    is undef, $db->get_data($ref1, $auth), "Cannot get non-existant object";
    ok !$db->delete_data($ref1, $auth), "Cannot delete non-existant object";
    $test_count += 3;

    # Tests on existing objects
    ok $db->save_data($ref1, $obj1, $auth), "Save object returns success";
    ok $db->has_data($ref1, $auth), "Has object after save";
    is_deeply $db->get_data($ref1, $auth), $obj1, "Get object returns same object";
    $test_count += 3;

    # Test permissions, not authorized
    ok !$db->has_data($ref1, $pub), "Test has_data, unauthorized";
    is undef, $db->get_data($ref1, $pub), "Test get_data, unauthorized";
    ok !$db->save_data($ref1, $obj2, $pub), "Shouldn't be able to save with another person's alias";
    is_deeply $db->get_data($ref1, $auth), $obj1, "Unauthorized save did not go through";
    $test_count += 4;

    # Test permissons, set to public (unauthorized)
    ok !$db->set_public($ref1, 1, $pub), "set_public unauthorized should fail";
    ok !$db->add_viewer($ref1, 'bob', $pub), "remove_viewer unauthorized should fail";
    ok !$db->remove_viewer($ref1, 'bob', $pub), "add_viewer unauthorized should fail";
    ok !$db->alias_owner($ref1, $pub), "getting alias owner, unauthorized should fail";
    ok !$db->alias_viewers($ref1, $pub), "getting alias viewers, unauthorized should fail";
    ok !$db->alias_public($ref1, $pub), "getting alias public, unauthorized should fail";
    ok !$db->alias_uuid($ref1, $pub), "getting alias uuid, unauthorized should fail";
    $test_count += 7;

    # Set permissions to public, authorized
    ok $db->set_public($ref1, 1, $auth), "set_public sould return success, auth";
    ok $db->alias_public($ref1, $auth), "alias_public sould return success, auth";
    is_deeply $db->alias_viewers($ref1, $auth), [], "no viewers on new alias";
    ok $db->add_viewer($ref1, "bob", $auth), "add_vewier should return success, auth"; 
    is_deeply $db->alias_viewers($ref1, $auth), ["bob"], "no viewers on new alias";
    is $db->alias_owner($ref1, $auth), "alice", "owner should be right on alias";
    $test_count += 6;

    # Test getting, for perm: public
    ok $db->has_data($ref1, $pub), "Test has_data, unauthorized, now public";
    is_deeply $db->get_data($ref1, $pub), $obj1, "Test get_data, unauthorized, now public";
    ok !$db->save_data($ref1, $obj2, $pub), "Shouldn't be able to save with another person's alias";
    is_deeply $db->get_data($ref1, $pub), $obj1, "Unauthorized save did not go through";
    $test_count += 4;

    # Test alter permissiosn, public, unauthorized
    ok !$db->set_public($ref1, 1, $pub), "set_public public, unauthorized should fail";
    ok !$db->add_viewer($ref1, 'bob', $pub), "remove_viewer public, unauthorized should fail";
    ok !$db->remove_viewer($ref1, 'bob', $pub), "add_viewer public, unauthorized should fail";
    is $db->alias_owner($ref1, $pub), "alice", "getting alias owner, public, unauthorized should work";
    is_deeply $db->alias_viewers($ref1, $pub), ["bob"], "getting alias viewers, public, unauthorized should work";
    is $db->alias_public($ref1, $pub), 1, "getting alias public, public, unauthorized should work";
    ok $db->alias_uuid($ref1, $pub), "getting alias uuid, public, unauthorized should work";
    $test_count += 7;

    # Test permissions for bob
    my $bob = ModelSEED::Auth::Basic->new({ username => "bob", password => "password" });
    $db->set_public($ref1, 0, $auth);
    is $db->alias_public($ref1, $auth), 0, "Should set correctly";
    ok $db->has_data($ref1, $bob), "Test has_data, bob";
    is_deeply $db->get_data($ref1, $bob), $obj1, "Test get_data, bob";
    ok !$db->save_data($ref1, $obj2, $bob), "Shouldn't be able to save with another person's alias";
    is_deeply $db->get_data($ref1, $bob), $obj1, "Unauthorized save did not go through";

    $test_count += 5;
}
=cut
    # now test multiple saves/deletes
    my $large_id = 'obj3';
    my $large_obj = {};
    my $num = 100;
    for (my $i=0; $i<$num; $i++) {
        my $obj = { test => "test$i" x 10 };
        $large_obj->{"test$i"} = int(rand(100000)) x 10;
        $db->save_object($type, "$i", $obj);
    }

    $db->save_object($type, $large_id, $large_obj);
    is_deeply $large_obj, $db->get_object($type, $large_id), "Large object saved and read from database";

    for (my $i=1; $i<$num-1; $i++) {
        $db->delete_object($type, $i);
    }

    is_deeply { test => "test0" x 10 }, $db->get_object($type, "0"), "Object ok after add/remove";
    my $test = "test" . ($num-1);
    is_deeply { test => "$test" x 10 }, $db->get_object($type, $num-1), "Object ok after add/remove";
    is undef, $db->get_object($type, 1), "Object gone after delete";

    # now testing metadata
    $db->save_object($type, $id2, $o2);

    $db->set_metadata($type, $id2, '', {foo => 'bar'});
    is_deeply {foo => 'bar'}, $db->get_metadata($type, $id2), "Simple metadata test";

    $db->set_metadata($type, $id2, 'foo2', 'bar2');
    is_deeply {foo => 'bar', foo2 => 'bar2'}, $db->get_metadata($type, $id2), "Added to existing metadata";
    is undef, $db->get_metadata($type, $id2, 'none'), "Non-existant metadata";

    $db->set_metadata($type, $id2, 'foo', {hello => 'world!'});
    is_deeply {hello => 'world!'}, $db->get_metadata($type, $id2, 'foo'),
	       "Overwrite existing metadata and get with selection";

    ok !$db->set_metadata($type, $id2, '', 'scalar'), "Overwrite whole metadata must provide hash";

    $db->remove_metadata($type, $id2, 'foo2');
    is undef, $db->get_metadata($type, $id2, 'foo2'), "Removed metadata successfully";

    $db->remove_metadata($type, $id2);
    is_deeply {}, $db->get_metadata($type, $id2), "Removed all metadata";

    $db->set_metadata($type, $id2, 'this.is.a', 'test');
    is_deeply {this => {is => {a => 'test'}}}, $db->get_metadata($type, $id2), "Saved nested metadata";
    is_deeply {a => 'test'}, $db->get_metadata($type, $id2, 'this.is'), "Got nested metadata";

    $test_count += 23;
}
=cut


done_testing($test_count);
