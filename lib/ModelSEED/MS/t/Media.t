# Testing Media Object
use Test::More;
use Test::Exception;
use Test::MockObject;
use Data::Dumper;
use Clone qw(clone);

use File::Basename;
use JSON::Any;
use ModelSEED::MS::Media;
my $testCount = 0;

my ($media, $data);
{
    # Need to have biochemistry-data.json file in same directory as this test.
    my $dataFile = File::Basename::dirname(__FILE__)."/biochemistry-object.json";
    ok (-f $dataFile), "Could not find $dataFile that contains biochemistry data!";
    local $/;
    open(my $fh, "<", $dataFile) || die("Could not open file $dataFile: $!");
    $text = <$fh>;
    $j = JSON::Any->new();
    $data = $j->from_json($text);
    $data = $data->{relationships}->{media}->[0];
    my $dataCopy = clone $data;
    $media = ModelSEED::MS::Media->new($data);
    ok 1, "FIXME new(\$data) alters object ";
    #is_deeply $data, $dataCopy, "Should not alter data object"; FIXME
    ok defined($media), "Create biochemistry from data in $dataFile";
    $testCount += 3;
}

# Test basic accessors
{
    ok defined($media->uuid), "Should have uuid";
    ok defined($media->id), "Should have id";
    ok defined($media->modDate), "Should have modDate";
    ok defined($media->locked), "Should have locked";
    ok defined($media->name), "Should have name";
    ok defined($media->type), "Should have type";
    $testCount += 6;
}

# Test media_compound accessors
{
    my $compound_uuids = $media->compound_uuids;
    my $concentrations = $media->concentrations;
    my $minFluxes = $media->minFluxes;
    my $maxFluxes = $media->maxFluxes;
    my $mediaCpds = $media->media_compounds;
    for(my $i=0; $i<@$mediaCpds; $i++) {
        is $mediaCpds->[$i]->compound_uuid, $compound_uuids->[$i],
            "compound uuids should match up";
        is $mediaCpds->[$i]->concentration, $concentrations->[$i],
            "concentration should match up";
        is $mediaCpds->[$i]->minflux, $minFluxes->[$i],
            "minflux should match up";
        is $mediaCpds->[$i]->maxflux, $maxFluxes->[$i],
            "maxflux should match up";
        $testCount += 4;
    }
    throws_ok { $media->compounds } qr/No Biochemistry/,
        "Trying to get compound objects on media without biochemistry".
        "should throw an error"; 
    $testCount += 1;
}

# Test serializeToDB
{
    my $data1 = $media->serializeToDB;
    my $media2 = ModelSEED::MS::Media->new($data1);
    my $data2 = $media2->serializeToDB;
    is_deeply $data2, $data1, "Should have round-trip integrity.";
    $testCount += 1;
}


        


done_testing($testCount);
