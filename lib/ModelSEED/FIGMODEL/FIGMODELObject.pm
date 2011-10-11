# -*- perl -*-
########################################################################
#
# Table object for the model database interaction module
# Initiating author: Christopher Henry
# Initiating author email: chrisshenry@gmail.com
# Initiating author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2/1/2008
########################################################################
use strict;
package ModelSEED::FIGMODEL::FIGMODELObject;
use Carp qw(cluck);
#use ModelSEED::FIGMODEL qw(FIGMODELERROR);

=head1 FIGMODELObject object
=head2 Introduction
Module for holding object data in individual files as done with reactions and compounds in the ModelSEED database
=head2 Core Object Methods

=head3 new
Definition:
	FIGMODELObject = FIGMODELObject->new({filename => string:filename for object,delimiter => string:delimiter for output,headings => [string],-load => 0/1});
Description:
	Creates an empty object that may be populated by the user.
=cut

sub new {
	my ($class,$args) = @_;
	my $self = {};
	bless $self;
	$args = $self->process_arguments($args,["filename"],{
		delimiter => "\t",
		headings => [],
		-load => 0,
		data => undef
	});
	$self->filename($args->{filename});
	$self->delimiter($args->{delimiter});
	$self->headings($args->{headings});
	if ($args->{-load} == 1) {
		if (defined($self->load())) {
			$self = undef;	
		}
	} elsif (defined($args->{data})) {
		if (@{$self->headings()} == 0) {
			$self->headings([keys(%{$args->{data}})]);
		}
		foreach my $key (keys(%{$args->{data}})) {
			push(@{$self->{$key}},@{$args->{data}->{$key}});
		}
	}
	return $self;
}

=head3 process_arguments
Definition:
	{key=>value} = FIGMODELObject->process_arguments({key=>value});
Description:
    Processes arguments to ensure that mandatory arguments are present and set default values for optional arguments
=cut
sub process_arguments {
    my ($self,$args,$mandatoryArguments,$optionalArguments) = @_;
    if (defined($mandatoryArguments)) {
    	for (my $i=0; $i < @{$mandatoryArguments}; $i++) {
    		if (!defined($args->{$mandatoryArguments->[$i]})) {
				push(@{$args->{_error}},$mandatoryArguments->[$i]);
    		}
    	}
    }
	ModelSEED::FIGMODELglobals::ERROR("Mandatory arguments ".join("; ",@{$args->{_error}})." missing. Usage:".$self->print_usage($mandatoryArguments,$optionalArguments,$args)) if (defined($args->{_error}));
    if (defined($optionalArguments)) {
    	foreach my $argument (keys(%{$optionalArguments})) {
    		if (!defined($args->{$argument})) {
    			$args->{$argument} = $optionalArguments->{$argument};
    		}
    	}	
    }
    return $args;
}

sub ERROR {	
	my ($self,$message) = @_;
	confess $message;
}

=head3 load
Definition:
	string:error = FIGMODELObject->load({filename => string:filename for object,delimiter => string:delimiter for output});
Description:
	Loads object from file
=cut
sub load {
	my ($self,$args) = @_;
	$args = $self->process_arguments($args,[],{delimiter => $self->delimiter(),filename => $self->filename()});
    $self->filename($args->{filename});
	$self->delimiter($args->{delimiter});
    open (INPUT, "<".$self->filename()) || ModelSEED::FIGMODEL::FIGMODELERROR("Could not open: ".$self->filename()." ".$@);
	my $headings;
	while (my $Line = <INPUT>) {
		chomp($Line);
		my $Delimiter = $self->delimiter();
		my @Data = split(/$Delimiter/,$Line);
		my $Heading = shift(@Data);
		my $Temp;
		push(@{$Temp},@Data);
		$self->add_data($Temp,$Heading);
		push(@{$headings},$Heading);
	}
	$self->headings($headings);
	close(INPUT);
	return undef;
}

=head3 save
Definition:
	string:error = FIGMODELObject->save({headings => [string],filename => string:filename for object,delimiter => string:delimiter for output});
Description:
	Saves the object to a horizontal table file
=cut

sub save {
	my ($self,$args) = @_;
	$args = $self->process_arguments($args,[],{headings => $self->headings(),delimiter => $self->delimiter(),filename => $self->filename()});
	$self->filename($args->{filename});
	$self->delimiter($args->{delimiter});
	$self->headings($args->{headings});
	if (open (HASHTOHORIZONTALOUTPUT, ">".$self->filename())) {
		foreach my $Item (@{$self->headings()}) {
			if ($self->get_data_size($Item) > 0) {
				print HASHTOHORIZONTALOUTPUT $Item.$self->delimiter().join($self->delimiter(),@{$self->get_data($Item)})."\n";
			}
		}
		close(HASHTOHORIZONTALOUTPUT);
	}
}


=head3 get_data_size
Definition:
	my $Size = $Object->get_data_size($Key);
Description:
	Returns the number of elements stored in a particular key.
Example:
	my $Size = $Object->get_data_size($Key);
=cut

sub get_data_size {
	my ($self,$Key) = @_;
	my $Size = 0;
	if (defined($self->{$Key})) {
		$Size = @{$self->{$Key}};
	}
	return $Size;
}

=head3 get_data
Definition:
	my $DataArrayRef = $Object->get_data($Key);
Description:
	Returns a reference to the array stored in Key.
Example:
	my DataArrayRef = $Object->get_data($Key);
=cut

sub get_data {
	my ($self,$Key) = @_;
	if (defined($self->{$Key})) {
		return $self->{$Key};
	}
	return undef;
}

=head3 filename
Definition:
	string = FIGMODELObject->filename(string)
Description:
	Getter setter for filename
=cut
sub filename {
	my ($self,$filename) = @_;
	if (defined($filename)) {
		$self->{_filename} = $filename;
	}
	return $self->{_filename};
}

=head3 delimiter
Definition:
	string = FIGMODELObject->delimiter(string)
Description:
	Getter setter for delimiter
=cut
sub delimiter {
	my ($self,$delimiter) = @_;
	if (defined($delimiter)) {
		$self->{_delimiter} = $delimiter;
	}
	return $self->{_delimiter};
}

=head3 headings
Definition:
	[string] = FIGMODELObject->headings([string]);
Description:
	Getter setter for headings
=cut

sub headings {
	my ($self,$headings) = @_;
	if (defined($headings)) {
		$self->{_headings} = $headings;
	}
	return $self->{_headings};
}

=head3 add_data
Definition:
	my $Count = $Object->add_data($Data,$Key,$Unique);
Description:
	Adds $Data to the array stored in $Key. If $Unique is specified and equal to "1", only new data is added to the array.
	Returns "1" if data was added and "0" if no data was added
=cut
sub add_data {
	my ($self,$DataArray,$Key,$Unique) = @_;
	if (defined($DataArray)) {
		foreach my $Data (@{$DataArray}) {
			#Now checking if the heading exists and if the $Data is unique
			if (!defined($Unique) || $Unique ne 1 || $self->data_exists($Data,$Key) == 0) {
				#Adding the data
				if (defined($self->get_data($Key))) {
					push(@{$self->get_data($Key)},$Data);
				} else {
					$self->{$Key}->[0] = $Data;
				}
			}
		}
	}
	return 0;
}

=head3 data_exists
Definition:
	my $Result = $Object->data_exists($Data,$Key);
Description:
	Returns "1" if the input $Data matches one of the entries in the array stored in $Key.
=cut
sub data_exists {
	my ($self,$Data,$Key) = @_;
	if ($self->get_data_size($Key) > 0) {
		for (my $i=0; $i < $self->get_data_size($Key); $i++) {
			if ($self->get_data($Key)->[$i] eq $Data) {
				return 1;
			}
		}
	}
	return 0;
}

=head3 delete_key
Definition:
	$Object->delete_key($Key);
Description:
	Deletes a key from the object.
=cut
sub delete_key {
	my ($self,$Key) = @_;

	if ($self->get_data_size($Key) > 0) {
		delete $self->{$Key};
		$self->remove_heading($Key);
	}
}

=head3 remove_data
Definition:
	$Object->remove_data(@Data,$Key);
Description:
	Removes the data specified in @Data from the array stored in $Key.
=cut
sub remove_data {
	my ($self,@Data,$Key) = @_;

	if ($self->get_data_size($Key) > 0) {
		for (my $i=0; $i < $self->get_data_size($Key); $i++) {
			foreach my $Item (@Data) {
				if ($Item eq $self->get_data_size($Key)->[$i]) {
					splice(@{$self->get_data()},$i,1);
					$i--;
					last;
				}
			}
		}
	}

	if ($self->get_data_size($Key) == 0) {
		delete $self->{$Key};
		$self->remove_heading($Key);
	}
}

=head3 remove_heading
Definition:
	$Object->remove_heading($Key);
Description:
	Removes the specified heading from the heading list

=cut
sub remove_heading {
	my ($self,$Key) = @_;
	for (my $i=0; $i < @{$self->headings()}; $i++) {
		if ($self->headings()->[$i] eq $Key) {
			splice(@{$self->headings()},$i,1);
			$i--;
		}
	}
}

=head3 rename_heading

Definition:
	FIGMODELObject->rename_heading(string:old name,string:new name);
Description:
	Renames a heading
=cut
sub rename_heading {
	my ($self,$old,$new) = @_;
	for (my $i=0; $i < @{$self->headings()}; $i++) {
		if ($self->headings()->[$i] eq $old) {
			$self->headings()->[$i] = $new;
			$self->{$new} = $self->{$old};
		}
	}
}

=head3 add_headings
Definition:
	$Object->add_headings(@Headings);
Description:
	Adds new headings to the table. This is needed to get the object to print the data under the new heading.
=cut
sub add_headings {
	my ($self,@Headings) = @_;

	foreach my $Heading (@Headings) {
		if (defined($self->headings())) {

            #First check if the heading already exists
            foreach my $ExistingHeading (@{$self->headings()}) {
                if ($Heading eq $ExistingHeading) {
                    $Heading = "";
                    last;
                }
            }
        }
        if ($Heading ne "") {
            push(@{$self->{"file IO settings"}->{orderedkeys}},$Heading);
        }
	}
}

1;
