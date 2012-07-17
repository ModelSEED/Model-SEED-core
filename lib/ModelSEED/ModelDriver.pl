#!/usr/bin/env perl
use FindBin qw($Bin);
use lib $Bin.'/../config';
use lib $Bin.'/../lib';
use lib $Bin.'/../lib/ModelSEED';
use lib $Bin.'/../lib/myRAST';
use lib $Bin.'/../lib/PPO';
use lib $Bin.'/../lib/FigKernelPackages';
use lib $Bin.'/../lib/ModelSEED/ModelSEEDClients';
use ModelSEEDbootstrap;
$|=1;
ModelSEED::ModelDriver->run(@ARGV);
1;