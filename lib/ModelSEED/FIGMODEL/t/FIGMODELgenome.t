#
#===============================================================================
#
#         FILE:  FIGMODELgenome.t
#
#  DESCRIPTION:  Testing for FIGMODELgenome.
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Christopher Henry (chenry@mcs.anl.gov)
#      CREATED:  09/25/11
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use Data::Dumper;
use lib $ENV{MODEL_SEED_CORE}."/config/";
use ModelSEEDbootstrap;
use ModelSEED::FIGMODEL;
use ModelSEED::TestingHelpers;
use Test::More tests => 2;
use File::Temp qw(tempfile);

my $helper = ModelSEED::TestingHelpers->new();
my $fm = $helper->getDebugFIGMODEL();
    
#Testing ability to remotely access RAST genomes
{
    $fm->authenticate({
    	username => "reviewer",
    	password => "reviewer"
    });
    my $genome = $fm->get_genome("315750.3");
    ok defined($genome), "Could not obtain RAST genome 315750.3!";
    my $ftrTbl = $genome->feature_table();
    ok defined($ftrTbl) && $ftrTbl->size() > 1000, "Could not obtain features for RAST genome 315750.3!";
}
