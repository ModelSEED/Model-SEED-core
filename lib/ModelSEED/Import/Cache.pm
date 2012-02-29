package ModelSEED::Import::Cache;
use strict;
use warnings;
use Moose;

has 'om' => (is => 'rw', required => 1, isa => 'ModelSEED::ObjectManager');
has 'importer' => (is => 'rw', isa => 'ModelSEED::Import', required => 1);

1;
