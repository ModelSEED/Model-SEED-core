use strict;
package ModelSEED::FIGMODEL::FIGMODELTableRow;

=head3 FIGMODELTableRow

Implements AUTOLOAD and attributes() methods
that are needed to emulate FIGMODELdata objects.
=cut

sub new {
    my ($class, $row, $table) = @_; 
    my $self = {
        _rowObj => $row,
        _tableObj => $table,
    };
    bless $self;
    return $self; 
}

sub attributes {
    my ($self) = @_;
    return { map { $_ => [1] } keys %{$self->{_rowObj}} }; 
}

sub _knows_attribute {
    my ($self, $attr) = @_;
    if(defined($self->{_rowObj}->{$attr})) {
        return 1;
    } else {
        return 0;
    } 
}
    

sub delete {
    my ($self) = @_;
    my $idx = $self->{_tableObj}->row_index($self->{_rowObj});
    $self->{_tableObj}->delete_row($idx);
    $self->{_tableObj}->save();
}
    
sub AUTOLOAD {
    my $self = shift @_;
    my $call = our $AUTOLOAD;
    return if $call =~ /::DESTROY$/;
    $call =~ s/.*://;
    my $delim = $self->{_tableObj}->item_delimiter();
    unless(scalar(@_) > 0) {
        if ($delim eq "\\|" || $delim eq "\|") {
			$delim = "|";
		} elsif ($delim eq "\\t") {
			$delim = "\t";
		}
        my $data = $self->{_rowObj}->{$call};
        return (defined($data) && @$data > 0) ? join("$delim", @$data) : undef;
    }
    my $value = shift @_; 
    my $old_values = $self->{_rowObj}->{$call};
    if ($delim eq "|") {
    	$delim = "\\|";	
    }
    $self->{_rowObj}->{$call} = [split(/$delim/, $value)];
    # update hash heading if we need to
    my $hash_headings = { map { $_ => $_ } $self->{_tableObj}->hash_headings() };
    if(defined($hash_headings->{$call})) {
        for my $old_value (@$old_values) { # removing old values from hashes
            if (defined($old_value) && length($old_value) > 0) {
	            my $all_rows = { map { $_ => $_ } @{$self->{_tableObj}->{"hash columns"}->{$call}->{$old_value}} };
	            if(defined($all_rows->{$self->{_rowObj}})) {
	                delete $all_rows->{$self->{_rowObj}};
	            }
	            if(values(%$all_rows) > 0) {
	                $self->{_tableObj}->{"hash columns"}->{$call}->{$old_value} = [values(%$all_rows)];
	            } else {
	                delete $self->{_tableObj}->{"hash columns"}->{$call}->{$old_value};
	            }
            }
        }
        for my $new_value (@{$self->{_rowObj}->{$call}}) { # and adding new values to hashes
			push(@{$self->{_tableObj}->{"hash columns"}->{$call}->{$new_value}}, $self->{_rowObj});
        }
    }
    $self->{_tableObj}->save();
    return $self->$call();
}
1;

