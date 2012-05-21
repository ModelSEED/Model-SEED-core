# Unit tests for ModelSEED::Database::MongoDB
use strict;
use warnings;
use Test::More;
use ModelSEED::Database::MongoDB;
use Data::Dumper;
my $test_count = 0;

{
    my $mongo = ModelSEED::Database::MongoDB->new({ db_name => 'test' });
    my $refs = {
        "biochemistry/chenry/master" => "biochemistry",
        "biochemistry/chenry/master/reactions" => "reactions",
        "biochemistry/chenry/master/reactions/550e8400-e29b-41d4-a716-446655440000" => "reactions",
        "biochemistry/550e8400-e29b-41d4-a716-446655440000" => "biochemistry",
        "biochemistry/550e8400-e29b-41d4-a716-446655440000/reactions" => "reactions",
        "biochemistry/550e8400-e29b-41d4-a716-446655440000/reactions/550e8400-e29b-41d4-a716-446655440000" => "reactions"
    };
    foreach my $ref (keys %$refs) {
        my $result = $refs->{$ref};
        my $struct = $mongo->refParse->parse($ref);
        is $mongo->_get_collection($struct), $result, "Should get correct collection";
        $test_count += 1;
    }
}


done_testing($test_count);
=cut

# Basic object initialization
{
    my $mongo = ModelSEED::Database::MongoDB->new({ db_name => 'test' });
    ok defined($mongo), "Should create a class instance";
    ok defined($mongo->conn), "Should have connection to database";
    ok defined($mongo->db), "Should have database object";
    $test_count += 3;
}

# Copying tests like in FileDB
{
    my $db = ModelSEED::Database::MongoDB->new({ db_name => 'test' });
    # Test methods for non-existant object
    my $type = "test";
    # Delete the collection to start, want a fresh slate
    $db->db->$type->drop();

    my $id1 = 'obj1';
    my $id2 = 'obj2';
    my $o1 = { hello => 'world1', foo => 'bar1' };
    my $o2 = { hello => 'world2', foo => 'bar2' };

    ok !$db->has_object($type, $id1), "Database is empty";
    is undef, $db->get_object($type, $id1), "Cannot get non-existant object";
    ok !$db->delete_object($type, $id1), "Cannot delete non-existant object";

    ok $db->save_object($type, $id1, $o1), "Save object returns success";
    ok $db->has_object($type, $id1), "Has object after save";
    is_deeply $o1, $db->get_object($type, $id1), "Get object returns same object";
    ok !$db->save_object($type, $id1, $o1), "Cannot save object with existing id";
    ok $db->delete_object($type, $id1), "Successfully deleted object";
    ok !$db->has_object($type, $id1), "Object no longer found in database";

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


done_testing($test_count);
