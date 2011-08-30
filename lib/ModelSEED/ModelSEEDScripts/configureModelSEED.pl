#!/usr/bin/perl -w
########################################################################
# This perl script configures a model seed installation
# Author: Christopher Henry
# Author email: chrisshenry@gmail.com
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of script creation: 8/29/2011
########################################################################
use strict;

my $argConfig = {
	"-p" => "instalation directory",
	"-d" => "data directory",
	"-cplex" => "cplex license",
	"-os" => "operating system",
	"-usr" => "username",
	"-pwd" => "password",
	"-figconfig" => "additional figconfig file",
	"-dbhost" => "additional figconfig file",
	"-dbusr" => "additional figconfig file",
	"-dbpwd" => "additional figconfig file"
};
my $essentialArgs = ["-p","-d"];

my $args;
for (my $i=1; $i < @ARGV; $i++) {
	if (!defined($argConfig->{$ARGV[$i]})) {
		print "Unrecognized argument: ".$ARGV[$i].". ";
		&printUsage();
		exit();
	} else {
		push(@{$args->{$ARGV[$i]}},$ARGV[$i+1]);	
	}
	$i++;
}
for (my $i=1; $i < @{$essentialArgs}; $i++) {
	if (!defined($args->{$essentialArgs->[$i]})) {
		print "Essential argument missing: ".$essentialArgs->[$i].". ";
		&printUsage();
		exit();
	}
}
my $extension = ".sh";
if (defined($args->{"-os"}) && $args->{"-os"} eq "windows") {
	$extension = ".bat";
}

#Creating environment shell script
my $data = &loadFile($args->{"-p"}."config/FIGMODELConfig.txt");
for (my $i=0; $i < @{$data}; $i++) {
	if ($data->[$i] =~ m/database\sroot\sdirectory/) {
		$data->[$i] = "database root directory|".$args->{"-d"}->[0];
	} elsif ($data->[$i] =~ m/software\sroot\sdirectory/) {
		$data->[$i] = "software root directory|".$args->{"-p"}->[0];
	}
}
&printFile($args->{"-p"}."config/FIGMODELConfig.txt",$data);

#Creating FIGMODELConfig.txt
my $data = &loadFile($args->{"-p"}."config/FIGMODELConfig.txt");
for (my $i=0; $i < @{$data}; $i++) {
	if ($data->[$i] =~ m/database\sroot\sdirectory/) {
		$data->[$i] = "database root directory|".$args->{"-d"}->[0];
	} elsif ($data->[$i] =~ m/software\sroot\sdirectory/) {
		$data->[$i] = "software root directory|".$args->{"-p"}->[0];
	}
}
&printFile($args->{"-p"}."config/FIGMODELConfig.txt",$data);

#Creating shell scripts
my ($modeldriver,$queuedriver);
$modeldriver = ["source ".$args->{"-p"}."config/envConfig".$extension];
$queuedriver = ["source ".$args->{"-p"}."config/envConfig".$extension];
if (defined($args->{"-cplex"})) {
	push(@{$queuedriver},"export ILOG_LICENSE_FILE=".$args->{"-cplex"}->[0]);
	push(@{$modeldriver},"export ILOG_LICENSE_FILE=".$args->{"-cplex"}->[0]);
}
my $configFiles = "export FIGMODEL_CONFIG=".$args->{"-p"}->[0]."config/FIGMODELConfig.txt";
if (defined($args->{"-figconfig"})) {
	$configFiles .= ":".join(":",@{$args->{"-figconfig"}});
}
push(@{$queuedriver},$configFiles);
push(@{$modeldriver},$configFiles);
push(@{$queuedriver},"export ARGONNEDB=".$args->{"-d"}->[0]."ReactionDB/");
push(@{$modeldriver},"export ARGONNEDB=".$args->{"-d"}->[0]."ReactionDB/");
if (defined($args->{"-usr"}) && defined($args->{"-pwd"})) {
	push(@{$queuedriver},"export FIGMODEL_USER=".$args->{"-usr"});
	push(@{$modeldriver},"export FIGMODEL_PASSWORD=".$args->{"-pwd"});
}
push(@{$queuedriver},"perl ".$args->{"-p"}->[0]."lib/ModelSEED/FIGMODELscheduler.pl $*");
push(@{$modeldriver},"perl ".$args->{"-p"}->[0]."lib/ModelSEED/ModelDriver.pl $*");
&printFile($args->{"-p"}."bin/ModelDriver".$extension,$modeldriver);
&printFile($args->{"-p"}."bin/QueueDriver".$extension,$queuedriver);

#Configuring database
system($args->{"-p"}."bin/ModelDriver".$extension." configureserver?"
	."ModelDB?"
	.$args->{"-dbhost"}->[0]."?"
	.$args->{"-dbusr"}->[0]."?"
	.$args->{"-dbpwd"}->[0]."???"
	.$args->{"-p"}."config/FIGMODELConfig.txt"
);
system($args->{"-p"}."bin/ModelDriver".$extension." configureserver?"
	."SchedulerDB?"
	.$args->{"-dbhost"}->[0]."?"
	.$args->{"-dbusr"}->[0]."?"
	.$args->{"-dbpwd"}->[0]."???"
	.$args->{"-p"}."config/FIGMODELConfig.txt"
);
system($args->{"-p"}."bin/ModelDriver".$extension." configureserver?"
	."UserDB?"
	.$args->{"-dbhost"}->[0]."?"
	.$args->{"-dbusr"}->[0]."?"
	.$args->{"-dbpwd"}->[0]."???"
	.$args->{"-p"}."config/FIGMODELConfig.txt"
);

sub printFile {
	my ($filename,$arrayRef) = @_;
	open (OUTPUT, ">$filename");
	foreach my $Item (@{$arrayRef}) {
		if (length($Item) > 0) {
			print OUTPUT $Item."\n";
		}
	}
	close(OUTPUT);
}

sub loadFile {
	my ($self,$Filename) = @_;
	my $DataArrayRef = [];
	if (open (INPUT, "<$Filename")) {
		while (my $Line = <INPUT>) {
			chomp($Line);
			push(@{$DataArrayRef},$Line);
		}
		close(INPUT);
	}
	return $DataArrayRef;
}

sub printUsage {
	print "Usage: configureModelSEED.sh";
	foreach my $key (keys(%{$argConfig})) {
		print " ".$key." \"".$argConfig->{$key}."\"";
	}
	print "\n";
}

$|=1;