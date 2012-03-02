# Testing Biochemistry object
use Test::More;
use Test::Exception;
use Test::MockObject;
use Test::Deep;
use Data::Dumper;
use Clone qw(clone);

use File::Basename;
use JSON::Any;
use ModelSEED::MS::Biochemistry;
my $testCount = 0;

# Simple subroutine that calls Test::Deep
# bag() on arrays in a deep datastructure.
# FIXME - right now locking up
sub bagIt {
    my $obj = shift;
    my $ref = ref($obj);
    if ($ref eq 'ARRAY') {
        return Test::Deep::bag(
            map { $_ = bagIt($_) }
            @$obj
        );
    } elsif ($ref eq 'HASH') {
        return {
            map { $_ => bagIt( $obj->{$_} ) }
            keys %$obj
        };
    } else {
        return $obj;
    }
}

my ($bio, $data);
{
    # Need to have biochemistry-data.json file in same directory as this test.
    my $dataFile = File::Basename::dirname(__FILE__)."/biochemistry-object.json";
    ok -f $dataFile, "Could not find $dataFile that contains biochemistry data!";
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

# Testing serializeToDB
{
    my $serial1 = $bio->serializeToDB();
    my $clone = clone $serial1;
    my $bio2 = ModelSEED::MS::Biochemistry->new($clone);
    my $serial2 = $bio2->serializeToDB();
    $serial1 = bagIt($serial1);
    #$serial2 = bagIt($serial2);
    cmp_deeply $serial2, $serial1, "serializeToDB should have round trip integrity";
    $testCount += 1;
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
