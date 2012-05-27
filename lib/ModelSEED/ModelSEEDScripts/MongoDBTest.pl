use JSON::Any;
use strict;
use Data::Dumper;
use URI;
use ModelSEED::Database::MongoDBSimple;
use ModelSEED::Auth::Basic;
use ModelSEED::Store;
use IO::Compress::Gzip qw(gzip);
use IO::Uncompress::Gunzip qw(gunzip);

print "Connecting to the database!\n";
my $db = ModelSEED::Database::MongoDBSimple->new({db_name => "modelObjectStore",host => "birch.mcs.anl.gov"});
my $auth = ModelSEED::Auth::Basic->new({username => "kbase",password => "kbase"});
my $store = ModelSEED::Store->new({auth => $auth,database => $db});

print "Loading the biochemistry!\n";
my $string;
my $gzipString;
open BIOCHEM, "</home/chenry/public_html/exampleObjects/FullBiochemistry.json.zip";#Check that this path works
read BIOCHEM,$gzipString,1000000000;#Note, I oversized the buffer to ensure we get the whole file
close BIOCHEM;
gunzip \$gzipString => \$string;#Unzipping the data
my $objectData = JSON::Any->decode($string);#Decoding the json

print "Saving the biochemistry!\n";
$store->save_data("biochemistry/kbase/default",$objectData);
$store->set_public("biochemistry/kbase/default",1);

print "Loading the mapping!\n";
open MAPPING, "</home/chenry/public_html/exampleObjects/FullMapping.json.zip";#Check that this path works
read MAPPING,$gzipString,1000000000;#Note, I oversized the buffer to ensure we get the whole file
close MAPPING;
gunzip \$gzipString => \$string;#Unzipping the data
$objectData = JSON::Any->decode($string);#Decoding the json

print "Saving the mapping!\n";
$store->save_data("mapping/kbase/default",$objectData);
$store->set_public("mapping/kbase/default",1);