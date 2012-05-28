#
#===============================================================================
#
#         FILE:  FIGMODELfba.t
#
#  DESCRIPTION:  Testing for FIGMODELfba.
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  Test for feature of FIGMODELfba
#       AUTHOR:  Chris Henry (chenry@mcs.anl.gov)
#      CREATED:  06/12/11
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use Data::Dumper;
use ModelSEED::FIGMODEL;
use ModelSEED::TestingHelpers;
use Test::More tests => 1;

my $helper = ModelSEED::TestingHelpers->new();
my $fm = $helper->getDebugFIGMODEL();
# test general access routines
{
    my $public_model = $fm->get_model('Seed83333.1'); 
    my $fba = $public_model->fba();
    $fba->setFBAStudy();
    $fba->runFBA({
    	filename => "FIGMODELfbaTest",
		printToScratch => 0,
		runSimulation => 0,
		nohup => 0,
		studyType => "LoadCentralSystem",
		logfile => "FIGMODELfbaTest.log",
        mediaPrintList => ["ArgonneLBMedia"],
    });
}
ok 1, "yes it passes"
