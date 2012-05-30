use strict;
use warnings;
use JSON::Any;
use ModelSEED::MS::Biochemistry;
use ModelSEED::MS::Mapping;
use ModelSEED::MS::Annotation;
use ModelSEED::MS::Model;
use ModelSEED::MS::Factories::SEEDFactory;
use Time::HiRes qw(time);
use IO::Compress::Gzip qw(gzip);
use IO::Uncompress::Gunzip qw(gunzip);
use ModelSEEDbootstrap;
use ModelSEED::FIGMODEL;

#Loading biochemistry
my $string;
my $directory = $figmodel->config("database root directory")->[0]."exampleObjects/";
open BIOCHEM, "<".$directory."biochemistry.json";
$string = join("\n",<BIOCHEM>);
close BIOCHEM;
my $objectData = JSON::Any->decode($string);
my $biochem = ModelSEED::MS::Biochemistry->new($objectData);
$biochem->setParents(undef);
print "Biochemistry loaded!\n";
#Loading mapping
open MAPPING, "<".$directory."mapping.json";
$string = join("\n",<MAPPING>);
close MAPPING;
$objectData = JSON::Any->decode($string);
my $mapping = ModelSEED::MS::Mapping->new($objectData);
$mapping->setParents(undef);
$mapping->biochemistry($biochem);
print "Mapping loaded!\n";
$mapping->buildSubsystemReactionSets();