# Tests for Compartment object
use Test::More;
use ModelSEED::MS::Compartment;
my $testCount = 0;

# Test basic initialization with raw data
{
    my $d1 = { id => 'c', name => 'Cytosol' };
    my $d2 = { id => 'e', name => 'Extracellular', locked => 1 };
    $o1 = ModelSEED::MS::Compartment->new($d1);
    $o2 = ModelSEED::MS::Compartment->new($d2);
    ok defined($o1), "Should get object back";
    ok defined($o2), "Should get object back";
    is $o1->id, $d1->{id}, "Should have same id.";
    is $o1->name, $d1->{name}, "Should have same name.";
    is $o1->locked, 0, "Should not be locked";
    is $o2->id, $d2->{id}, "Should have same id.";
    is $o2->name, $d2->{name}, "Should have same name.";
    is $o2->locked, 1, "Should be locked";
    ok defined($o1->uuid), "should have uuid if we want it.";
    ok defined($o2->uuid), "should have uuid if we want it.";
    ok defined($o1->modDate), "should have modDate if we want it.";
    $testCount += 11;
}


done_testing($testCount);

