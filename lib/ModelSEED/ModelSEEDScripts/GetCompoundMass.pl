#!/usr/bin/perl -w

########################################################################
# Script for filtering the Chris File functional role mapping
# Author: Christopher Henry
# Author email: chrisshenry@gmail.com
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 10/15/2008
########################################################################

use strict;
use FIGMODEL;
$|=1;

my $model = new FIGMODEL->new();

$model->LoadCompoundDatabaseFile();

for (my $i=0; $i < @{$model->{"DATABASE"}->{"COMPOUNDS"}}; $i++) {
    if (defined($model->{"DATABASE"}->{"COMPOUNDS"}->[$i]->{"DATABASE"})) {
	my $CompoundData = $model->LoadObject($model->{"DATABASE"}->{"COMPOUNDS"}->[$i]->{"DATABASE"}->[0]);
	if (defined($CompoundData->{"MASS"})) {
	    print $model->{"DATABASE"}->{"COMPOUNDS"}->[$i]->{"DATABASE"}->[0]."\t".$CompoundData->{"MASS"}->[0]."\n";
	}
    }
}