# Testing Biochemistry object
use Test::More;
use Test::Exception;
use Test::MockObject;

use File::Basename;
use JSON::Any;
use ModelSEED::MS::Biochemistry;
my $testCount = 0;

my ($bio, $data);
{
    # Need to have biochemistry-data.json file in same directory as this test.
    my $dataFile = File::Basename::dirname(__FILE__)."/biochemistry-object.json";
    ok (-f $dataFile), "Could not find $dataFile that contains biochemistry data!";
    local $/;
    open(my $fh, "<", $dataFile) || die("Could not open file $dataFile: $!");
    $text = <$fh>;
    close($fh);
    $j = JSON::Any->new(utf8 => 1);
    $data = $j->from_json($text);
    $bio = ModelSEED::MS::Biochemistry->new($data);
    ok defined($bio), "Create biochemistry from data in $dataFile";
    $testCount += 2;
}

# Test basic attributes
{
    ok defined($bio->uuid), "Should have uuid";
    ok defined($bio->modDate), "Should have modDate";
    ok defined($bio->locked), "Should have locked";
    ok defined($bio->public), "Should have public";
    ok defined($bio->name), "Should have name";
    $testCount += 5;
}

# Test access to relationships
{
    ok defined($bio->reactions), "Should have reactions";
    ok defined($bio->compounds), "Should have compounds";
    ok defined($bio->compartments), "Should have compartments";
    ok defined($bio->media), "Should have media";
    # TODO - compoundset reactionset
    $testCount += 4;
}

# Test getCompound
{
    my $cpd = $bio->compounds->[0];
    my $uuid = $cpd->uuid;
    my $id = $cpd->id;
    my $cpd2 = $bio->getCompound({ uuid => $uuid });
    my $cpd3 = $bio->getCompound({ id => $id });
    my $cpd4 = $bio->getCompound({ uuid => $uuid, id => $id });

    is_deeply $cpd2, $cpd, "Query for uuid should return same";
    is_deeply $cpd3, $cpd, "Query for id should return same";
    is_deeply $cpd4, $cpd, "Query for both uuid, id should return same";
    $testCount += 3;
}


# Testing save
{
    throws_ok { $bio->save } qr/No ObjectManager/, 'Throws exception without OM';
    ok !defined($bio->om), "Should not have OM with this object";
    # Now create a slim OM interface
    my $mockOM = Test::MockObject->new();
    $mockOM->mock("save", sub { return 1; });
    $mockOM->set_isa('ModelSEED::CoreApi');
    $bio->om($mockOM);
    ok $bio->save(), "Should return success from save call"; 
    $testCount += 3;
}
done_testing($testCount);
