# Unit tests for ModelSEED::Database::Shock
use strict;
use warnings;
use Test::More;
use ModelSEED::Database::Shock;
use ModelSEED::Auth::Public;
use Data::Dumper;
my $test_count = 0;

# Basic object initialization
{
    my $shock = ModelSEED::Database::Shock->new({ host => 'localhost' });
    ok defined($shock), "Should create a class instance";
    $test_count += 3;
}

# Copying tests like in FileDB
{
    my $db = ModelSEED::Database::Shock->new({ host => 'localhost' });
    my $auth = ModelSEED::Auth::Public->new();
    # Test methods for non-existant object
    my $type = "test";

    my $id1 = 'obj1';
    my $id2 = 'obj2';
    my $o1 = { hello => 'world1', foo => 'bar1' };
    my $o2 = { hello => 'world2', foo => 'bar2' };

    ok !$db->has_object($type, $id1, $auth), "Database is empty";
    is undef, $db->get_object($type, $id1, $auth), "Cannot get non-existant object";
    ok !$db->delete_object($type, $id1, $auth), "Cannot delete non-existant object";

    ok $db->save_object($type, $id1, $o1, $auth), "Save object returns success";
    ok $db->has_object($type, $id1, $auth), "Has object after save";
    is_deeply $o1, $db->get_object($type, $id1, $auth), "Get object returns same object";
    ok !$db->save_object($type, $id1, $o1, $auth), "Cannot save object with existing id";
    ok $db->delete_object($type, $id1, $auth), "Successfully deleted object";
    ok !$db->has_object($type, $id1, $auth), "Object no longer found in database";

    # now test multiple saves/deletes
    my $large_id = 'obj3';
    my $large_obj = {};
    my $num = 100;
    for (my $i=0; $i<$num; $i++) {
        my $obj = { test => "test$i" x 10 };
        $large_obj->{"test$i"} = int(rand(100000)) x 10;
        $db->save_object($type, "$i", $obj);
    }

    $db->save_object($type, $large_id, $large_obj, $auth);
    is_deeply $large_obj, $db->get_object($type, $large_id, $auth), "Large object saved and read from database";

    for (my $i=1; $i<$num-1; $i++) {
        $db->delete_object($type, $i, $auth);
    }

    is_deeply { test => "test0" x 10 }, $db->get_object($type, "0", $auth), "Object ok after add/remove";
    my $test = "test" . ($num-1);
    is_deeply { test => "$test" x 10 }, $db->get_object($type, $num-1, $auth), "Object ok after add/remove";
    is undef, $db->get_object($type, 1, $auth), "Object gone after delete";

    $test_count += 16;
}


done_testing($test_count);
