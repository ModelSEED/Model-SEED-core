use strict;
package ModelSEED::FIGMODEL::FIGMODELcompound;
use Scalar::Util qw(weaken);
use Carp qw(cluck);

=head1 FIGMODELcompound object
=head2 Introduction
Module for holding reaction related access functions
=head2 Core Object Methods

=head3 new
Definition:
	FIGMODELcompound = FIGMODELcompound->new({figmodel => FIGMODEL:parent figmodel object,id => string:compound id});
Description:
	This is the constructor for the FIGMODELcompound object.
=cut
sub new {
	my ($class,$args) = @_;
	#Must manualy check for figmodel argument since figmodel is needed for automated checking
	if (!defined($args->{figmodel})) {
		print STDERR "FIGMODELcompound->new():figmodel must be defined to create an genome object!\n";
		return undef;
	}
	my $self = {_figmodel => $args->{figmodel}};
    Scalar::Util::weaken($self->{_figmodel});
	bless $self;
	#Processing remaining arguments
	$args = $self->figmodel()->process_arguments($args,["figmodel","id"],{});
	if (defined($args->{error})) {
		$self->error_message({function=>"new",args=>$args});
		return undef;
	}
	$self->{_id} = $args->{id};
	$self->figmodel()->set_cache("FIGMODELcompound|".$self->id(),$self);
	return $self;
}

=head3 error_message
Definition:
	string:message text = FIGMODELcompound->error_message(string::message);
Description:
=cut
sub error_message {
	my ($self,$args) = @_;
	$args->{"package"} = "FIGMODELcompound";
    return $self->figmodel()->new_error_message($args);
}

=head3 figmodel
Definition:
	FIGMODEL = FIGMODELcompound->figmodel();
Description:
	Returns the figmodel object
=cut
sub figmodel {
	my ($self) = @_;
	return $self->{_figmodel};
}

=head3 id
Definition:
	string:compound ID = FIGMODELcompound->id();
Description:
	Returns the reaction ID
=cut
sub id {
	my ($self) = @_;
	return $self->{_id};
}

=head3 ppo
Definition:
	PPOcompound:compound object = FIGMODELcompound->ppo();
Description:
	Returns the reaction ppo object
=cut
sub ppo {
	my ($self,$inppo) = @_;
	if (defined($inppo)) {
		$self->{_ppo} = $inppo;
	}
	if (!defined($self->{_ppo})) {
		$self->{_ppo} = $self->figmodel()->database()->get_object("compound",{id => $self->id()});
	}
	return $self->{_ppo};
}

=head3 file
Definition:
	{string:key => [string]:values} = FIGMODELcompound->file({clear => 0/1});
Description:
	Loads the compound data from file
=cut
sub file {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{clear => 0});
	if ($args->{clear} == 1) {
		delete $self->{_file};
	}
	if (!defined($self->{_file})) {
		$self->{_file} = ModelSEED::FIGMODEL::FIGMODELObject->new({filename=>$self->figmodel()->config("compound directory")->[0].$self->id(),delimiter=>"\t",-load => 1});
		if (!defined($self->{_file})) {return $self->error_message({function=>"file",message=>"could not load file",args=>$args});}
	} 
	return $self->{_file};
}

=head3 loadPPOFromFile
Definition:
	{} = FIGMODELcompound->loadPPOFromFile({
	});
Description:
	Loads the compound data from file into PPO database
=cut
sub loadPPOFromFile {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	if (defined($args->{error})) {return $self->error_message({function => "loadPPOFromFile",args => $args});}
	$args = $self->figmodel()->process_arguments($args,[],{});
	my $data = $self->file();
	my $ppoHash = {
		id => $self->id(),
		name => $self->id(),
		abbrev => $self->id(),
		owner => "master",
		modificationDate => time(),
		creationDate => time(),
		public => 1
	};
	if (defined($data->{PKA})) {
		$ppoHash->{pKa} = join(";",@{$data->{PKA}});
	}
	if (defined($data->{PKB})) {
		$ppoHash->{pKb} = join(";",@{$data->{PKB}});
	}
	if (defined($data->{STRUCTURAL_CUES})) {
		$ppoHash->{structuralCues} = join(";",@{$data->{STRUCTURAL_CUES}});
	}
	my $keyTranslation = {
		name => "NAME",
		abbrev => "NAME",
		formula=>"FORMULA",
		mass => "MASS",
		charge => "CHARGE",
		deltaG => "DELTAG",
		deltaGErr => "DELTAGERR",
	};
	foreach my $key (keys(%{$keyTranslation})) {
		if (defined($data->{$keyTranslation->{$key}})) {
			$ppoHash->{$key} = $data->{$keyTranslation->{$key}}->[0];
		}
	}
	my $ppo = $self->ppo();
	if (!defined($ppo)) {
		$self->{_ppo} = $self->figmodel()->database()->create_object("compound",$ppoHash);
	} else {
		foreach my $key (keys(%{$ppoHash})) {
			$ppo->$key($ppoHash->{$key});
		}	
	}
	if (defined($data->{NAME})) {
		$self->addNamesToAliasTable({names=>$data->{NAME},clear=>1});
	}
}
=head3 convert_to_search_name
Definition:
	(string)::search names = FIGMODELcompound->convert_to_search_name(string::name);
Description:
	Converts the input name to a search name.
=cut
sub convert_to_search_name {
	my ($self,$InName) = @_;
	my $ending = "";
	if ($InName =~ m/-$/) {
		$ending = "-";
	}
	$InName = lc($InName);
	$InName =~ s/\s//g;
	$InName =~ s/,//g;
	$InName =~ s/-//g;
	$InName =~ s/_//g;
	$InName =~ s/\(//g;
	$InName =~ s/\)//g;
	$InName =~ s/\[//g;
	$InName =~ s/\]//g;
	$InName =~ s/\://g;
	$InName =~ s/’//g;
	$InName =~ s/'//g;
	$InName =~ s/\;//g;
	$InName .= $ending;
	my $NameOne = $InName;
	$InName =~ s/icacid/ate/g;
	if ($NameOne eq $InName) {
		return ($NameOne);
	} else {
		return ($NameOne,$InName);
	}
}
=head3 addNamesToAliasTable
Definition:
	{} = FIGMODELcompound->addNamesToAliasTable({
	});
Description:
	Loads the compound data from file into PPO database
=cut
sub addNamesToAliasTable {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["names"],{clear=>0});
	if (defined($args->{error})) {return $self->error_message({function => "addNamesToAliasTable",args => $args});}
	if ($args->{clear} == 1) {
		my $objs = $self->figmodel()->database()->get_objects("cpdals",{COMPOUND=>$self->id(),type=>"name"});
		for (my $i=0; $i < @{$objs}; $i++) {
			$objs->[$i]->delete();
		}
		$objs = $self->figmodel()->database()->get_objects("cpdals",{COMPOUND=>$self->id(),type=>"searchname"});
		for (my $i=0; $i < @{$objs}; $i++) {
			$objs->[$i]->delete();
		}
	}
	for (my $i=0; $i < @{$args->{names}}; $i++) {
		if (!defined($self->figmodel()->database()->get_object("cpdals",{COMPOUND=>$self->id(),type=>"name",alias=>$args->{names}->[$i]}))) {
			$self->figmodel()->database()->create_object("cpdals",{COMPOUND=>$self->id(),type=>"name",alias=>$args->{names}->[$i]});
		}
		my @searchNames = $self->convert_to_search_name($args->{names}->[$i]);
		for (my $j=0; $j < @searchNames; $j++) {
			if (!defined($self->figmodel()->database()->get_object("cpdals",{COMPOUND=>$self->id(),type=>"searchname",alias=>$searchNames[$j]}))) {
				$self->figmodel()->database()->create_object("cpdals",{COMPOUND=>$self->id(),type=>"searchname",alias=>$searchNames[$j]});
			}
		}
	}
}

=head3 get_general_grouping
Definition:
	PPOcpdgrp = FIGMODELcompound->get_general_grouping({ids => [string]:compound IDs,type => string:grouping type,create=>0/1:indicates if grouping should be created if not found);
Description:
=cut
sub get_general_grouping {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["ids","type"],{create => 0});
	if (defined($args->{error})) {return {error => $self->new_error_message({args => $args,function => "get_grouping",package => "FIGMODELcompound"})};}
	#Creating package hash if it doesn't already exist
	if (!defined($self->figmodel()->cache("FIGMODELcompound|PPOcpdgrp|HASH|".$args->{type}))) {
		my $objs = $self->figmodel()->database()->get_objects("cpdgrp",{type => $args->{type}});
		my $packageHash;
		for (my $i=0; $i < @{$objs}; $i++) {
			$packageHash->{$objs->[$i]->grouping()}->{$objs->[$i]->COMPOUND()} = 1;
		}
		my $fnlHash;
		foreach my $pkg (keys(%{$packageHash})) {
			$fnlHash->{join("|",sort(keys(%{$packageHash->{$pkg}})))} = $pkg;
		}
		$self->figmodel()->set_cache("FIGMODELcompound|PPOcpdgrp|HASH|".$args->{type},$fnlHash);
	}
	#Looking for package with specified input IDs
	my $groupKey = join("|",sort(@{$args->{ids}}));
	if (!defined($self->figmodel()->cache("FIGMODELcompound|PPOcpdgrp|HASH|".$args->{type})->{$groupKey}) && $args->{create} == 1) {
		$self->figmodel()->cache("FIGMODELcompound|PPOcpdgrp|HASH|".$args->{type})->{$groupKey} = $self->figmodel()->database()->check_out_new_id($args->{type});
		for (my $i=0; $i < @{$args->{ids}}; $i++) {
			$self->figmodel()->database()->create_object("cpdgrp",{type => $args->{type},grouping => $self->figmodel()->cache("FIGMODELcompound|PPOcpdgrp|HASH|".$args->{type})->{$groupKey},COMPOUND => $args->{ids}->[$i]});
		}
	}
	return $self->figmodel()->cache("FIGMODELcompound|PPOcpdgrp|HASH|".$args->{type})->{$groupKey};
}

=head3 get_new_temp_id
Definition:
	string = FIGMODELcompound->get_new_temp_id({});
Description:
=cut
sub get_new_temp_id {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	return $self->error_message({$args => $args,function => "get_new_temp_id",package => "FIGMODELcompound"}) if (defined($args->{error}));
	my $newID;
	my $largestID = 79999;
	my $objs = $self->figmodel()->database()->get_objects("compound");
	for (my $i=0; $i < @{$objs}; $i++) {
		if (substr($objs->[$i]->id(),3) > $largestID) {
			$largestID = substr($objs->[$i]->id(),3);	
		}
	}
	$largestID++;
	return "cpd".$largestID;
}
=head3 printDatabaseTable
Definition:
	undef = FIGMODELcompound->printDatabaseTable({
		filename => string
	});
Description:
=cut
sub printDatabaseTable {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		filename => $self->figmodel()->config("compounds data filename")->[0]
	});
	my $config = {
		filename => $args->{filename},
		hash_headings => ['id', 'name', 'formula'],
	    delimiter => "\t",
	    item_delimiter => ";",
	};
	my $tbl = $self->figmodel()->database()->ppo_rows_to_table($config,$self->figmodel()->database()->get_objects('compound'));
	$tbl->save();
}

1;