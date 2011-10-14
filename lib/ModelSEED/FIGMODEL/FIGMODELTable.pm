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
use ModelSEED::FIGMODEL::FIGMODELTableRow;
package ModelSEED::FIGMODEL::FIGMODELTable;

=head1 Table object for the model database interaction module

=head2 Public Methods

=head3 new
Definition:
	my $TableObj = FIGMODELTable->new($heading_list_ref,$filename,$hash_heading_list_ref,$delimiter,$itemdelimiter,$prefix);
Description:
	Creates an empty table object which may be filled using the add row function.
	The $heading_list_ref and $filename are required, but all remaining arguments are optional.
Example:
	my $TableObj = FIGMODELTable->new($heading_list_ref,$filename,$hash_heading_list_ref,$delimiter,$itemdelimiter,$prefix);
=cut

sub new {
	my $ObjectType = shift @_;
	my $args = shift @_;
	my ($headings,$filename,$hash_headings,$delimiter,$itemdelimiter,$prefix) = undef;
    if(ref($args) eq 'HASH') {
        $headings = $args->{headings};
        $filename = $args->{filename};
        $hash_headings = $args->{hashHeadings};
        $delimiter = $args->{delimiter};
        $itemdelimiter = $args->{itemDelimiter};
        $prefix = $args->{prefix};
    } else {
        $headings = $args;
        ($filename,$hash_headings,$delimiter,$itemdelimiter,$prefix) = @_;
    }
	my $self;
	if (!defined($filename) || !defined($headings)) {
		print STDERR "FIGMODELTable:new: cannot create table without a list of headings and a filename\n";
		return undef;
	}
	$self->{"file IO settings"}->{"filename"}->[0] = $filename;
	$self->{"file IO settings"}->{"orderedkeys"} = $headings;
	#Dealing with optional arguments
	if (defined($hash_headings)) {
		for (my $i=0; $i < @{$hash_headings}; $i++) {
			$self->{"hash columns"}->{$hash_headings->[$i]} = {};
		}
	}
	if (!defined($delimiter)) {
		$delimiter = ";";
	}
	$self->{"file IO settings"}->{"delimiter"}->[0] = $delimiter;
	if (!defined($itemdelimiter)) {
		$itemdelimiter = "|";
	}
	$self->{"file IO settings"}->{"item delimiter"}->[0] = $itemdelimiter;
	if (!defined($prefix)) {
		$prefix = "";
	}
	$self->{"file IO settings"}->{"file prefix"}->[0] = $prefix;

	return bless $self;
}

=head2 TABLE Methods

=head3 size
Definition:
	my $tablesize = $TableObj->size();
Description:
	This returns the number of rows in the table
Example:
	my $tablesize = $TableObj->size();
=cut

sub size {
	my ($self) = @_;
	my $TableSize = 0;
	if (defined($self->{"array"})) {
		$TableSize = @{$self->{"array"}};
	}
	return $TableSize;
}

=head3 get_row
Definition:
	my $RowObject = $TableObj->get_row($Row_index);
Description:
	Returns a hash reference for the specified row in the table. Returns undef if the row does not exist.
Example:
	my $RowObject = $TableObj->get_row(1);
=cut

sub get_row {
	my ($self,$RowNumber) = @_;
	return $self->{"array"}->[$RowNumber];
}

=head3 get_rows
Definition:
	(RowObjects):array reference to all rows = FIGMODELTable->get_rows();
Description:
	Returns a reference to the complete array of rows
=cut
sub get_rows {
	my ($self) = @_;
	return $self->{"array"};
}

=head3 filename
Definition:
	my $filename = $TableObj->filename();
Description:
	Returns the filename for the table.
Example:
	my $filename = $TableObj->filename();
=cut

sub filename {
	my ($self,$NewFilename) = @_;

	if (defined($NewFilename)) {
		$self->{"file IO settings"}->{"filename"}->[0] = $NewFilename;
	}

	return $self->{"file IO settings"}->{"filename"}->[0];
}

=head3 prefix
Definition:
	string: prefix = FIGMODELTable->prefix(string:new prefix);
=cut
sub prefix {
	my ($self,$newPrefix) = @_;
	if (defined($newPrefix)) {
		$self->{"file IO settings"}->{"file prefix"}->[0] = $newPrefix;
	}
	return $self->{"file IO settings"}->{"file prefix"}->[0];
}

=head3 delimiter
Definition:
	my $delimiter = $TableObj->delimiter();
Description:
	Returns the delimiter for the table.
Example:
	my $delimiter = $TableObj->delimiter();
=cut

sub delimiter {
	my ($self,$NewDelimiter) = @_;

	if (defined($NewDelimiter)) {
		$self->{"file IO settings"}->{"delimiter"}->[0] = $NewDelimiter;
	}

	return $self->{"file IO settings"}->{"delimiter"}->[0];
}

=head3 item_delimiter
Definition:
	my $item_delimiter = $TableObj->item_delimiter();
Description:
	Returns the item delimiter for the table.
Example:
	my $item_delimiter = $TableObj->item_delimiter();
=cut

sub item_delimiter {
	my ($self,$ItemDelimiter) = @_;

	if (defined($ItemDelimiter)) {
		$self->{"file IO settings"}->{"item delimiter"}->[0] = $ItemDelimiter;
	}

	return $self->{"file IO settings"}->{"item delimiter"}->[0];
}

=head3 headings
Definition:
	my @Headings = $TableObj->headings();
Description:
	Returns an array containing the headings for the table.
Example:
	my @Headings = $TableObj->headings();
=cut

sub headings {
	my ($self,$InHeadings) = @_;
	if (defined($InHeadings)) {
		$self->{"file IO settings"}->{"orderedkeys"} = $InHeadings;
	}
	return @{$self->{"file IO settings"}->{"orderedkeys"}};
}

=head3 get_table_hash_headings
Definition:
	my @hash_headings = $TableObj->get_table_hash_headings();
Description:
	Returns an array containing the headings that have also been added to the hash key for the table.
Example:
	my @hash_headings = $TableObj->get_table_hash_headings();
=cut

sub hash_headings {
	my ($self) = @_;
	return keys(%{$self->{"hash columns"}});
}

=head3 get_row_by_key
Definition:
	my $RowObject = $TableObj->get_row_by_key($Key,$HashColumn,$AddRow);
Description:
	Returns the row object for the firt row that matches the input key. Return undef if nothing matches the input key.
Example:
	my $RowObject = $TableObj->get_row_by_key("rxn00001");
=cut

sub get_row_by_key {
	my ($self,$Key,$HashColumn,$AddRow) = @_;
	if (defined($self->{"hash columns"}->{$HashColumn}->{$Key}->[0])) {
		return $self->{"hash columns"}->{$HashColumn}->{$Key}->[0];
	} elsif (defined($AddRow) && $AddRow == 1) {
		my $NewRow = {$HashColumn => [$Key]};
		$self->add_row($NewRow);
		return $NewRow;
	}
	return undef;
}

=head3 get_rows_by_key
Definition:
	my @RowObjects = $TableObj->get_rows_by_key($Key);
Description:
	Returns the list of row objects that match the input key. Returns an empty list if nothing matches the input key.
Example:
	my @RowObjects = $TableObj->get_rows_by_key("rxn00001");
=cut

sub get_rows_by_key {
	my ($self,$Key,$HashColumn) = @_;

	if (defined($self->{"hash columns"}->{$HashColumn}->{$Key})) {
		return @{$self->{"hash columns"}->{$HashColumn}->{$Key}};
	}
	return ();
}


=head3 get_table_by_key
Definition:
	my $NewTable = $TableObj->get_table_by_key();
Description:
	Returns a new table object where every row matches the input key/data combo.
	Returns an empty table if no rows match the input key/data combo.
Example:
	my $NewTable = $TableObj->get_table_by_key();
=cut

sub get_table_by_key {
	my ($self,$Key,$HashColumn) = @_;

	my $NewTable = $self->clone_table_def();
	my @Rows = $self->get_rows_by_key($Key,$HashColumn);
	for (my $i=0; $i < @Rows; $i++) {
		$NewTable->add_row($Rows[$i]);
	}

	return $NewTable;
}

=head3 get_hash_column_keys
Definition:
	my @HashKeys = $TableObj->get_hash_column_keys($HashColumn);
Description:
	Returns the list of the keys stored in the hash of the values in the column labeled $HashColumn.
Example:
	my @HashKeys = $TableObj->get_hash_column_keys("Media");
=cut

sub get_hash_column_keys {
	my ($self,$HashColumn) = @_;
	if (defined($self->{"hash columns"}->{$HashColumn})) {
		return keys(%{$self->{"hash columns"}->{$HashColumn}});
	}
	return ();
}

=head3 add_row
Definition:
	$TableObj->add_row($row_object);
Description:
	Adds a row to the table.
Example:
	$TableObj->add_row({"COLUMN 1" => ["A"],"COLUMN 2" => ["B"]});
=cut

sub add_row {
	my ($self,$RowObject,$RowIndex) = @_;
	if (defined($RowIndex)) {
		splice(@{$self->{"array"}},$RowIndex,1,$RowObject);
	} else {
		push(@{$self->{"array"}},$RowObject);
	}
	my @HashHeadings = $self->hash_headings();
	foreach my $HashHeading (@HashHeadings) {
		if (defined($RowObject->{$HashHeading})) {
			for (my $i=0; $i < @{$RowObject->{$HashHeading}}; $i++) {
			#	push(@{$self->{$RowObject->{$HashHeading}->[$i]}},$RowObject); # PROBABLY NOT BEING USED NOW
				push(@{$self->{"hash columns"}->{$HashHeading}->{$RowObject->{$HashHeading}->[$i]}},$RowObject);
			}
		}
	}
	return $RowObject;
}

=head3 sort_rows
Definition:
	$TableObj->sort_rows($sortcolumn);
Description:
	Sorts the rows in the table by the specified column
Example:
=cut

sub sort_rows {
	my ($self,$sortcolumn) = @_;
	if (defined($self->{"array"})) {
		@{$self->{"array"}} = sort { $a->{$sortcolumn}->[0] cmp $b->{$sortcolumn}->[0] } @{$self->{"array"}};
	}
}

=head3 replace_row
Definition:
	$TableObj->replace_row($OriginalRow,$NewRow);
Description:
	Replaces the original row in the table with the new row.
Example:
=cut

sub replace_row {
	my ($self,$OriginalRow,$NewRow) = @_;

	for (my $i=0; $i < $self->size(); $i++) {
		if ($self->get_row($i) == $OriginalRow) {
			$self->{"array"}->[$i] = $NewRow;
			last;
		}
	}
}

=head3 add_row_copy
Definition:
	$TableObj->add_row_copy($OriginalRow,$NewRow);
Description:
	Replaces the original row in the table with the new row.
Example:
=cut

sub add_row_copy {
	my ($self,$OriginalRow) = @_;

	my @HashKeys = keys(%{$OriginalRow});
	my $NewRow;
	foreach my $Key (@HashKeys) {
		$NewRow->{$Key} = $OriginalRow->{$Key};
	}

	$self->add_row($NewRow);
	return $NewRow;
}

=head3 add_data
Definition:
	$TableObj->add_data($Row,"TEST",1,1);
Description:
	Deletes a row from the table.
Example:
	$TableObj->delete_row(1);
=cut

sub add_data {
	my ($self,$RowObject,$Heading,$Data,$Unique) = @_;

	#First checking that the input row exists
	if (!defined($RowObject) || !defined($Data)) {
		return -1;
	}

	if (ref($Data) eq 'ARRAY') {
		my $Indecies;
		for (my $i=0; $i < @{$Data}; $i++) {
			$Indecies->[$i] = $self->add_data($RowObject,$Heading,$Data->[$i],$Unique);
		}
		return $Indecies;
	}

	#Now checking if the heading exists in the row
	if (defined($Unique) && $Unique == 1 && defined($RowObject->{$Heading})) {
		for (my $i=0; $i < @{$RowObject->{$Heading}}; $i++) {
			if ($RowObject->{$Heading}->[$i] eq $Data) {
				return $i;
			}
		}
	}

	#Adding the data
	push(@{$RowObject->{$Heading}},$Data);
	my @HashHeadings = $self->hash_headings();
	foreach my $HashHeading (@HashHeadings) {
		if ($HashHeading eq $Heading) {
			push(@{$self->{$Data}},$RowObject);
			push(@{$self->{"hash columns"}->{$HashHeading}->{$Data}},$RowObject);
			last;
		}
	}
	my $Index = (@{$RowObject->{$Heading}}-1);

	return $Index;
}

=head3 update_data
Definition:
	$TableObj->update_data($Row,"TEST",1,1);
Description:
	Updates a row with the data for a specified heading.
Example:
	$TableObj->update_data($Row,"TEST",1,1);
=cut

sub update_data {
    my ($self,$RowObject,$Heading,$Data,$Unique) = @_;
    
    #First checking that the input row exists
    if (!defined($RowObject) || !defined($Data)) {
	return -1;
    }
    
    if (ref($Data) eq 'ARRAY') {
	my $Indecies;
	for (my $i=0; $i < @{$Data}; $i++) {
	    $Indecies->[$i] = $self->update_data($RowObject,$Heading,$Data->[$i],$Unique);
	}
	return $Indecies;
    }
    
    #Now checking if the heading exists in the row
    if (defined($Unique) && $Unique == 1 && defined($RowObject->{$Heading})) {
	for (my $i=0; $i < @{$RowObject->{$Heading}}; $i++) {
	    $RowObject->{$Heading}->[$i]=$Data;
	    return $i;
	}
    }
}

=head3 remove_data
Definition:
	$TableObj->remove_data($Row,"HEADING","TEST");
Description:
	Deletes a element of data from the input row
Example:
	$TableObj->remove_data(1);
=cut

sub remove_data {
	my ($self,$RowObject,$Heading,$Data) = @_;

	#First checking that the input row exists
	if (!defined($RowObject)) {
		return 0;
	}

	#Now checking if the heading exists in the row
	if (defined($RowObject->{$Heading})) {
		for (my $i=0; $i < @{$RowObject->{$Heading}}; $i++) {
			if ($RowObject->{$Heading}->[$i] eq $Data) {
				splice(@{$RowObject->{$Heading}},$i,1);
				$i--;
			}
		}
		if (defined($self->{"hash columns"}->{$Heading}) && defined($self->{"hash columns"}->{$Heading}->{$Data})) {
			if (@{$self->{"hash columns"}->{$Heading}->{$Data}} == 1) {
				delete $self->{"hash columns"}->{$Heading}->{$Data};
			} else {
				for (my $j=0; $j < @{$self->{"hash columns"}->{$Heading}->{$Data}}; $j++) {
					if ($self->{"hash columns"}->{$Heading}->{$Data}->[$j] eq $RowObject) {
						splice(@{$self->{"hash columns"}->{$Heading}->{$Data}},$j,1);
						$j--;
					}
				}
			}
		}
	}

	return 1;
}

=head3 row_index
Definition:
	$TableObj->row_index($Row);
Description:
	Returns the index in the table where the input row is stored.
	This only works if the input $Row object was pulled from the table using one of the get_row functions.
	Returns undef if the row could not be found.
Example:
	$TableObj->row_index($Row);
=cut

sub row_index {
	my ($self,$Row) = @_;

	for (my $i=0; $i < $self->size(); $i++) {
		if ($self->get_row($i) == $Row) {
			return $i;
		}
	}

	return undef;
}

=head3 delete_row_by_key
Definition:
	$TableObj->delete_row_by_key($Key,$Heading);
Description:
	Deletes a row from the table based on the input key and heading that the key will be stored under.
	Returns 1 if a row was found and deleted. Returns 0 if no row was found.
Example:
	$TableObj->delete_row_by_key("Core83333.1","Model ID");
=cut

sub delete_row_by_key {
	my ($self,$Key,$Heading) = @_;

	my $Row = $self->get_row_by_key($Key,$Heading);
	if (defined($Row)) {
		$self->delete_row($self->row_index($Row));
		return 1;
	}
	return 0;
}

=head3 clone_table_def
Definition:
	my $NewTable = $TableObj->get_clone_table();
Description:
	Returns a new *empty* table with the same headings, hash headings, and delimiters as the input table.
Example:
	my $NewTable = $TableObj->get_clone_table();
=cut

sub clone_table_def {
	my ($self) = @_;

	my $HeadingRef;
	push(@{$HeadingRef},$self->headings());
	my $HashHeadingRef;
	push(@{$HashHeadingRef},$self->hash_headings());

	my $TableObj = ModelSEED::FIGMODEL::FIGMODELTable->new($HeadingRef,$self->filename(),$HashHeadingRef,$self->delimiter(),$self->item_delimiter(),$self->{"file IO settings"}->{"file prefix"}->[0]);
	return $TableObj;
}

=head3 clone_row
Definition:
	my $NewRow = $TableObj->clone_row($Index);
Description:
	Returns an exact copy of row located at $Index
Example:
	my $NewRow = $TableObj->clone_row(5);
=cut

sub clone_row {
	my ($self,$Index) = @_;

	my @Headings = $self->headings();
	my $NewRow;
	for (my$k=0; $k < @Headings; $k++) {
		if (defined($self->get_row($Index)->{$Headings[$k]})) {
			push(@{$NewRow->{$Headings[$k]}},@{$self->get_row($Index)->{$Headings[$k]}});
		}
	}

	return $NewRow;
}

=head3 delete_row
Definition:
	$TableObj->delete_row($i);
Description:
	Deletes a row from the table.
Example:
	$TableObj->delete_row(1);
=cut

sub delete_row {
	my ($self,$RowIndex) = @_;
	my @HashHeadings = $self->hash_headings();
	foreach my $HashHeading (@HashHeadings) {
		my $RowObject = $self->get_row($RowIndex);
		if (defined($RowObject->{$HashHeading})) {
			for (my $i=0; $i < @{$RowObject->{$HashHeading}}; $i++) {
				if (defined($self->{$RowObject->{$HashHeading}->[$i]})) {
					for (my $j =0; $j < @{$self->{$RowObject->{$HashHeading}->[$i]}}; $j++) {
						if ($self->{$RowObject->{$HashHeading}->[$i]}->[$j] eq $RowObject) {
							if ($j == 0 && @{$self->{$RowObject->{$HashHeading}->[$i]}} == 1) {
								delete $self->{$RowObject->{$HashHeading}->[$i]};
								last;
							} else {
								splice(@{$self->{$RowObject->{$HashHeading}->[$i]}},$j,1);
								$j--;
							}
						}
					}
				}
				if (defined($self->{"hash columns"}->{$HashHeading}->{$RowObject->{$HashHeading}->[$i]})) {
					for (my $j =0; $j < @{$self->{"hash columns"}->{$HashHeading}->{$RowObject->{$HashHeading}->[$i]}}; $j++) {
						if ($self->{"hash columns"}->{$HashHeading}->{$RowObject->{$HashHeading}->[$i]}->[$j] eq $RowObject) {
							if ($j == 0 && @{$self->{"hash columns"}->{$HashHeading}->{$RowObject->{$HashHeading}->[$i]}} == 1) {
								delete $self->{"hash columns"}->{$HashHeading}->{$RowObject->{$HashHeading}->[$i]};
								last;
							} else {
								splice(@{$self->{"hash columns"}->{$HashHeading}->{$RowObject->{$HashHeading}->[$i]}},$j,1);
								$j--;
							}
						}
					}
				}
			}
		}
	}
	splice(@{$self->{"array"}},$RowIndex,1);
}

=head3 add_headings
Definition:
	$TableObj->add_headings(@Headings);
Description:
	Adds new headings to the table. This is needed to get the table to print the data under the new heading.
Example:
	$TableObj->add_headings("Notes");
=cut

sub add_headings {
	my ($self,@Headings) = @_;
	foreach my $Heading (@Headings) {
		#First check if the heading already exists
		foreach my $ExistingHeading ($self->headings()) {
			if ($Heading eq $ExistingHeading) {
				$Heading = "";
				last;
			}
		}
		if ($Heading ne "") {
			push(@{$self->{"file IO settings"}->{"orderedkeys"}},$Heading);
		}
	}
}

sub is_heading {
	my ($self,$heading) = @_;
	foreach my $ExistingHeading ($self->headings()) {
		if ($heading eq $ExistingHeading) {
			return 1;
		}
	}
	return 0;
}

sub is_indexed {
	my ($self,$heading) = @_;
	if (defined($self->{"hash columns"}->{$heading})) {
		return 1;
	}
	return 0;
}

=head3 add_hashheadings
Definition:
	$TableObj->add_hashheadings(@Headings);
Description:
	Adds new hash headings to the table. This is needed to get the table to print the data under the new heading.
Example:
	$TableObj->add_hashheadings("Notes");
=cut

sub add_hashheadings {
	my ($self,@HashHeadings) = @_;

	foreach my $HashHeading (@HashHeadings) {
		if (!defined($self->{"hash columns"}->{$HashHeading})) {
			$self->{"hash columns"}->{$HashHeading} = {};
			for (my $i=0; $i < $self->size(); $i++) {
				my $Row = $self->get_row($i);
				if (defined($Row->{$HashHeading})) {
					for (my $j=0; $j < @{$Row->{$HashHeading}}; $j++) {
						push(@{$self->{"hash columns"}->{$HashHeading}->{$Row->{$HashHeading}->[$j]}},$Row);
					}
				}
			}
		}
	}
}

=head3 save
Definition:
	$TableObj->save($filename,$delimiter,$itemdelimiter,$prefix);
Description:
	Saves the table to the specified filename with the specified column delimiter and subcolumn delimiter, and file prefix (lines that appear before the table heading in the file).
	All arguments are optional. If arguments are not supplied, the values used to read the table from file will be used.
Example:
	$TableObj->save("/vol/Table.txt",";","|","REACTIONS");
=cut

sub save {
	my ($self,$filename,$delimiter,$itemdelimiter,$prefix) = @_;
	if (defined($self->{_freezeFileSyncing}) && $self->{_freezeFileSyncing} == 1) {
		return;
	}
	if (defined($filename)) {
		$self->{"file IO settings"}->{"filename"}->[0] = $filename;
	}
	if (defined($delimiter)) {
		$self->{"file IO settings"}->{"delimiter"}->[0] = $delimiter;
	}
	if (defined($itemdelimiter)) {
		$self->{"file IO settings"}->{"item delimiter"}->[0] = $itemdelimiter;
	}
	if (defined($prefix)) {
		$self->{"file IO settings"}->{"file prefix"}->[0] = $prefix;
	}
	$self->print_table_to_file();
}

sub print_table_to_file {
	my ($self) = @_;

	#Checking that a filename exists
	if (!defined($self->{"array"}) || !defined($self->{"file IO settings"}->{"filename"}) || !defined($self->{"file IO settings"}->{"orderedkeys"})) {
		return -1;
	}

	my $Filename = $self->{"file IO settings"}->{"filename"}->[0];
	my $Delimiter = ";";
	my $ItemDelimiter = "|";
	my $Prefix = "";
	if (defined($self->{"file IO settings"}->{"delimiter"})) {
		$Delimiter = $self->{"file IO settings"}->{"delimiter"}->[0];
		if ($Delimiter eq "\\|" || $Delimiter eq "\|") {
			$Delimiter = "|";
		} elsif ($Delimiter eq "\\t") {
			$Delimiter = "\t";
		}
	}
	if (defined($self->{"file IO settings"}->{"item delimiter"})) {
		$ItemDelimiter = $self->{"file IO settings"}->{"item delimiter"}->[0];
		if ($ItemDelimiter eq "\\|" || $ItemDelimiter eq "\|") {
			$ItemDelimiter = "|";
		} elsif ($ItemDelimiter eq "\\t") {
			$ItemDelimiter = "\t";
		}
	}
	if (defined($self->{"file IO settings"}->{"file prefix"})) {
		$Prefix = $self->{"file IO settings"}->{"file prefix"}->[0];
	}

	#Opening the file
	if (defined($self->{"file IO settings"}->{"append"})) {
		if (!open (SAVINGTABLE, ">>$Filename")) {
			return -1;
		}
	} else {
		if (!open (SAVINGTABLE, ">$Filename")) {
			return -1;
		}
	}

	if (defined($Prefix)) {
		print SAVINGTABLE $Prefix;
	}
	print SAVINGTABLE join($Delimiter,@{$self->{"file IO settings"}->{"orderedkeys"}})."\n";
	for (my $i=0; $i < @{$self->{"array"}}; $i++) {
		for (my $j=0; $j < @{$self->{"file IO settings"}->{"orderedkeys"}}; $j++) {
			if ($j > 0) {
				print SAVINGTABLE $Delimiter;
			}
			if (defined($self->{"array"}->[$i]->{$self->{"file IO settings"}->{"orderedkeys"}->[$j]})) {
				if(ref($self->{"array"}->[$i]->{$self->{"file IO settings"}->{"orderedkeys"}->[$j]}) eq 'ARRAY') {
					print SAVINGTABLE join($ItemDelimiter,@{$self->{"array"}->[$i]->{$self->{"file IO settings"}->{"orderedkeys"}->[$j]}});
				} else {
					print SAVINGTABLE $self->{"array"}->[$i]->{$self->{"file IO settings"}->{"orderedkeys"}->[$j]};
				}
			}
		}
		print SAVINGTABLE "\n";
	}
	close (SAVINGTABLE);
}

=head3 html_print
Definition:
	string::html_text = FIGMODELTable::my_table->html_print(void);
Description:
	This function returns the table contents in html format for simple display on a webpage.
Example:
=cut

sub html_print {
	my ($self) = @_;

	#Printing the table headings first
	my $html = "<table><tr>";
	my @Headings = $self->headings();
	for (my $i=0; $i < @Headings; $i++) {
		$html .= "<th align='left'>".$Headings[$i]."</th>";
	}
	$html .= "</tr>\n";

	#Printing the table rows
	for (my $j=0; $j < $self->size(); $j++) {
		my $Row = $self->get_row($j);
		$html .= "<tr>";
		for (my $i=0; $i < @Headings; $i++) {
			$html .= "<td>";
			if (defined($Row->{$Headings[$i]})) {
				$html .= join("|",@{$Row->{$Headings[$i]}});
			}
			$html .= "</td>";
		}
		$html .= "</tr>\n";
	}
	$html .= "</table>";

	return $html;
}

=head3 load
Definition:
	my $Table = load_table($Filename,$Delimiter,$ItemDelimiter,$HeadingLine,$HashColumns);
Description:

Example:
	my $Table = load_table($Filename,$Delimiter,$ItemDelimiter,$HeadingLine,$HashColumns);
=cut

sub load_table {
    my $args = shift @_;
    my ($Filename,$Delimiter,$ItemDelimiter,$HeadingLine,$HashColumns) = undef;
    if(ref($args) eq 'HASH') {
        $Filename = $args->{filename};    
        $Delimiter = $args->{delimiter};    
        $ItemDelimiter = $args->{itemDelimiter};    
        $HeadingLine = $args->{headingLine};
        $HashColumns = $args->{hashColumns};
    } else {
        $Filename = $args;
        ($Delimiter,$ItemDelimiter,$HeadingLine,$HashColumns) = @_;
    }

	#Checking that the table file exists
	if (!-e $Filename) {
		return undef;
	}

	#Sanity checking input values
	if (!defined($HeadingLine) || $HeadingLine eq "") {
		$HeadingLine = 0;
	}
	if (!defined($Delimiter) || $Delimiter eq "") {
		$Delimiter = ";";
	}
	if ($Delimiter eq "|") {
		$Delimiter = "\\|";
	}
	if (!defined($ItemDelimiter) || $ItemDelimiter eq "") {
		$ItemDelimiter = "";
	} elsif ($ItemDelimiter eq "|") {
		$ItemDelimiter = "\\|";
	}

	#Loading the data table
	my $Prefix;
	my @Headings;
	if (!open (TABLEINPUT, "<$Filename")) {
		return undef;
	}
	my $Line = <TABLEINPUT>;
	for (my $i=0; $i < $HeadingLine; $i++) {
		$Prefix .= $Line;
		$Line = <TABLEINPUT>;
	}
	chomp($Line);
	@Headings = split(/$Delimiter/,$Line);
	my $headingCount = @Headings;
	my $HeadingRef;
	push(@{$HeadingRef},@Headings);
	my $Table = new ModelSEED::FIGMODEL::FIGMODELTable($HeadingRef,$Filename,$HashColumns,$Delimiter,$ItemDelimiter,$Prefix);
	while ($Line = <TABLEINPUT>) {
		chomp($Line);
		my @Data = split(/$Delimiter/,$Line);
		my $ArrayRefHashRef;
		for (my $i=0; $i < @Headings; $i++) {
			if (defined($Data[$i]) && length($Data[$i]) > 0) {
				if (defined($ItemDelimiter) && length($ItemDelimiter) > 0) {
					my @TempArray = split(/$ItemDelimiter/,$Data[$i]);
					foreach my $Item (@TempArray) {
						push(@{$ArrayRefHashRef->{$Headings[$i]}},$Item);
					}
				} else {
					$ArrayRefHashRef->{$Headings[$i]}->[0] = $Data[$i];
				}
			}
		}
		$Table->add_row($ArrayRefHashRef);
	}
	close(TABLEINPUT);

	return $Table;
}

=head3 connect_to_db
Definition:
	integer::status = FIGMODELTable->connect_to_db(string::table name,string::database,string::user,host::host)
Description:
	Connects to the database for input and output for the table to and from the database
=cut

sub connect_to_db {
	my ($self,$Table,$Database,$Username,$Host,$SubTableHeadings,$TableKey) = @_;

	#Getting DB data from arguments
	my $Changed = 0;
	if (!defined($Host)) {
		$Host = $self->{_host};
	} elsif (!defined($self->{_host}) || $Host ne $self->{_host}) {
		$Changed = 1;
	}
	if (!defined($Table)) {
		$Table = $self->{_table};
	} elsif (!defined($self->{_table}) || $Table ne $self->{_table}) {
		$Changed = 1;
	}
	if (!defined($Database)) {
		$Database = $self->{_database};
	} elsif (!defined($self->{_database}) || $Database ne $self->{_database}) {
		$Changed = 1;
	}
	if (!defined($Username)) {
		$Username = $self->{_user};
	} elsif (!defined($self->{_user}) || $Username ne $self->{_user}) {
		$Changed = 1;
	}
	if (!defined($Username)) {
		$Username = $self->{_user};
	} elsif (!defined($self->{_user}) || $Username ne $self->{_user}) {
		$Changed = 1;
	}
	if (defined($SubTableHeadings)) {
		for (my $i=0; $i < @{$SubTableHeadings}; $i++) {
			$self->{_subheadings}->{$SubTableHeadings->[$i]} = 1;
		}
	}
	if (defined($TableKey)) {
		$self->{_tablekey} = $TableKey;
	}

	#If no change, then we leave
	if ($Changed == 0) {
		return 1;
	}

	#If the connection data was changed, we reconnect to the database
	if (defined($self->{_dbhandle})) {
		#Closing any previous connection
		delete $self->{_dbhandle};
	}

	#Checking if DBMaster is even available
	eval {
		require "DBMaster.pm";
	};
	if ($@) {
		print STDERR "FIGMODELTable:connect_to_db:Cannot connect to database because DBMaster module is unavailable\n";
		return -1;
	}

	$self->{_dbhandle} = DBMaster->new(-database => $Database, -user => $Username, -host => $Host);
	$self->{_dbtable} = $self->{_dbhandle}->$Table;

	#Check that the connection was successful
	if (!defined($self->{_dbhandle})) {
		print STDERR "FIGMODELTable:save_to_db: could not connect to database with ".$Database.";".$Table.";".$Username.";".$Host."\n";
		return -1;
	}

	return 1;
}

=head3 save_to_db
Definition:
	integer::status = FIGMODELTable->save_to_db(string::table name,string::database,string::user,host::host)
Description:
	Syncs the FIGMODELTable and the database
=cut

sub save_to_db {
	my ($self,$Table,$Database,$Username,$Host,$SubTableHeadings,$TableKey) = @_;

	#Connecting to database
	if ($self->connect_to_db($Table,$Database,$Username,$Host,$SubTableHeadings,$TableKey) == -1) {
		return -1;
	}

	#Saving the table
	for (my $i=0; $i < $self->size(); $i++) {
		my $Row = $self->get_row($i);
		$self->update_db_row($Row);
	}

	return 1;
}

=head3 update_db_row
Definition:
	integer::status = FIGMODELTable->update_db_row(FIGMODELTable::Row::row to be updated)
Description:
	Updates the input row in the database. Returns -1 upon failure, 0 if there was no change, 1 if the row is new, 2 if the row was changed
=cut

sub update_db_row {
	my ($self,$row) = @_;

	#Checking that the database is connected
	if (!defined($self->{_dbhandle})) {
		print STDERR "FIGMODELTable:update_db_row: need to be connected to database prior to update of row.\n";
		return -1;
	}

	#Checking if a row with the same table key already exists in the table
	if (!defined($row->{_dbhandle}) && defined($self->{_tablekey}) && defined($row->{$self->{_tablekey}}->[0])) {
		$row->{_dbhandle} = $self->{_dbtable}->init( { $self->{_tablekey} => $row->{$self->{_tablekey}}->[0] } );
	}

	#Checking if the row has a dbhandle
	if (defined($row->{_dbhandle})) {
		#This is not a new row-first we check if anything has changed
	} else {
		#First we add the base object to the table on the server
		my $NewObject;
		my @Headings = $self->headings();
		for (my $i=0; $i < @Headings; $i++) {
			if (defined($row->{$Headings[$i]}->[0])) {
				if (!defined($self->{_subheadings}->{$Headings[$i]})) {
					$NewObject->{$Headings[$i]} = join($self->item_delimiter(),@{$row->{$Headings[$i]}});
				}
			}
		}
		$row->{_dbhandle} = $self->{_dbtable}->create($NewObject);
		#Now we add all of the subtable objects
		for (my $i=0; $i < @Headings; $i++) {
			if (defined($row->{$Headings[$i]}->[0])) {
				if (defined($self->{_subheadings}->{$Headings[$i]})) {
					#Adding the subtable rows to the database
					for (my $j=0; $j < @{$row->{$Headings[$i]}}; $j++) {
						#my $Object = $self->{_dbtable}->init( { $self->{_tablekey} => $row->{$self->{_tablekey}}->[0] } );
					}
				}
			}
		}
	}

	return 1;
}

=head3 set_metadata
Definition:
	FIGMODELTable->set_metadata(string::key,string::data);
Description:
	Sets a specified metadata for the table
=cut
sub set_metadata {
	my ($self,$key,$data) = @_;
	$self->{_metadata}->{$key} = $data;
}

=head3 get_meta_data
Definition:
	string::data = FIGMODELTable->get_meta_data(string::key);
Description:
	Sets a specified metadata for the table
=cut
sub get_meta_data {
	my ($self,$key,$data) = @_;
	return $self->{_metadata}->{$key};
}

=head3 add_column
Definition:
	FIGMODELTable->add_column(array, string);
	FIGMODELTable->add_column(function(hash), string);
Descrition:
	Adds a column to the table under column name string. If the first
	argument is an array, it places the content of the i-th elment of
	the array in row i for the new column. If the first argument is a
	function operating over a hash, the output of that function
	run over the i-th row is placed in the new column for row i.
	Just be sure to pass function sub foo { ... } as \&PACKAGE::PATH::foo
=cut
sub add_column {
	my ($self, $arg, $column_name) = @_;
	if( ref($arg) == 'CODE' ) {
		# $arg is a function, apply to all rows
		my @columnData = [];
		for( my $i = 0; $i < $self->size(); $i++ ) {
			my $row = $self->get_row($i);
			my $entry = &$arg($row);
			$row->{$column_name} = $entry;
		}
	} elsif ( ref($arg) == 'ARRAY' ) {
		for( my $i = 0; $i < $self->size(); $i++ ) {
			if( $i > @{$arg} ) { return; }
			my $row = $self->get_row($i);
			$row->{$column_name} = $arg->[$i];
		}
	}
}


=head3 remove_column
Defintion:
	FIGMODELTable->remove_column(string)
Description:
	Removes column whose name matches string.
=cut
sub remove_column {
	my ($self, $column_name) = @_;
	for( my $i = 0; $i < $self->size(); $i++ ) {
		my $row = $self->get_row($i);
		if(defined($row->{$column_name})) {
			delete($row->{$column_name});
		}
	}
}	
	
=head2 Excel Output Methods

=head3 add_as_sheet 
Definition:
    FIGMODELTable->add_as_sheet(string:sheet name, 
                                string:filename || Spreadsheet::WriteExcel::Workbook
Description:
    Adds a sheet to an excel file containing the contents of the table.
    The first argument is the sheet name for this table. The second
    required argument is either a string for the Excel filename to be
    created or an existing Spreadsheet::WriteExcel::Workbook object.
    Returns a Spreadsheet::WriteExcel::Workbook object:
    i.e. my $workbook = $table->add_as_sheet('my first sheet', 'my_file.xls');
    (Hint: call $workbook->close(); to write my_file.xls to disk!)
=cut
sub add_as_sheet {
    my ($self, $sheet_name, $workbook) = @_;
    unless(defined($sheet_name) && defined($workbook)) {
        return undef;
    }
    my $wkbk;
    if(ref($workbook) eq undef) { # isa file name
        $wkbk = Spreadsheet::WriteExcel->new($workbook);
    } elsif(ref($workbook) eq 'Spreadsheet::WriteExcel') {
        $wkbk = $workbook;
    } else {
        return undef;
    }
    my $sheet = $wkbk->add_worksheet($sheet_name);
    my @headings = $self->headings(); 
    $sheet->write_row(0,0, \@headings);
    my $item_delimiter = $self->item_delimiter();
    for(my $i=0; $i<$self->size(); $i++) {
        my $row = $self->get_row($i);
        my $row_data = [];
        for(my $j=0; $j < @headings; $j++) {
            my $heading = $headings[$j];
            if(defined($row->{$heading})) { 
                $sheet->write_string($i+1, $j, join("$item_delimiter", @{$row->{$heading}}));
            } else {
                $sheet->write_string($i+1, $j, "");
            }
        }
    }
    return $wkbk;
}


=head2 FIGMODELdatabase Compatibility


=cut

sub get_object {
    my ($self, $query) = @_;
    my $objs = $self->get_objects($query);
    return (@$objs > 0) ? $objs->[0] : undef;
}

sub get_objects {
    my ($self, $query) = @_;
    my $result_tbl = $self->get_rows();
    my %hash_headings = map { $_ => $_ } $self->hash_headings();
    if(!defined($query) || scalar(keys %$query) == 0) {
        # don't change anything
    } elsif (scalar(keys %$query) == 1) {
       my $key = (keys %$query)[0];
       $result_tbl = [$self->get_rows_by_key($query->{$key}, $key)];
    } else {
        my $tmp_results = { map { $_ => $_ } @$result_tbl };
        foreach my $key (keys %$query) {
            my $value = $query->{$key};
            if(not defined($hash_headings{$key})) {
                $self->add_hashheadings([$key]);
                %hash_headings = map { $_ => $_ } $self->hash_headings();
            }
            my $map = { map { $_ => $_ } $self->get_rows_by_key($value, $key) };
            foreach my $key (keys %$map) {
                if(!defined($tmp_results->{$key})) {
                    delete $map->{$key};
                }
            }
            $tmp_results = $map;
        }
        $result_tbl = [values %$tmp_results]; 
    }
    my @results = @$result_tbl;
    return [map { ModelSEED::FIGMODEL::FIGMODELTableRow->new($_, $self); } @results];
}

sub create_object {
    my ($self, $hash) = @_;
    my %headings = map {$_ => $_} $self->headings();
    my $delim = $self->item_delimiter();
    for my $key (keys %$hash) {
        if(not defined($headings{$key})) {
            $self->add_headings([$key]);
            %headings = map {$_ => $_} $self->headings();
        }
        $hash->{$key} = [split(/$delim/, $hash->{$key})];
    }
    $self->add_row($hash);
    $self->save();
    return ModelSEED::FIGMODEL::FIGMODELTableRow->new($hash, $self);
}

sub create {
    my ($self, $hash) = @_;
    $self->create_object($hash);
}

1;
