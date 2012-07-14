#!/usr/bin/env perl
use FindBin qw($Bin);
use lib $Bin.'/../config';
use ModelSEEDbootstrap;
use Class::Autouse qw(
    ModelSEED::App::mseed
    ModelSEED::App::bio
    ModelSEED::App::genome
    ModelSEED::App::import
    ModelSEED::App::model
    ModelSEED::App::stores
    ModelSEED::App::mapping
    ModelSEED::ModelDriver
    ModelSEED::Interface::interface
);
$|=1;
#Determine which subscript the user is calling
my $target = shift(@ARGV);
if ($target eq "ms") {
	ModelSEED::App::mseed->run;
} elsif ($target eq "bio") {
	ModelSEED::App::bio->run;
} elsif ($target eq "genome") {
	ModelSEED::App::genome->run;
} elsif ($target eq "model") {
	ModelSEED::App::model->run;
} elsif ($target eq "mapping") {
	ModelSEED::App::mapping->run;
} elsif ($target eq "stores") {
	ModelSEED::App::stores->run;
} elsif ($target eq "import") {
	ModelSEED::App::import->run;
} elsif ($target eq "modeldriver") {
	ModelSEED::ModelDriver->run(@ARGV);
}

=pod

=head1 NAME

mscli - A unified script to drive the entire Model SEED command line interface


=head1 SYNOPSIS

ms [command] [options]


=head1 DESCRIPTION

Use the B<commands> command for a list of avaiable commands.
For help with a specfic command, use the B<help> command
followed by the name of the command you are interested in.

    $ ms commands
    $ ms help login

=cut
