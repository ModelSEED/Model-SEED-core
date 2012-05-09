# Unit tests for KeyValueStore.pm
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile tempdir);
use ModelSEED::Database::FileDB::KeyValueStore;

my $TYPE_META = "__type__";

my $testCount = 0;
# test initialization
{
    my $dir = tempdir();

    my $type = 'test';
    my $kvstore = ModelSEED::Database::FileDB::KeyValueStore->new({ directory => $dir });

    ok defined $kvstore, "Database successfully created";

    # Test methods for non-existant object
    my $id1 = 'obj1';
    my $id2 = 'obj2';
    my $o1 = { hello => 'world1', foo => 'bar1' };
    my $o2 = { hello => 'world2', foo => 'bar2' };

    ok !$kvstore->has_object($type, $id1), "Database is empty";
    is undef, $kvstore->get_object($type, $id1), "Cannot get non-existant object";
    ok !$kvstore->delete_object($type, $id1), "Cannot delete non-existant object";

    ok $kvstore->save_object($type, $id1, $o1), "Save object returns success";
    ok $kvstore->has_object($type, $id1), "Has object after save";
    is_deeply $o1, $kvstore->get_object($type, $id1), "Get object returns same object";
    ok !$kvstore->save_object($type, $id1, $o1), "Cannot save object with existing id";
    ok $kvstore->delete_object($type, $id1), "Successfully deleted object";
    ok !$kvstore->has_object($type, $id1), "Object no longer found in database";

    # now test multiple saves/deletes
    my $large_id = 'obj3';
    my $large_obj = {};
    my $num = 100;
    for (my $i=0; $i<$num; $i++) {
        my $obj = { test => "test$i" x 10 };
        $large_obj->{"test$i"} = int(rand(100000)) x 10;
        $kvstore->save_object($type, "$i", $obj);
    }

    $kvstore->save_object($type, $large_id, $large_obj);
    is_deeply $large_obj, $kvstore->get_object($type, $large_id), "Large object saved and read from database";

    for (my $i=1; $i<$num-1; $i++) {
        $kvstore->delete_object($type, $i);
    }

    is_deeply { test => "test0" x 10 }, $kvstore->get_object($type, 0), "Object ok after add/remove";
    my $test = "test" . ($num-1);
    is_deeply { test => "$test" x 10 }, $kvstore->get_object($type, $num-1), "Object ok after add/remove";
    is undef, $kvstore->get_object($type, 1), "Object gone after delete";

    # now testing metadata
    $kvstore->save_object($type, $id2, $o2);

    $kvstore->set_metadata($type, $id2, '', {foo => 'bar'});
    is_deeply $kvstore->get_metadata($type, $id2), {foo => 'bar'}, "Simple metadata test";

    $kvstore->set_metadata($type, $id2, 'foo2', 'bar2');
    is_deeply $kvstore->get_metadata($type, $id2),
      {foo => 'bar', foo2 => 'bar2'},
      "Added to existing metadata";
    is undef, $kvstore->get_metadata($type, $id2, 'none'), "Non-existant metadata";

    $kvstore->set_metadata($type, $id2, 'foo', {hello => 'world!'});
    is_deeply {hello => 'world!'}, $kvstore->get_metadata($type, $id2, 'foo'),
               "Overwrite existing metadata and get with selection";

    ok !$kvstore->set_metadata($type, $id2, '', 'scalar'), "Overwrite whole metadata must provide hash";

    $kvstore->remove_metadata($type, $id2, 'foo2');
    is undef, $kvstore->get_metadata($type, $id2, 'foo2'), "Removed metadata successfully";

    $kvstore->remove_metadata($type, $id2);
    is_deeply $kvstore->get_metadata($type, $id2), {}, "Removed all metadata";

    $kvstore->set_metadata($type, $id2, 'this.is.a', 'test');
    is_deeply {this => {is => {a => 'test'}}}, $kvstore->get_metadata($type, $id2), "Saved nested metadata";
    is_deeply {a => 'test'}, $kvstore->get_metadata($type, $id2, 'this.is'), "Got nested metadata";

    # test reserved type_meta
    is $kvstore->get_metadata($type, $id2, $TYPE_META), undef, "Can't get type metadata";
    ok !$kvstore->set_metadata($type, $id2, $TYPE_META, "test"), "Can't set type metadata";
    ok !$kvstore->remove_metadata($type, $id2, $TYPE_META), "Can't remove type metadata";

    $testCount += 26;
}

# test find_objects
{
    my $dir = tempdir();

    my $kvstore = ModelSEED::Database::FileDB::KeyValueStore->new({ directory => $dir });

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
    my $meta1 = { string => 'yes', test => 'what' };
    my $meta2 = { size => 100 };
    my $meta3 = { size => 50 };
    my $meta4 = { size => 10 };

    $kvstore->save_object($type1, $id1, $o1);
    $kvstore->save_object($type2, $id2, $o2);
    $kvstore->save_object($type1, $id3, $o4);
    $kvstore->save_object($type2, $id4, $o4);

    $kvstore->set_metadata($type1, $id1, '', $meta1);
    $kvstore->set_metadata($type2, $id2, '', $meta2);
    $kvstore->set_metadata($type1, $id3, '', $meta3);
    $kvstore->set_metadata($type2, $id4, '', $meta4);

    my $objs = {};
    map {$objs->{$_} = 1} @{$kvstore->find_objects($type1)};
    is_deeply $objs, { $id1 => 1, $id3 => 1}, "Find objects works for empty query (type1)";

    $objs = {};
    map {$objs->{$_} = 1} @{$kvstore->find_objects($type2)};
    is_deeply $objs, { $id2 => 1, $id4 => 1}, "Find objects works for empty query (type2)";

    $objs = {};
    map {$objs->{$_} = 1} @{$kvstore->find_objects($type1, { string => 'yes' })};
    is_deeply $objs, { $id1 => 1 }, "Find objects (string 'eq')";

    $objs = {};
    map {$objs->{$_} = 1} @{$kvstore->find_objects($type1, { size => 50 })};
    is_deeply $objs, { $id3 => 1 }, "Find objects (numeric '==')";

    $objs = {};
    map {$objs->{$_} = 1} @{$kvstore->find_objects($type2, { size => {'$gt' => 0} })};
    is_deeply $objs, { $id2 => 1, $id4 => 1 }, "Find objects (numeric '>')";

    $objs = {};
    map {$objs->{$_} = 1} @{$kvstore->find_objects($type2, { size => {'$gt' => 0, '$lte' => 10} })};
    is_deeply $objs, { $id4 => 1 }, "Find objects (numeric '> and <=')";

    $objs = {};
    map {$objs->{$_} = 1} @{$kvstore->find_objects($type1, { string => 'yes', test => 'no' })};
    is_deeply $objs, {}, "Find objects (string multiple 'eq')";

    $objs = {};
    map {$objs->{$_} = 1} @{$kvstore->find_objects($type1, { string => 'yes', test => 'what' })};
    is_deeply $objs, { $id1 => 1 }, "Find objects (string multiple 'eq')";

    $testCount += 8;
}

done_testing($testCount);
