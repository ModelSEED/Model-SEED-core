use strict;
use FileHandle;
use Fcntl qw/:DEFAULT :seek :flock/;
use Symbol 'qualify_to_ref';

my $have_fsync;
eval {
	require File::Sync;
	$have_fsync++;
};


#--- This function just prints the given array reference to file with a different array element on each line ---#
sub PrintArrayToFile {
	my ($Filename,$ArrayRef,$Append) = @_;

	if (defined($Append) && $Append == 1) {
		open (OUTPUT, ">>$Filename");
	} else {
		open (OUTPUT, ">$Filename");
	}
	foreach my $Item (@{$ArrayRef}) {
		if (length($Item) > 0) {
			print OUTPUT $Item."\n";
		}
	}
	close(OUTPUT);
}

sub PrintTwoDimensionalArrayToFile {
	my ($Filename,$ArrayRef,$Delimiter) = @_;

	if (open (OUTPUT, ">$Filename")) {
		foreach my $Item (@{$ArrayRef}) {
			if (@{$Item} > 0) {
				print OUTPUT join($Delimiter,@{$Item})."\n";
			}
		}
		close(OUTPUT);
	} else {
		die "Cannot open $Filename: $!";
	}
}


#--- This function removes the specified line from the file with the input filename if the line exists in the file ---#
sub RemoveSpecificLineFromFile {
	my ($Filename,$DelLine,$Delimiter) = @_;

	#Note that I donot specify the delimiter to the file upload function because I want to preserve the entire content of the file
	my $FileArray = &LoadSingleColumnFile($Filename,"");
	my $Count = 0;
	foreach my $Item (@{$FileArray}) {
		my @Data = split(/$Delimiter/,$Item);
		if ($Data[0] eq $DelLine) {
			delete $FileArray->[$Count];
		}
		$Count++;
	}
	&PrintArrayToFile($Filename,$FileArray);
}

#--- This function adds the input line to the file with the input filename if the line does not already exist in the file ---#
sub AddLineToFileUnique {
	my ($Filename,$NewLine,$Delimiter) = @_;
	my $FileArray = &LoadSingleColumnFile($Filename,$Delimiter);
	my $LastLineLength = 0;
	foreach my $Item (@{$FileArray}) {
		$LastLineLength = length($Item);
		if ($Item eq $NewLine) {
			return;
		}
	}
	if (open (OUTPUT, ">>$Filename")) {
		if ($LastLineLength > 0) {
			print OUTPUT "\n";
		}
		print OUTPUT $NewLine."\n";
		close(OUTPUT);
	} else {
		die "Cannot open $Filename: $!";
	}
}

#--- This function saves the input hash back to a file where each data item is stored on a separate line with the file headings stored in the first column of data ---#
sub SaveHashToHorizontalDataFile {
	my ($Filename,$Delimiter,$DataHashRef) = @_;

	if (!defined($DataHashRef->{"orderedkeys"})) {
		my @Keys = keys(%{$DataHashRef});
		push(@{$DataHashRef->{"orderedkeys"}},@Keys);
	}

	if ($Filename eq "") {
		open (HASHTOHORIZONTALOUTPUT, ">&STDOUT");
	} else {
		open (HASHTOHORIZONTALOUTPUT, ">$Filename");
	}

	if (open (HASHTOHORIZONTALOUTPUT, ">$Filename")) {
		my @ReactionKeys = @{$DataHashRef->{"orderedkeys"}};
		foreach my $Item (@ReactionKeys) {
			if (defined($DataHashRef->{"keytranslation"}) && defined($DataHashRef->{"keytranslation"}->{$Item})) {
				$Item = $DataHashRef->{"keytranslation"}->{$Item};
			}
			if (defined($DataHashRef->{$Item}) && @{$DataHashRef->{$Item}} > 0) {
				print HASHTOHORIZONTALOUTPUT $Item.$Delimiter.join($Delimiter,@{$DataHashRef->{"$Item"}})."\n";
			}
		}
		close(HASHTOHORIZONTALOUTPUT);
	} else {
		die "Cannot open $Filename: $!";
	}

	return $DataHashRef;
}

#--- This function loads a file where each data item is stored on a separate line with the file headings stored in the first column of data ---#
sub LoadHorizontalDataFile {
	my ($Filename,$Delimiter,$HeadingTranslation) = @_;

	my $DataHashRef = {};

	if (open (INPUT, "<$Filename")) {
		while (my $Line = <INPUT>) {
			chomp($Line);
			my @Data = split(/$Delimiter/,$Line);
			if (defined($HeadingTranslation) && defined($HeadingTranslation->{$Data[0]})) {
				$DataHashRef->{"keytranslation"}->{$HeadingTranslation->{$Data[0]}} = $Data[0];
				$Data[0] = $HeadingTranslation->{$Data[0]};
			}
			for (my $i=1; $i < @Data; $i++) {
				$DataHashRef->{$Data[0]}->[$i-1] = $Data[$i];
			}
			if (@Data > 1) {
				push(@{$DataHashRef->{"orderedkeys"}},$Data[0]);
			}
		}
		close(INPUT);
	} else {
		die "Cannot open $Filename: $!";
	}

	return $DataHashRef;
}


#--- This function loads a file containing a simple list and returns a reference to an array containing that list ---#
#--- Note that when a delimiter is supplied, each line in the file is broken up with the delimiter, and only the first element from each line is stored in the returned list ---#
sub LoadSingleColumnFile {
	my ($Filename,$Delimiter) = @_;

	my $DataArrayRef = [];
	if (open (INPUT, "<$Filename")) {
		while (my $Line = <INPUT>) {
			chomp($Line);

			if (length($Delimiter) > 0) {
				my @Data = split(/$Delimiter/,$Line);
				$Line = $Data[0];
			}

			push(@{$DataArrayRef},$Line);
		}
		close(INPUT);
	} else {
		die "Cannot open $Filename: $!";
	}
	return $DataArrayRef;
}

#--- This function loads a file containing multiple columns of data with no file headings ---#
sub LoadMultipleColumnFile {
	my ($Filename,$Delimiter) = @_;

	my $DataArrayRefArrayRef = [];
	if (open (INPUT, "<$Filename")) {
		while (my $Line = <INPUT>) {
			chomp($Line);
			my $Data = [];
			$Data->[0] = $Line;
			if (length($Delimiter) > 0) {
				@{$Data} = split(/$Delimiter/,$Line);
			}
			push(@{$DataArrayRefArrayRef},$Data);
		}
		close(INPUT);
	} else {
		die "Cannot open $Filename: $!";
	}
	return $DataArrayRefArrayRef;
}

#--- This function loads a file containing multiple columns of data with file headings at the top ---#
sub LoadMultipleLabeledColumnFile {
	my ($Filename,$ColumnDelimiter,$ItemDelimiter,$HeadingRowNumber) = @_;
	if (!defined($HeadingRowNumber) || $HeadingRowNumber eq "") {
		$HeadingRowNumber = 0;
	}
	my $DataHashRefArrayRef = [];
	if (open (INPUT, "<$Filename")) {
		my $Line = <INPUT>;
		for (my $i=0; $i < $HeadingRowNumber; $i++) {
			$Line = <INPUT>;
		}
		chomp($Line);
		if (length($ColumnDelimiter) > 0) {
			my @Headings = split(/$ColumnDelimiter/,$Line);
			my $First = 1;
			while ($Line = <INPUT>) {
				chomp($Line);
				my @Data = split(/$ColumnDelimiter/,$Line);
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
				if ($First == 1) {
					$First = 0;
					push(@{$ArrayRefHashRef->{"orderedkeys"}},@Headings);
				}
 				push(@{$DataHashRefArrayRef},$ArrayRefHashRef);
			}
		}
		close(INPUT);
	} else {
		die "Cannot open $Filename: $!";
	}
	return $DataHashRefArrayRef;
}

sub PrintHashArrayToFile {
	my ($Filename,$HashArrayRef,$HeaderRef,$ExtraHeaders) = @_;

	if (!defined($HeaderRef) || $HeaderRef == 0 || $HeaderRef eq "") {
		if (!defined($HashArrayRef->[0]) || !defined($HashArrayRef->[0]->{"orderedkeys"})) {
			return;
		} else {
			$HeaderRef = $HashArrayRef->[0]->{"orderedkeys"};
		}
	}

	if (open (HASHARRAYTOFILE, ">$Filename")) {
		if (defined($ExtraHeaders)) {
			print HASHARRAYTOFILE $ExtraHeaders;
		}
		print HASHARRAYTOFILE join(";",@{$HeaderRef})."\n";
		for (my $i=0; $i < @{$HashArrayRef}; $i++) {
			for (my $j=0; $j < @{$HeaderRef}; $j++) {
				if ($j > 0) {
					print HASHARRAYTOFILE ";";
				}
				if (defined($HashArrayRef->[$i]->{$HeaderRef->[$j]})) {
					print HASHARRAYTOFILE join("|",@{$HashArrayRef->[$i]->{$HeaderRef->[$j]}});
				}
			}
			print HASHARRAYTOFILE "\n";
		}
		close (HASHARRAYTOFILE);
	}
}

sub LoadTable {
	my ($VariableHash,$Filename,$Delimiter,$ItemDelimiter,$HeadingLine,$HashColumns) = @_;

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
	my $Table;
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
		push(@{$Table->{"array"}},$ArrayRefHashRef);
	}
	close(TABLEINPUT);

	#Loading file IO parameters
	$Table->{"file IO settings"}->{"filename"}->[0] = $Filename;
	if ($Delimiter eq "\\|") {
		$Delimiter = "|";
	}
	$Table->{"file IO settings"}->{"delimiter"}->[0] = $Delimiter;
	if ($ItemDelimiter eq "\\|") {
		$ItemDelimiter = "|";
	}
	$Table->{"file IO settings"}->{"item delimiter"}->[0] = $ItemDelimiter;
	$Table->{"file IO settings"}->{"file prefix"}->[0] = $Prefix;
	push(@{$Table->{"file IO settings"}->{"orderedkeys"}},@Headings);
	#Replacing variables in variable columns with variable values and loading hash with hash column keys
	foreach my $ItemData (@{$Table->{"array"}}) {
		if (defined($HashColumns) && $HashColumns ne "") {
			foreach my $Heading (@{$HashColumns}) {
				if (defined($ItemData->{$Heading})) {
					for (my $i=0; $i < @{$ItemData->{$Heading}}; $i++) {
						push(@{$Table->{$ItemData->{$Heading}->[$i]}},$ItemData);
						push(@{$Table->{"hash columns"}->{$Heading}->{$ItemData->{$Heading}->[$i]}},$ItemData);
					}
				}
			}
		}
	}

	return $Table;
}

sub SaveTable {
	my ($TableRef) = @_;

	#Checking that a filename exists
	if (!defined($TableRef->{"array"}) || !defined($TableRef->{"file IO settings"}->{"filename"}) || !defined($TableRef->{"file IO settings"}->{"orderedkeys"})) {
		return -1;
	}

	my $Filename = $TableRef->{"file IO settings"}->{"filename"}->[0];
	my $Delimiter = ";";
	my $ItemDelimiter = "|";
	my $Prefix = "";
	if (defined($TableRef->{"file IO settings"}->{"delimiter"})) {
		$Delimiter = $TableRef->{"file IO settings"}->{"delimiter"}->[0];
		if ($Delimiter eq "\\|" || $Delimiter eq "\|") {
			$Delimiter = "|";
		} elsif ($Delimiter eq "\\t") {
			$Delimiter = "\t";
		}
	}
	if (defined($TableRef->{"file IO settings"}->{"item delimiter"})) {
		$ItemDelimiter = $TableRef->{"file IO settings"}->{"item delimiter"}->[0];
		if ($ItemDelimiter eq "\\|" || $ItemDelimiter eq "\|") {
			$ItemDelimiter = "|";
		} elsif ($ItemDelimiter eq "\\t") {
			$ItemDelimiter = "\t";
		}
	}
	if (defined($TableRef->{"file IO settings"}->{"file prefix"})) {
		$Prefix = $TableRef->{"file IO settings"}->{"file prefix"}->[0];
	}

	#Opening the file
	if (defined($TableRef->{"file IO settings"}->{"append"})) {
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
	print SAVINGTABLE join($Delimiter,@{$TableRef->{"file IO settings"}->{"orderedkeys"}})."\n";
	for (my $i=0; $i < @{$TableRef->{"array"}}; $i++) {
		for (my $j=0; $j < @{$TableRef->{"file IO settings"}->{"orderedkeys"}}; $j++) {
			if ($j > 0) {
				print SAVINGTABLE $Delimiter;
			}
			if (defined($TableRef->{"array"}->[$i]->{$TableRef->{"file IO settings"}->{"orderedkeys"}->[$j]})) {
				if(ref($TableRef->{"array"}->[$i]->{$TableRef->{"file IO settings"}->{"orderedkeys"}->[$j]}) eq 'ARRAY') {
					print SAVINGTABLE join($ItemDelimiter,@{$TableRef->{"array"}->[$i]->{$TableRef->{"file IO settings"}->{"orderedkeys"}->[$j]}});
				} else {
					print SAVINGTABLE $TableRef->{"array"}->[$i]->{$TableRef->{"file IO settings"}->{"orderedkeys"}->[$j]};
				}
			}
		}
		print SAVINGTABLE "\n";
	}
	close (SAVINGTABLE);
}

sub copy_table_row {
	my ($InRow) = @_;

	my $NewRow;
	my @Headings = keys(%{$InRow});
	foreach my $Heading (@Headings) {
		push(@{$NewRow->{$Heading}},@{$InRow->{$Heading}});
	}

	return $NewRow;
}

#--- This function loads a file  with the following on each line: $A$Delimiter$B and maps $A to $B in the first returned hash reference and $B to $A in the second returned hash reference ---#
sub LoadSeparateTranslationFiles {
	my ($Filename,$Delimiter) = @_;
	my $HashReferenceForward = {};
	my $HashReferenceReverse = {};

	if (open (INPUT, "<$Filename")) {
		while (my $Line = <INPUT>) {
			chomp($Line);
			my @Data = split(/$Delimiter/,$Line);
			if (@Data >= 2) {
				if (!defined($HashReferenceForward->{$Data[0]})) {
					$HashReferenceForward->{$Data[0]} = $Data[1];
				}
				if (!defined($HashReferenceForward->{$Data[1]})) {
					$HashReferenceReverse->{$Data[1]} = $Data[0];
				}
			}
		}
		close(INPUT);
	}

	return ($HashReferenceForward,$HashReferenceReverse);
}

#--- This function breaks down the input filename into a directory, filename, and extension ---#
sub ParseFilename {
	my ($Filename) = @_;

	my $Directory = "";
	my $Extension = "";
	if ($Filename =~ m/^(.+\/)([^\/]+)\.([^\.]+)/) {
		$Directory = $1;
		$Filename = $2;
		$Extension = $3;
	}

	return ($Filename,$Directory,$Extension);
}

#--- This function compares the files listed in two separate directories and returns the list of new files and updated files ---#
sub CompareDirectories {
	my ($NewDirectory,$OldDirectory,$ComparisonType) = @_;

	my $Command = "ls -la ".$NewDirectory." > ".$NewDirectory."FileList.txt";
	system($Command);
	$Command = "ls -la ".$OldDirectory." > ".$OldDirectory."FileList.txt";
	system($Command);

	my $NewFileData = &LoadMultipleColumnFile($NewDirectory."FileList.txt","\\s");
	my $OldFileData = &LoadMultipleColumnFile($OldDirectory."FileList.txt","\\s");

	my $UpdatedFiles = [];
	my $NewFiles = [];

	my %FilenameHash;
	foreach my $File (@{$OldFileData}) {
		if ($ComparisonType eq "date") {
			$FilenameHash{$File->[$#{$File}]} = $File->[$#{$File}-2].":".$File->[$#{$File}-1];
		} elsif ($ComparisonType eq "size") {
			$FilenameHash{$File->[$#{$File}]} = $File->[$#{$File}-3];
		}
	}
	foreach my $File (@{$NewFileData}) {
		if (defined($FilenameHash{$File->[$#{$File}]})) {
			if ($ComparisonType eq "date" && $FilenameHash{$File->[$#{$File}]} ne $File->[$#{$File}-2].":".$File->[$#{$File}-1]) {
				push(@{$UpdatedFiles},$File->[$#{$File}]);
			} elsif ($ComparisonType eq "size" && $FilenameHash{$File->[$#{$File}]} ne $File->[$#{$File}-3]) {
				push(@{$UpdatedFiles},$File->[$#{$File}]);
			}
		} else {
			$FilenameHash{$File->[$#{$File}]} = $File->[$#{$File}-2].":".$File->[$#{$File}-1];
			push(@{$NewFiles},$File->[$#{$File}]);
		}
	}

	return ($NewFiles,$UpdatedFiles);
}

sub RemoveHFromFormula {
	my ($Formula) = @_;
	my @Data = split(/H/,$Formula);

	if (@Data == 1) {
		return $Formula;
	}

	while ($Data[1] =~ m/^\d/) {
		$Data[1] = substr($Data[1],1);
	}

	return $Data[0].$Data[1];
}

sub CompareArrays {
	my ($ArrayOne,$ArrayTwo) = @_;

	my $ArrayOneExtra = ();
	my $ArrayTwoExtra = ();
	my $ArrayOverlap = ();
	my %ArrayTwoHash;

	for (my $i=0; $i < @{$ArrayOne}; $i++) {
		my $Match = 0;
		for (my $j=0; $j < @{$ArrayTwo}; $j++) {
			if ($ArrayOne->[$i] eq $ArrayTwo->[$j]) {
				$ArrayTwoHash{$ArrayOne->[$i]} = 1;
				$Match = 1;
				push(@{$ArrayOverlap},$ArrayOne->[$i]);
				$j = @{$ArrayTwo};
			}
		}
		if ($Match == 0) {
			push(@{$ArrayOneExtra},$ArrayOne->[$i]);
		}
	}
	for (my $j=0; $j < @{$ArrayTwo}; $j++) {
		if (!defined($ArrayTwoHash{$ArrayTwo->[$j]})) {
			push(@{$ArrayTwoExtra},$ArrayTwo->[$j]);
		}
	}

	return ($ArrayOneExtra,$ArrayTwoExtra,$ArrayOverlap);
}

sub ReplaceLineSubstringsFromHash {
	my ($Translation, $Line) = @_;

	my @Data = keys(%{$Translation});
	for (my $i=0; $i < @Data; $i++) {
		my $FindString = $Data[$i];
		my $ReplaceString = $Translation->{$Data[$i]};
		$Line =~ s/([\,\s\;\+\[])$FindString([\,\s\;\+\[])/$1$ReplaceString$2/g;
		$Line =~ s/$FindString$/$ReplaceString/g;
		$Line =~ s/^$FindString/$ReplaceString/g;
	}

	return $Line;
}

sub FindArrayElement {
	my ($ArrayRef,$Value) = @_;

	if (!defined($ArrayRef)) {
		return -1;
	}

        for (my $i=0;$i < @{$ArrayRef};$i++) {
        	if ($ArrayRef->[$i] eq $Value) {
                	return $i;
                }
        }

        return -1;
}

sub RemoveArrayElement {
	my ($ArrayRef,$Value) = @_;

	for (my $i=0;$i < @{$ArrayRef};$i++) {
		if ($ArrayRef->[$i] eq $Value) {
			splice(@{$ArrayRef},$i,1);
			$i--;
		}
	}

    return $ArrayRef;
}

sub FormatNumber {
        my ($OriginalNumber,$Digits,$ZeroEquivalence) = @_;

        if (abs($OriginalNumber) < $ZeroEquivalence) {
                $OriginalNumber = "0.";
                for (my $i=0; $i < $Digits;$i++) {
                        $OriginalNumber .= "0"
                }
                return $OriginalNumber
        }

        if ($OriginalNumber > 1 || $OriginalNumber < -1) {
                $OriginalNumber = $OriginalNumber*(10**$Digits);
                $OriginalNumber = int($OriginalNumber + .5 * ($OriginalNumber <=> 0));
                $OriginalNumber = $OriginalNumber/(10**$Digits);
                return $OriginalNumber;
        }

        my $Zeros = 0;
        while (abs($OriginalNumber) < 10**$Zeros) {
                $Zeros--;
        }

        $OriginalNumber = $OriginalNumber*10**-$Zeros;
        $OriginalNumber = $OriginalNumber*(10**$Digits);
        $OriginalNumber = int($OriginalNumber + .5 * ($OriginalNumber <=> 0));
        $OriginalNumber = $OriginalNumber/(10**$Digits);
        if ($Zeros > -4) {
		$OriginalNumber = $OriginalNumber/(10**-$Zeros);
	} else {
		$OriginalNumber .= "e".$Zeros;
	}

        return $OriginalNumber;
}

sub CountFileLines {
	my ($filename) = @_;
	my $lines = 0;
	open(FILE, $filename) or die "Can't open `$filename': $!";
	while(<FILE>) {
	    	$lines++;
	}
	close FILE;
	return $lines;
}

sub ManipulateFormula {
	my ($OriginalFormula) = @_;

	my %Atoms;
	my $CurrentAtomType = "";
	my $CurrentAtomNumber = "";
	for (my $i=0; $i < length($OriginalFormula); $i++) {
		my $CurrentLetter  = substr($OriginalFormula,$i,1);
		if ($CurrentLetter =~ m/[A-Z]/) {
			if ($CurrentAtomType ne "") {
				if ($CurrentAtomNumber eq "1") {
					$CurrentAtomNumber = "";
				}
				$Atoms{$CurrentAtomType} = $CurrentAtomNumber;
			}
			$CurrentAtomType = $CurrentLetter;
			$CurrentAtomNumber = "";
		} elsif ($CurrentLetter =~ m/[a-z]/) {
			$CurrentAtomType .= $CurrentLetter;
		} elsif ($CurrentLetter =~ m/[\d]/) {
			$CurrentAtomNumber .= $CurrentLetter;
		} else {
			if ($CurrentAtomType ne "") {
				$Atoms{$CurrentAtomType} = $CurrentAtomNumber;
			}
			$CurrentAtomType = "";
		}
	}
	if ($CurrentAtomType ne "") {
		if ($CurrentAtomNumber eq "1") {
			$CurrentAtomNumber = "";
		}
		$Atoms{$CurrentAtomType} = $CurrentAtomNumber;
	}

	my @SortedAtoms = sort(keys(%Atoms));
	my $StandardFormula;
	my $CompareFormula;
	for (my $i=0; $i < @SortedAtoms; $i++) {
		$StandardFormula .= $SortedAtoms[$i];
		$StandardFormula .= $Atoms{$SortedAtoms[$i]};
		if ($SortedAtoms[$i] ne "H") {
			$CompareFormula .= $SortedAtoms[$i];
			$CompareFormula .= $Atoms{$SortedAtoms[$i]};
		}
	}

	return ($StandardFormula,$CompareFormula);
}

sub ParseGPRFile {
	my ($Filename,$ReactionData) = @_;

	my $GPRData = &LoadMultipleColumnFile($Filename,"\t");

	for (my $i=0; $i < @{$GPRData}; $i++) {
		if (@{$GPRData->[$i]} >= 3) {
			if (!defined($ReactionData->{$GPRData->[$i]->[2]})) {
				$ReactionData->{$GPRData->[$i]->[2]}->{"ID"} = $GPRData->[$i]->[2];
			}
			if (length($GPRData->[$i]->[1]) > 0) {
				$ReactionData->{$GPRData->[$i]->[2]}->{"EC"} = $GPRData->[$i]->[1];
			}
			for (my $j=4; $j < @{$GPRData->[$i]}; $j++) {
				if (length($GPRData->[$i]->[$j]) > 0) {
					if ($GPRData->[$i]->[$j] =~ m/_$/) {
						$GPRData->[$i]->[$j] = chop($GPRData->[$i]->[$j]);
					}
					push(@{$ReactionData->{$GPRData->[$i]->[2]}->{"GENE ID"}},$GPRData->[$i]->[$j]);
				}
			}
		}
	}

	return ($ReactionData);
}

sub ParseSBMLFile {
	my ($Filename,$ReactionData,$CompoundData) = @_;

	my $SBMLData = &LoadSingleColumnFile($Filename,"");

	my $HandlingSpecies = 0;
	my $HandlingReactions = 0;
	my $HandlingReactants = 0;
	my $HandlingProducts = 0;
	my $ReactionID = "";
	my $ReactionReactants = "";
	my $ReactionSign = "";
	my $ReactionProducts = "";
	for (my $i=0; $i < @{$SBMLData}; $i++) {
		if ($SBMLData->[$i] =~ m/^<listOfSpecies>/) {
			$HandlingSpecies = 1;
		} elsif ($SBMLData->[$i] =~ m/^<\/listOfSpecies>/) {
			$HandlingSpecies = 0;
		} elsif ($SBMLData->[$i] =~ m/^<listOfReactions>/) {
			$HandlingReactions = 1;
		} elsif ($SBMLData->[$i] =~ m/^<\/listOfReactions>/) {
			$HandlingReactions = 0;
		} elsif ($HandlingSpecies == 1 && $SBMLData->[$i] =~ m/^<species/) {
			#Parsing out the compound ID
			if ($SBMLData->[$i] =~ m/id="([^"]+)"/) {
				my $ID = $1;
				if ($ID =~ m/^_/) {
					$ID = substr($ID,1);
				}
				if ($ID =~ m/_[a-z]$/) {
					chop($ID);
					chop($ID);
				}
				if (length($ID) > 0) {
					#Parsing out the compound name
					if (!defined($CompoundData->{$ID})) {
						$CompoundData->{$ID}->{"ID"} = $ID;
					}
					if ($SBMLData->[$i] =~ m/name="([^"]+)"/) {
						my $Name = $1;
						if ($Name =~ m/^_/) {
							$Name = substr($Name,1);
						}
						$Name =~ s/_/ /g;
						if (length($Name) > 0 && (!defined($CompoundData->{$ID}->{"NAME"}) || &FindArrayElement($CompoundData->{$ID}->{"NAME"},$Name) == -1)) {
							push(@{$CompoundData->{$ID}->{"NAME"}},$Name);
						}
					}
				}
			}
		} elsif ($HandlingReactions == 1 && $SBMLData->[$i] =~ m/^<reaction/) {
			$ReactionSign = " <=> ";
			if ($SBMLData->[$i] =~ m/reversible="false"/) {
				$ReactionSign = " => ";
			}
			if ($SBMLData->[$i] =~ m/id="([^"]+)"/) {
				$ReactionID = $1;
				if (length($ReactionID) > 0) {
					if (!defined($ReactionData->{$ReactionID})) {
						$ReactionData->{$ReactionID}->{"ID"} = $ReactionID;
					}
					if ($SBMLData->[$i] =~ m/name="([^"]+)"/) {
						my $Name = $1;
						if ($Name =~ m/^_/) {
							$Name = substr($Name,1);
						}
						$Name =~ s/_/ /g;
						if (length($Name) > 0 && (!defined($ReactionData->{$ReactionID}->{"NAME"}) || &FindArrayElement($ReactionData->{$ReactionID}->{"NAME"},$Name) == -1)) {
							push(@{$ReactionData->{$ReactionID}->{"NAME"}},$Name);
						}
					}

				}
			}
		} elsif ($HandlingReactions == 1 && $SBMLData->[$i] =~ m/^<\/reaction>/) {
			$ReactionID = "";
			$ReactionReactants = "";
			$ReactionSign = "";
			$ReactionProducts = "";
		} elsif ($HandlingReactions == 1 && $SBMLData->[$i] =~ m/^<html:p>EC Number:\s([^<]+)/) {
			my $ECNumber = $1;
			if (length($ECNumber) > 3 && (!defined($ReactionData->{$ReactionID}->{"EC"}) || &FindArrayElement($ReactionData->{$ReactionID}->{"EC"},$ECNumber) == -1)) {
				push(@{$ReactionData->{$ReactionID}->{"EC"}},$ECNumber);
			}
		} elsif ($HandlingReactions == 1 && $SBMLData->[$i] =~ m/^<html:p>Confidence Level:\s([^<]+)/) {
			my $Confidence = $1;
			if (length($Confidence) > 0) {
				$ReactionData->{$ReactionID}->{"CONFIDENCE"} = $Confidence;
			}
		} elsif ($HandlingReactions == 1 && $SBMLData->[$i] =~ m/^<html:p>LOCUS:/) {
			$_ = $SBMLData->[$i];
			my @GeneArray = /<html:p>LOCUS:([^\#]+)/g;
			for (my $j=0; $j < @GeneArray; $j++) {
				if (length($GeneArray[$j]) > 0 && (!defined($ReactionData->{$ReactionID}->{"GENES"}) || &FindArrayElement($ReactionData->{$ReactionID}->{"GENES"},$GeneArray[$j]) == -1)) {
					push(@{$ReactionData->{$ReactionID}->{"GENES"}},$GeneArray[$j]);
				}
			}
		} elsif ($HandlingReactions == 1 && $SBMLData->[$i] =~ m/^<listOfReactants>/) {
			$HandlingReactants = 1;
		} elsif ($HandlingReactions == 1 && $SBMLData->[$i] =~ m/^<\/listOfReactants>/) {
			$HandlingReactants = 0;
		} elsif ($HandlingReactions == 1 && $SBMLData->[$i] =~ m/^<listOfProducts>/) {
			$HandlingProducts = 1;
		} elsif ($HandlingReactions == 1 && $SBMLData->[$i] =~ m/^<\/listOfProducts>/) {
			$HandlingProducts = 0;
			if (length($ReactionID) > 0 && defined($ReactionData->{$ReactionID})) {
				my $Equation = $ReactionReactants.$ReactionSign.$ReactionProducts;
				$ReactionData->{$ReactionID}->{"EQUATION"} = $Equation;
			}
		} elsif ($HandlingReactions == 1 && $SBMLData->[$i] =~ m/^<speciesReference/) {
			if ($SBMLData->[$i] =~ m/species="([^"]+)"/) {
				my $SpeciesID = $1;
				if ($SpeciesID =~ m/^_/) {
					$SpeciesID = substr($SpeciesID,1);
				}
				my $Compartment = "";
				if ($SpeciesID =~ m/_([a-z])$/) {
					$Compartment = $1;
					chop($SpeciesID);
					chop($SpeciesID);
				}
				my $Stoichiometry = "";
				if ($SBMLData->[$i] =~ m/stoichiometry="([^"]+)"/) {
					$Stoichiometry = $1;
				}
				if (length($Stoichiometry) > 0 && length($SpeciesID) > 0) {
					my $SpeciesString = "";
					if ($Stoichiometry ne "1") {
						$SpeciesString .= "(".$Stoichiometry.") ";
					}
					$SpeciesString .= "$SpeciesID";
					if (length($Compartment) > 0 && $Compartment ne "c") {
						$SpeciesString .= "[".$Compartment."]";
					}
					if ($HandlingReactants == 1) {
						if (length($ReactionReactants) > 0) {
							$ReactionReactants .= " + ";
						}
						$ReactionReactants .= $SpeciesString;
					} elsif ($HandlingProducts == 1) {
						if (length($ReactionProducts) > 0) {
							$ReactionProducts .= " + ";
						}
						$ReactionProducts .= $SpeciesString;
					}
				}
			}
		}
	}

	return ($ReactionData,$CompoundData);
}

sub SearchTranslationDataForMatchingID {
	my ($Filename,$SearchText) = @_;

	#Declaring the reference to the array where the results will ultimately be stored
	my $MatchingIDs = ();

	#If the search text is blank or the input file does not exist, I return an empty array
	if (length($SearchText) == 0 || !(-e $Filename)) {
		return $MatchingIDs;
	}

	#Loading the translation file
	my %IDHash;
	my $TranslationData = &LoadMultipleColumnFile($Filename,"\t");
	my %UniqueKeysHash;
	for (my $i=0; $i < @{$TranslationData}; $i++) {
		if (@{$TranslationData->[$i]} >= 2) {
			push(@{$UniqueKeysHash{$TranslationData->[$i]->[1]}},$TranslationData->[$i]->[0]);
		}
	}
	#Searching through the keys of the translation file for my search text and storing matching ids in a hash
	my @AllKeys = keys(%UniqueKeysHash);
	for (my $i=0; $i < @AllKeys; $i++) {
		if ($AllKeys[$i] =~ m/$SearchText/) {
			for (my $j=0; $j < @{$UniqueKeysHash{$AllKeys[$i]}}; $j++) {
				$IDHash{$UniqueKeysHash{$AllKeys[$i]}->[$j]} = 1;
			}
		}
	}

	#Putting the matching hash keys into an array and sorting it
	push(@{$MatchingIDs},keys(%IDHash));
	if (defined($MatchingIDs)) {
		@{$MatchingIDs} = sort(@{$MatchingIDs})
	}

	return $MatchingIDs;
}

sub BackupFile {
	my ($CurrentFilename,$BackupFilename) = @_;

	if (-e $CurrentFilename) {
		if (-e $BackupFilename) {
			unlink($BackupFilename);
		}
		rename($CurrentFilename,$BackupFilename);
	}
}

sub Date {
	my ($Time) = @_;
	if (!defined($Time)) {
		$Time = time();
	}
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($Time);

	return ($mon+1)."/".($mday)."/".($year+1900);
}

sub MergeArraysUnique {
	my @ArrayRefs = @_;

	my $ResultArray = ();
	my %EntryHash;
	for (my $i=0; $i < @ArrayRefs; $i++) {
		if (defined($ArrayRefs[$i])) {
			for (my $j=0; $j < @{$ArrayRefs[$i]}; $j++) {
				if (!defined($EntryHash{$ArrayRefs[$i]->[$j]})) {
					push(@{$ResultArray},$ArrayRefs[$i]->[$j]);
					$EntryHash{$ArrayRefs[$i]->[$j]} = 1;
				}
			}
		}
	}

	return $ResultArray
}

#Opens up every file in a directory, searches each line for the search expression, and replaces the objects matching the search expression according to the translation hash
sub TranslateFileData {
	my ($TranslationHash,$FilenameExpression,$SearchExpression,$Recursive,$MakeUnique,$SortLines) = @_;

	#Checking the search expression if one was provided
	if (defined($SearchExpression) && length($SearchExpression) > 0) {
		if (index($SearchExpression,"(") == -1 || index($SearchExpression,"(") == -1) {
			$SearchExpression = "(".$SearchExpression.")";
		}
	}

	#Finding all matching filenames
	my @MatchingFiles;
	if ($Recursive == 1 && $FilenameExpression =~ m/\/$/) {
		@MatchingFiles = &RecursiveGlob($FilenameExpression);
	} else {
		@MatchingFiles = glob($FilenameExpression);
	}

	#Exiting if no matching filenames were found
	if (@MatchingFiles == 0) {
		print "No matching files!\n";
		return;
	}

	#Loading the translation file
	if (!(-e $TranslationHash)) {
		print "Could not find translation file: ".$TranslationHash."!\n";
		return;
	}
	my ($Ignore,$ReverseTranslation) = &LoadSeparateTranslationFiles($TranslationHash,"\t");

	#Scanning through all matching filenames
	my @TranslationKeys = keys(%{$ReverseTranslation});

	for (my $i=0; $i < @MatchingFiles; $i++) {
		#Loading the file data into an array
		my $FileData = &LoadSingleColumnFile($MatchingFiles[$i],"");
		#Scanning through each fileline
		my $MatchCount = 0;
		for (my $j=0; $j < @{$FileData}; $j++) {
			if (defined($SearchExpression) && length($SearchExpression) > 0) {
				#This should be faster
				$_ = $FileData->[$j];
				my @MatchingGroups = /$SearchExpression/g;
				for (my $k=0; $k < @MatchingGroups;$k++) {
					if (defined($ReverseTranslation->{$MatchingGroups[$k]})) {
						$MatchCount++;
						my $VarOne = $MatchingGroups[$k];
						my $VarTwo = $ReverseTranslation->{$MatchingGroups[$k]};
						$FileData->[$j] =~ s/$VarOne/$VarTwo/;
					}
				}
			} else {
				#This will be slower
				for (my $k=0; $k < @TranslationKeys;$k++) {
					my $VarOne = $TranslationKeys[$k];
					my $VarTwo = $ReverseTranslation->{$TranslationKeys[$k]};
					$FileData->[$j] =~ s/$VarOne/$VarTwo/g;
				}
			}

		}
		#Saving the modified file data back to the file
		print $MatchingFiles[$i]."\n";
		print $MatchCount."\n";
		#Making the array unique if requested
		if (defined($MakeUnique) && $MakeUnique == 1) {
			$FileData = &MergeArraysUnique($FileData);
		}
		#Sort file lines
		if (defined($SortLines) && $SortLines == 1) {
			@{$FileData} = sort(@{$FileData});
		}
		&PrintArrayToFile($MatchingFiles[$i],$FileData);
	}
}

sub RecursiveGlob {
	my($path) = @_;

	my @FileList;

	## append a trailing / if it's not there
	$path .= '/' if($path !~ /\/$/);

	## loop through the files contained in the directory
	for my $eachFile (glob($path.'*')) {
		## if the file is a directory
		if( -d $eachFile) {
			## pass the directory to the routine ( recursion )
			push(@FileList,RecursiveGlob($eachFile));
		} else {
			push(@FileList,$eachFile);
		}
	}

	return @FileList;
}

sub PrintHashToFile {
	my($HashRef,$Filename) = @_;

	if ($Filename == "") {
		open (HASHOUTPUT, ">&STDOUT");
	} else {
		open (HASHOUTPUT, ">$Filename");
	}
	my @Headings = keys(%{$HashRef});
	my @FirstHeadings;
	my @SecondHeadings;
	for (my $i=0; $i < @Headings; $i++) {
		if (ref($HashRef->{$Headings[$i]}) eq "HASH") {
			my @SubHeadings = keys(%{$HashRef->{$Headings[$i]}});
			for (my $j=0; $j < @SubHeadings;$j++) {
				push(@FirstHeadings,$Headings[$i]);
				push(@SecondHeadings,$SubHeadings[$j]);
			}
		} else {
			push(@FirstHeadings,$Headings[$i]);
			push(@SecondHeadings,$Headings[$i]);
		}
	}
	#Printing headers
	print HASHOUTPUT "FIRST HEADING;";
	print HASHOUTPUT join(";",@FirstHeadings)."\n";
	print HASHOUTPUT "SECOND HEADING;";
	print HASHOUTPUT join(";",@SecondHeadings)."\n";
	#Printing the number of data entries
	print HASHOUTPUT "Number of entries;";
	for (my $i=0; $i < @FirstHeadings; $i++) {
		if ($i > 0) {
			print HASHOUTPUT ";";
		}
		if ($FirstHeadings[$i] ne $SecondHeadings[$i]) {
			if (defined($HashRef->{$FirstHeadings[$i]}->{$SecondHeadings[$i]})) {
				if (@{$HashRef->{$FirstHeadings[$i]}->{$SecondHeadings[$i]}} == 1) {
					print HASHOUTPUT $HashRef->{$FirstHeadings[$i]}->{$SecondHeadings[$i]}->[0];
				} else {
					my $NumEntries = @{$HashRef->{$FirstHeadings[$i]}->{$SecondHeadings[$i]}};
					print HASHOUTPUT $NumEntries;
				}
			} else {
				print HASHOUTPUT 0;
			}
		} else {
			if (defined($HashRef->{$FirstHeadings[$i]})) {
				if (@{$HashRef->{$FirstHeadings[$i]}} == 1) {
					print HASHOUTPUT $HashRef->{$FirstHeadings[$i]}->[0];
				} else {
					my $NumEntries = @{$HashRef->{$FirstHeadings[$i]}};
					print HASHOUTPUT $NumEntries;
				}
			} else {
				print HASHOUTPUT 0;
			}
		}
	}
	print HASHOUTPUT "\n";
	#Printing data
	my $Continue = 1;
	my $Count = 0;
	while($Continue == 1) {
		print HASHOUTPUT ($Count+1).";";
		$Continue = 0;
		for (my $i=0; $i < @FirstHeadings; $i++) {
			if ($FirstHeadings[$i] ne $SecondHeadings[$i]) {
				if (defined($HashRef->{$FirstHeadings[$i]}->{$SecondHeadings[$i]})) {
					if (@{$HashRef->{$FirstHeadings[$i]}->{$SecondHeadings[$i]}} > 1 && defined($HashRef->{$FirstHeadings[$i]}->{$SecondHeadings[$i]}->[$Count])) {
						print HASHOUTPUT $HashRef->{$FirstHeadings[$i]}->{$SecondHeadings[$i]}->[$Count];
						$Continue = 1;
					}
				}
			} else {
				if (defined($HashRef->{$FirstHeadings[$i]})) {
					if (@{$HashRef->{$FirstHeadings[$i]}} > 1 && defined($HashRef->{$FirstHeadings[$i]}->[$Count])) {
						print HASHOUTPUT $HashRef->{$FirstHeadings[$i]}->[$Count];
						$Continue = 1;
					}
				}
			}
			print HASHOUTPUT ";";
		}
		$Count++;
		print HASHOUTPUT "\n";
	}
	close(HASHOUTPUT);
}

sub CreateHistogramHash {
	my($ArrayRef) = @_;

	my $HashRef;
	for (my $i=0; $i < @{$ArrayRef}; $i++) {
		my @TempArray = split(/\|/,$ArrayRef->[$i]);
		for (my $j=0; $j < @TempArray; $j++) {
			if (defined($HashRef->{$TempArray[$j]})) {
				$HashRef->{$TempArray[$j]}->[0]++;
			} else {
				$HashRef->{$TempArray[$j]}->[0] = 1;
			}
		}
	}

	return $HashRef;
}

#init_hoh will take a directory like peg or rxn and create a hash of hashes
#my $dir_all = '/disks/www/Network_Data/MinOrg';
#$dir_peg = "$dir_all/peg";
#%hoh_peg = &init_hoh($dir_peg);
# $hoh_peg{'peg.1234'}{REACTIONS} will be an @array of reactions associated with peg.1234
sub init_hoh{
    my $dir = shift @_;
    my %hash;
    opendir my $DH, $dir or die "cannot open '$dir' $!";
    while (my $file = readdir $DH ) {
        chomp $file;
        next if $file =~ /~$/;
        next if -d $file;
        open my $FH, "<", "$dir/$file" or die "Cannot open '$dir/$file' $!";
        while ( my $line = <$FH> ) {
            chomp $line;
            next if /^#/ || !length($line);
            my ($key, @values ) = split(/\t/, $line);
            $hash{ $file }{ $key } = \@values;
        }
        close $FH;
    }
    return %hash;
}

sub AddElementsUnique {
	my ($ArrayRef,@NewElements) = @_;

	my $ArrayValueHash;
	my $NewArray;
	if (defined($ArrayRef) && @{$ArrayRef} > 0) {
		for (my $i=0; $i < @$ArrayRef; $i++) {
			if (!defined($ArrayValueHash->{$ArrayRef->[$i]})) {
				push(@{$NewArray},$ArrayRef->[$i]);
				$ArrayValueHash->{$ArrayRef->[$i]} = @{$NewArray}-1;
			}
		}
	}

	my $NumberOfMatches = 0;
	for (my $i=0; $i < @NewElements; $i++) {
		if (length($NewElements[$i]) > 0 && !defined($ArrayValueHash->{$NewElements[$i]})) {
			push(@{$NewArray},$NewElements[$i]);
			$ArrayValueHash->{$NewElements[$i]} = @{$NewArray}-1;
		} else {
			$NumberOfMatches++;
		}
	}

	return ($NewArray,$NumberOfMatches);
}

sub PutArrayInHash {
	my (@ArrayRef) = @_;

	my $HashRef;
	for (my $i=0; $i < @ArrayRef; $i++) {
		$HashRef->{$ArrayRef[$i]} = $i;
	}

	return $HashRef;
}

sub RefineOrganismName {
	my ($Name) = @_;

	my @Temp = split(/\s/,$Name);
	if (@Temp >= 2) {
	  $Name = substr(shift(@Temp),0,1).". ".lc(join(" ",@Temp));
	}
	$Name =~ s/str\.\s//g;
	my $Find = "subsp. ".$Temp[0];
	$Name =~ s/$Find//g;

	return $Name;
}

sub RemoveDuplicates {
	my (@OriginalArray) = @_;

	my %Hash;
	foreach my $Element (@OriginalArray) {
		$Hash{$Element} = 1;
	}
	@OriginalArray = sort(keys(%Hash));

	return @OriginalArray;
}

sub FormatCoefficient {
	my ($Original) = @_;

	#Converting scientific notation to normal notation
	if ($Original =~ m/[eE]/) {
		my $Coefficient = "";
		my @Temp = split(/[eE]/,$Original);
		my @TempTwo = split(/\./,$Temp[0]);
		if ($Temp[1] > 0) {
			my $Index = $Temp[1];
			if (defined($TempTwo[1]) && $TempTwo[1] != 0) {
				$Index = $Index - length($TempTwo[1]);
				if ($Index < 0) {
					$TempTwo[1] = substr($TempTwo[1],0,(-$Index)).".".substr($TempTwo[1],(-$Index))
				}
			}
			for (my $j=0; $j < $Index; $j++) {
				$Coefficient .= "0";
			}
			if ($TempTwo[0] == 0) {
				$TempTwo[0] = "";
			}
			if (defined($TempTwo[1])) {
				$Coefficient = $TempTwo[0].$TempTwo[1].$Coefficient;
			} else {
				$Coefficient = $TempTwo[0].$Coefficient;
			}
		} elsif ($Temp[1] < 0) {
			my $Index = -$Temp[1];
			$Index = $Index - length($TempTwo[0]);
			if ($Index < 0) {
				$TempTwo[0] = substr($TempTwo[0],0,(-$Index)).".".substr($TempTwo[0],(-$Index))
			}
			if ($Index > 0) {
				$Coefficient = "0.";
			}
			for (my $j=0; $j < $Index; $j++) {
				$Coefficient .= "0";
			}
			$Coefficient .= $TempTwo[0];
			if (defined($TempTwo[1])) {
				$Coefficient .= $TempTwo[1];
			}
		}
		$Original = $Coefficient;
	}
	#Removing trailing zeros
	if ($Original =~ m/(.+\..+)0+$/) {
		$Original = $1;
	}
	$Original =~ s/\.0$//;

	return $Original;
}

sub ParseProcessorNumber {
	my ($InProcessorNumber) = @_;

	my $NumberOfProcessors = 1;
	my $NoHup = 0;
	if (defined($InProcessorNumber)) {
		if ($InProcessorNumber =~ m/^NH(.+)/) {
			$NumberOfProcessors = $1;
			$NoHup = 1;
		} else {
			$NumberOfProcessors = $InProcessorNumber;
		}
	}

	return ($NoHup,$NumberOfProcessors);
}

1;
