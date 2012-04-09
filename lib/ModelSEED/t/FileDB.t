# Unit tests for FileDB.pm 
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile tempdir);
use ModelSEED::FileDB;

my $testCount = 0;
# test initialization
{
    my $dir = tempdir();

    my $db = ModelSEED::FileDB->new({filename => "$dir/foo"});
    ok defined $db, "Database successfully created";

    # Test methods for non-existant object
    my $id1 = 'obj1';
    my $id2 = 'obj2';
    my $o1 = { hello => 'world1', foo => 'bar1' };
    my $o2 = { hello => 'world2', foo => 'bar2' };

    ok !$db->has_object($id1), "Database is empty";
    is undef, $db->get_object($id1), "Cannot get non-existant object";
    ok !$db->delete_object($id1), "Cannot delete non-existant object";

    ok $db->save_object($id1, $o1), "Save object returns success";
    ok $db->has_object($id1), "Has object after save";
    is_deeply $o1, $db->get_object($id1), "Get object returns same object";
    ok !$db->save_object($id1, $o1), "Cannot save object with existing id";
    ok $db->delete_object($id1), "Successfully deleted object";
    ok !$db->has_object($id1), "Object no longer found in database";

    # now test multiple saves/deletes
    my $large_id = 'obj3';
    my $large_obj = {};
    my $num = 100;
    for (my $i=0; $i<$num; $i++) {
    	my $obj = { test => "test$i" x 10 };
	$large_obj->{"test$i"} = int(rand(100000)) x 10;
	$db->save_object("$i", $obj);
    }

    $db->save_object($large_id, $large_obj);
    is_deeply $large_obj, $db->get_object($large_id), "Large object saved and read from database";

    for (my $i=1; $i<$num-1; $i++) {
    	$db->delete_object($i);
    }

    is_deeply { test => "test0" x 10 }, $db->get_object(0), "Object ok after add/remove";
    my $test = "test" . ($num-1);
    is_deeply { test => "$test" x 10 }, $db->get_object($num-1), "Object ok after add/remove";
    is undef, $db->get_object(1), "Object gone after delete";

    # now testing metadata
    $db->save_object($id2, $o2);

    $db->set_metadata($id2, '', {foo => 'bar'});
    is_deeply {foo => 'bar'}, $db->get_metadata($id2), "Simple metadata test";

    $db->set_metadata($id2, 'foo2', 'bar2');
    is_deeply {foo => 'bar', foo2 => 'bar2'}, $db->get_metadata($id2), "Added to existing metadata";
    is undef, $db->get_metadata($id2, 'none'), "Non-existant metadata";

    $db->set_metadata($id2, 'foo', {hello => 'world!'});
    is_deeply {hello => 'world!'}, $db->get_metadata($id2, 'foo'),
	       "Overwrite existing metadata and get with selection";

    ok !$db->set_metadata($id2, '', 'scalar'), "Overwrite whole metadata must provide hash";

    $db->remove_metadata($id2, 'foo2');
    is undef, $db->get_metadata($id2, 'foo2'), "Removed metadata successfully";

    $db->remove_metadata($id2);
    is_deeply {}, $db->get_metadata($id2), "Removed all metadata";

    $db->set_metadata($id2, 'this.is.a', 'test');
    is_deeply {this => {is => {a => 'test'}}}, $db->get_metadata($id2), "Saved nested metadata";
    is_deeply {a => 'test'}, $db->get_metadata($id2, 'this.is'), "Got nested metadata";

    $testCount += 23;
}

done_testing($testCount);
