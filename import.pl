#!/usr/bin/perl 
use strict;
use warnings;
use Data::Dumper;
use ModelSEED::ModelSEEDScripts::ContinuousDataImporter;

my $importer = ModelSEED::ModelSEEDScripts::ContinuousDataImporter->new({
    DATABASE => "/home/devoid/test.db",
    DRIVER   => "SQLite",
});

my $dir = "$ENV{HOME}/mapping/";

my $ctx = {};
$importer->printDBMappingsToDir($dir);
my $biochemObj = $importer->importBiochemistryFromDir($dir, 'master', 'main');
my $mappingObj = $importer->importMappingFromDir($dir, $biochemObj, 'master', 'main');

