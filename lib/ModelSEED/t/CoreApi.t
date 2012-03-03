use strict;
use warnings;
use Test::More;
use JSON::Any;
use File::Basename;
use ModelSEED::TestingHelpers;
use ModelSEED::MS::Biochemistry;

my $testCount = 0;
my $helper = ModelSEED::TestingHelpers->new();
my $api = $helper->getDebugCoreApi();
$api->_initOM();
warn $api->{om}->database;

my ($bio);
{
    ok defined $api->{om}, "Should have OM after call to _initOM";

    # Need to have biochemistry-data.json file in same directory as this test.
    my $dataFile = File::Basename::dirname(__FILE__)."/../MS/t/biochemistry-object.json";
    ok -f $dataFile, "Could not find $dataFile that contains biochemistry data!";
    local $/;
    open(my $fh, "<", $dataFile) || die("Could not open file $dataFile: $!");
    my $text = <$fh>;
    close($fh);
    my $j = JSON::Any->new(utf8 => 1);
    my $data = $j->from_json($text);
    $bio = ModelSEED::MS::Biochemistry->new($data);
    $bio->om($api);

    $testCount += 2;
}

{
    $bio->save();
}

done_testing($testCount);
