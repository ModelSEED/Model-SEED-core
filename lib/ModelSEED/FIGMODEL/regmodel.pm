use strict;
package ModelSEED::FIGMODEL::regmodel;
use Scalar::Util qw(weaken);
use Carp qw(cluck);

=head1 regmodel object
=head2 Introduction
Module for manipulating model objects.
=head2 Core Object Methods

=head3 new
Definition:
	regmodel = regmodel->new();
Description:
	This is the constructor for the regmodel object.
	Arguments: 
		id, { new configuration }	   
=cut
sub new {
	my ($class,$args) = @_;
	$args = ModelSEED::globals::ARGS($args,["figmodel"],{
		id => undef,
	});
	my $self = {_figmodel => $args->{figmodel},_mainfigmodel => $args->{figmodel}};
	Scalar::Util::weaken($self->{_figmodel});
	Scalar::Util::weaken($self->{_mainfigmodel});
	bless $self;
	
	#Jose places constructor code here.
	
	return $self;
}

=head3 initializeModel
Definition:
	string = FIGMODELmodel->initializeModel();
Description:
	Getter for model id
=cut
sub initializeModel {
	my ($self,$args) = @_;
	$args = ModelSEED::globals::ARGS($args,["id"],{
		genome => "NONE",
		owner => "master"
	});
	$self->{_owner} = $args->{owner};
}

=head3 loadFromFile
Definition:
	string = FIGMODELmodel->loadFromFile();
Description:
	Loads a model from the input filename
=cut
sub loadFromFlatData {
	my ($self,$args) = @_;
	$args = ModelSEED::globals::ARGS($args,[],{
		filedata => undef
	});
	#Jose writes code here to fill datastructure as listed below
	$self->{data}->{rules}->[0] = {
		genes => [],
		rule => ""
	};
	$self->{data}->{regulators}->[0] = {
		id => "",
		regulator => "",
		type => ""
	};
}

=head3 printToFile
Definition:
	string = FIGMODELmodel->printToFile();
Description:
	Print a model to the input filename
=cut
sub printToFlatData {
	my ($self,$args) = @_;
	$args = ModelSEED::globals::ARGS($args,[],{});
	my $flatdata;
	#Jose writes code here to fill datastructure as listed below
	$self->{data}->{rules}->[0] = {
		genes => [],
		rule => ""	
	};
	$self->{data}->{regulators}->[0] = {
		id => "",
		regulator => "",
		type => ""
	};
	return $flatdata;
}

=head3 id
Definition:
	string = FIGMODELmodel->id();
Description:
	Getter for model id
=cut
sub id {
	my ($self) = @_;
	return $self->{id};
}

=head3 genome
Definition:
	string = FIGMODELmodel->genome();
Description:
	Gets genome ID
=cut
sub genome {
	my ($self) = @_;
	return $self->{genome};
}

=head3 source
Definition:
	string = FIGMODELmodel->source();
Description:
	Gets source ID
=cut
sub source {
	my ($self) = @_;
	return $self->{source};
}

=head3 get_rules
Definition:
	string = FIGMODELmodel->get_rules();
Description:
	Gets a list of all rules in the model
=cut
sub get_rules {
	my ($self) = @_;
	return $self->{rules};
}

=head3 get_rule
Definition:
	string = FIGMODELmodel->get_rule();
Description:
	Gets one rule from the model
=cut
sub get_rule {
	my ($self,$index) = @_;
	return $self->{rule}->[$index];
}

1;
