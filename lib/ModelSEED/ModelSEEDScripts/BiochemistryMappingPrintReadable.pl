use strict;
use warnings;
use JSON::Any;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Mapping;
use ModelSEED::MS::Annotation;
use ModelSEED::MS::Model;
use ModelSEED::MS::Factories::Annotation;
use Time::HiRes qw(time);

#Loading biochemistry
my $directory = "C:/Code/Model-SEED-core/data/exampleObjects/";
open BIOCHEM, "<".$directory."biochemistry.json";
my $string = join("\n",<BIOCHEM>);
close BIOCHEM;
my $objectData = JSON::Any->decode($string);
my $biochem = ModelSEED::MS::Biochemistry->new($objectData);
my $readable = $biochem->createReadableStringArray();
ModelSEED::utilities::PRINTFILE("c:/Code/Model-SEED-core/data/exampleObjects/biochemistry.readable",$readable);
#Loading mapping
open MAPPING, "<".$directory."mapping.json";
$string = join("\n",<MAPPING>);
close MAPPING;
$objectData = JSON::Any->decode($string);
my $mapping = ModelSEED::MS::Mapping->new($objectData);
$mapping->biochemistry($biochem);
$readable = $mapping->createReadableStringArray();
ModelSEED::utilities::PRINTFILE("c:/Code/Model-SEED-core/data/exampleObjects/mapping.readable",$readable);
