# Unit tests for FileDB.pm 
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile tempdir);
use ModelSEED::Database::FileDB;

my $TYPE_META = "__type__";

my $testCount = 0;
# test initialization
{
    my $dir = tempdir();

    my $type = 'test';
    my $db = ModelSEED::Database::FileDB->new({ directory => $dir });

    ok defined $db, "Database successfully created";

    # Test methods for non-existant object
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

    is_deeply { test => "test0" x 10 }, $db->get_object($type, 0), "Object ok after add/remove";
    my $test = "test" . ($num-1);
    is_deeply { test => "$test" x 10 }, $db->get_object($type, $num-1), "Object ok after add/remove";
    is undef, $db->get_object($type, 1), "Object gone after delete";

    # now testing metadata
    $db->save_object($type, $id2, $o2);

    $db->set_metadata($type, $id2, '', {foo => 'bar'});
    is_deeply $db->get_metadata($type, $id2), {foo => 'bar'}, "Simple metadata test";

    $db->set_metadata($type, $id2, 'foo2', 'bar2');
    is_deeply $db->get_metadata($type, $id2),
      {foo => 'bar', foo2 => 'bar2'},
      "Added to existing metadata";
    is undef, $db->get_metadata($type, $id2, 'none'), "Non-existant metadata";

    $db->set_metadata($type, $id2, 'foo', {hello => 'world!'});
    is_deeply {hello => 'world!'}, $db->get_metadata($type, $id2, 'foo'),
	       "Overwrite existing metadata and get with selection";

    ok !$db->set_metadata($type, $id2, '', 'scalar'), "Overwrite whole metadata must provide hash";

    $db->remove_metadata($type, $id2, 'foo2');
    is undef, $db->get_metadata($type, $id2, 'foo2'), "Removed metadata successfully";

    $db->remove_metadata($type, $id2);
    is_deeply $db->get_metadata($type, $id2), {}, "Removed all metadata";

    $db->set_metadata($type, $id2, 'this.is.a', 'test');
    is_deeply {this => {is => {a => 'test'}}}, $db->get_metadata($type, $id2), "Saved nested metadata";
    is_deeply {a => 'test'}, $db->get_metadata($type, $id2, 'this.is'), "Got nested metadata";

    # test reserved type_meta
    is $db->get_metadata($type, $id2, $TYPE_META), undef, "Can't get type metadata";
    ok !$db->set_metadata($type, $id2, $TYPE_META, "test"), "Can't set type metadata";
    ok !$db->remove_metadata($type, $id2, $TYPE_META), "Can't remove type metadata";

    $testCount += 26;
}

# test find_objects
{
    my $dir = tempdir();

    my $db = ModelSEED::Database::FileDB->new({ directory => $dir });

    my $type1 = 'foo';
    my $type2 = 'bar';
    my $id1 = 'obj1';
    my $id2 = 'obj2';
    my $id3 = 'obj3';
    my $id4 = 'obj4';
    my $o1 = { hello => 'world1' };
    my $o2 = { hello => 'world2' };
    my $o3 = { hello => 'world3' };
    my $o4 = { hello => 'world4' };
    my $meta1 = {};
    my $meta2 = {};
    my $meta3 = {};
    my $meta4 = {};

    $db->save_object($type1, $id1, $o1);
    $db->save_object($type2, $id2, $o2);
    $db->save_object($type1, $id3, $o4);
    $db->save_object($type2, $id4, $o4);

    my $objs1 = {};
    map {$objs1->{$_} = 1} @{$db->find_objects($type1, "")};
    is_deeply $objs1, { $id1 => 1, $id3 => 1}, "Find objects works for empty query (type1)";

    my $objs2 = {};
    map {$objs2->{$_} = 1} @{$db->find_objects($type2, "")};
    is_deeply $objs2, { $id2 => 1, $id4 => 1}, "Find objects works for empty query (type2)";

    $testCount += 2;
}

done_testing($testCount);
