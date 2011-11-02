#
#===============================================================================
#
#         FILE:  FIGMODELTable.t
#
#
#       AUTHOR:  Scott Devoid (sdevoid@gmail.com) 
#      VERSION:  1.0
#      CREATED:  05/03/11 18:04:03
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Test::More plan => 15;
use File::Temp qw(tempfile);
use ModelSEED::FIGMODEL::FIGMODELTable;
use Data::Dumper;

# Testing FIGMODELdata / FIGMODELdatabase interface
{
    my ($tbl_one_fh, $tbl_one_filename) = tempfile(UNLINK => 0);
    $tbl_one_fh->close();
    my $tbl_one = ModelSEED::FIGMODEL::FIGMODELTable->new(['name', 'phone', 'address', 'id'], $tbl_one_filename, ['name', 'id'], "\t", ";");
    $tbl_one->add_row({name => ['Scott'], phone => ["3121234567"], address => ["1 Bar Way", "Chicago, IL 60673"], id => ['devoid']});
    $tbl_one->add_row({name => ['Joe'], address => ["2 Bar Way", "Chicago, IL 60673"], id => ['joe']});
    $tbl_one->add_row({name => ['Joe'], address => ["Foo St.", "Amsterdam, NL"], id => ['jnl']});
    my $all = $tbl_one->get_objects();
    ok scalar(@$all) == 3, "got ".scalar(@$all)." objects instead of 3!";
    my $obj = $tbl_one->get_object({name => 'Scott'});
    ok defined($obj), "could not get object that should be there!";
    ok $obj->name() eq 'Scott', "could not do atttribute() getter!";
    ok scalar(keys %{$obj->attributes()}) == 4, "should be 4 attributes for object, got " . scalar(keys %{$obj->attributes()}) ."!";
    $obj->name('Bob');
    ok $obj->name() eq 'Bob', "change of attribute did not work!";
    my $obj2 = $tbl_one->get_object({name => 'Bob'});
    ok defined($obj2), "could not find updated result!";
    my $obj3 = $tbl_one->create_object({name => 'Scott', phone => "3121234577", id => 'sdevoid'});
    ok !defined($obj3->address()), "undefined attribute does not return undefined after create_object!";
    ok $obj3->id() eq 'sdevoid', "defined attribute does not return proper value after create_object!";
    my $obj4 = $tbl_one->get_object({id => 'sdevoid'});
    ok defined($obj4), "could not query object that was created with create_object!";
    ok $obj4->phone() eq "3121234577", "object created wtih create_object does not return proper value on query!";
    $obj4->delete(); 
    $obj4 = $tbl_one->get_object({id => 'sdevoid'});
    ok !defined($obj4), "object that was deleted was found again!";
    # testing saving and opening again
    open(my $fh2, "<", $tbl_one_filename);
    close($fh2);
    my $tbl_two = ModelSEED::FIGMODEL::FIGMODELTable::load_table($tbl_one_filename, "\t", ";", 0, ['name', 'id']);
    $all = $tbl_two->get_objects();
    ok scalar(@$all) == 3, "got ".scalar(@$all)." objects instead of 3!";
    $obj = $tbl_two->get_object({name => 'Bob'});
    ok defined($obj), "could not get object that should be there!";
    ok $obj->name() eq 'Bob', "could not do atttribute() getter!";
    ok scalar(keys %{$obj->attributes()}) == 4, "should be 4 attributes for object, got " . scalar(keys %{$obj->attributes()}) ."!";
}

