use strict;
package ModelSEED::FIGMODEL::FIGMODELinterval;
use Scalar::Util qw(weaken);
use Carp qw(cluck);

=head1 FIGMODELinterval object
=head2 Introduction
Module for holding interval related access functions
=head2 Core Object Methods

=head3 new
Definition:
	FIGMODELinterval = FIGMODELinterval->new(figmodel,string:interval id);
Description:
	This is the constructor for the FIGMODELgenome object.
=cut
sub new {
	my ($class,$args) = @_;
	#Error checking first
	if (!defined($args->{figmodel})) {
		print STDERR "FIGMODELinterval->new():figmodel must be defined to create an interval object!\n";
		return undef;
	}
	if (!defined($args->{id})) {
		print STDERR "FIGMODELinterval->new():id must be defined to create an interval object!\n";
		return undef;
	}
	my $self = {_figmodel => $args->{figmodel}};
    weaken($self->{_figmodel});
	bless $self;
	my $tbl = $self->figmodel()->database()->get_table("INTERVAL");
	$self->id($args->{id});
	my $row = $tbl->get_row_by_key($self->id(),"ID");
	if (!defined($row)) {
		print STDERR "FIGMODELinterval->new():interval ".$self->id()." could not be found!\n";
		return undef;
	}
	$self->{_start} = $row->{START}->[0];
	$self->{_stop} = $row->{STOP}->[0];
	$self->{_genome} = $row->{GENOME}->[0];
	return $self;
}

=head3 figmodel
Definition:
	FIGMODEL = FIGMODELinterval->figmodel();
Description:
	Returns the figmodel object
=cut
sub figmodel {
	my ($self) = @_;
	return $self->{_figmodel};
}

=head3 error_message
Definition:
	string:message text = FIGMODELinterval->error_message(string::message);
Description:
=cut
sub error_message {
	my ($self,$message) = @_;
	return $self->figmodel()->error_message("FIGMODELinterval:".$self->id().":".$message);
}


=head3 id
Definition:
	string:ID = FIGMODELinterval->id(string:input ID);
Description:
	Returns the ID
=cut
sub id {
	my ($self,$id) = @_;
	if (defined($id)) {
		$self->{_id} = $id;
	}
	return $self->{_id};
}

=head3 start
Definition:
	interger:start location = FIGMODELinterval->start();
Description:
	Returns the start location of the interval on the genome
=cut
sub start {
	my ($self) = @_;
	return $self->{_start};
}

=head3 stop
Definition:
	interger:stop location = FIGMODELinterval->stop();
Description:
	Returns the stop location of the interval on the genome
=cut
sub stop {
	my ($self) = @_;
	return $self->{_stop};
}

=head3 genome
Definition:
	string:genome ID = FIGMODELinterval->genome();
Description:
	Returns the ID of the genome containing the interval
=cut
sub genome {
	my ($self) = @_;
	return $self->{_genome};
}

=head3 genomeObj
Definition:
	FIGMODELgenome:genome object = FIGMODELinterval->genomeObj();
Description:
	Returns the FIGMODELgenome object for the genome containing the interval
=cut
sub genomeObj {
	my ($self) = @_;
	if (!defined($self->{_genomeObj})) {
		$self->{_genomeObj} = $self->figmodel()->get_genome($self->genome());	
	}
	return $self->{_genomeObj};
}

=head3 genes
Definition:
	{genes => [string:gene IDs]} = FIGMODELinterval->genes();
Description:
=cut
sub genes {
	my ($self) = @_;
	my $obj = $self->genomeObj();
	if (!defined($obj)) {
		return {error => $self->error_message("genes:could not load genome object for interval")};
	}
	return $obj->intervalGenes({start => $self->start(),stop => $self->stop()});
}

=head3 createPrimers
Definition:
	{} = FIGMODELinterval->createPrimers();
	Output: {success,error,msg};
Description:
=cut
sub createPrimers {
	my ($self) = @_;
}

1;
