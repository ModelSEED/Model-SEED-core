#!/usr/bin/perl -w
########################################################################
# This perl script configures a model seed installation
# Author: Christopher Henry
# Author email: chrisshenry@gmail.com
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of script creation: 8/29/2011
########################################################################
use strict;
use lib '../../../config/';
use ModelSEEDbootstrap;

my $files = [
	$ENV{MODEL_SEED_CORE}."/lib/ModelSEED/ModelDriver.pm"
];
my $categoryList = [
	"Workspace Operations",
	"Biochemistry Operations",
	"Metabolic Model Operations",
	"Flux Balance Analysis Operations",
	"Sequence Analysis Operations",
	"Utility Functions"
];

#Loading and parsing the code files
my $functions;
for (my $i=0; $i < @{$files};$i++) {
	my $data = loadFile($files->[$i]);
	my $current;
	my $newFunction = -1;
	for (my $j=0; $j < @{$data}; $j++) {
		if ($data->[$j] =~ m/^=CATEGORY/) {
			if (defined($current->{category}) && defined($current->{description}) && defined($current->{function}) && defined($current->{arguments})) {
				$functions->{$current->{category}}->{$current->{function}} = $current;
			}
			$current = {category => $data->[$j+1]};
			$newFunction = 0;
			$j++;
		} elsif ($data->[$j] =~ m/^=DESCRIPTION/) {
			$current->{description} = "";
			while ($data->[$j+1] !~ m/^=EXAMPLE/) {
				if (length($current->{description}) > 0) {
					$current->{description} .= "\n\n";
				}
				$current->{description} .= $data->[$j+1];
				$j++;
			}
			$j--;
		} elsif ($data->[$j] =~ m/^=EXAMPLE/) {
			$current->{example} = $data->[$j+1];
			$j++;
		} elsif ($data->[$j] =~ m/^sub\s+(\w+)\s*\{/ && $newFunction == 0) {
			$current->{function} = $1;
			$newFunction = 1;
		} elsif ($data->[$j] =~ m/=\s\$self\-\>check\(\[/ && $newFunction == 1) {
			$j++;
			while ($data->[$j] =~ m/\[\"([^\"]+)\",([01])(.*)\]/) {
				my $arg = $1;
				$current->{arguments}->{$arg} = {
					optional => $2
				};
				my $tempstring = $3;
				if (length($tempstring) > 0) {
					my $temp = [split(/,/,$tempstring)];
					shift(@{$temp});
					$current->{arguments}->{$arg}->{default} = shift(@{$temp});
					while (@{$temp} > 0 && $current->{arguments}->{$arg}->{default} =~ m/^\"/ && $current->{arguments}->{$arg}->{default} =~ m/\"$/) {
						$current->{arguments}->{$arg}->{default} .= shift(@{$temp});
					}
					if (@{$temp} > 0) {
						$current->{arguments}->{$arg}->{description} = shift(@{$temp});
						while (@{$temp} > 0 && $current->{arguments}->{$arg}->{description} =~ m/^\"/ && $current->{arguments}->{$arg}->{description} =~ m/\"$/) {
							$current->{arguments}->{$arg}->{description} .= shift(@{$temp});
						}
					}
					if (@{$temp} > 0) {
						$current->{arguments}->{$arg}->{default} = shift(@{$temp});
						while (@{$temp} > 0 && $current->{arguments}->{$arg}->{default} =~ m/^\"/ && $current->{arguments}->{$arg}->{default} =~ m/\"$/) {
							$current->{arguments}->{$arg}->{default} .= shift(@{$temp});
						}
					}
					my $headings = ["default","description"];
					for (my $k=0; $k < @{$headings}; $k++) {
						if (defined($current->{arguments}->{$arg}->{$headings->[$k]}) && $current->{arguments}->{$arg}->{$headings->[$k]} =~ m/^\".+\"$/) {
							$current->{arguments}->{$arg}->{$headings->[$k]} = substr($current->{arguments}->{$arg}->{$headings->[$k]},1,length($current->{arguments}->{$arg}->{$headings->[$k]})-2);
						}
					}
				}
				$j++;
			}
			if ($data->[$j] =~ m/\[\@Data\],\"(.+)\"\);/) {
				$current->{summary} = $1;
			}
			$newFunction = -1;
		}
	}
	if (defined($current->{category}) && defined($current->{description}) && defined($current->{function}) && defined($current->{arguments})) {
		$functions->{$current->{category}}->{$current->{function}} = $current;
	}
}

#Creating the documentation
my $output = ["[[Model SEED Homepage]]",""];
for (my $i=0; $i < @{$categoryList}; $i++) {
	my $category = $categoryList->[$i];
	if (defined($functions->{$category})) {
		push(@{$output},("== ".$category." ==",""));
		foreach my $func (keys(%{$functions->{$category}})) {
			if (defined($functions->{$category}->{$func}->{summary})) {
				push(@{$output},("==== ''".$func."'': ".$functions->{$category}->{$func}->{summary}." ====",""));
			} else {
				push(@{$output},("==== ''".$func."'' ====",""));
			}
			if (defined($functions->{$category}->{$func}->{description})) {
				push(@{$output},("'''Description'''","",$functions->{$category}->{$func}->{description},""));
			}
			if (defined($functions->{$category}->{$func}->{arguments})) {
				push(@{$output},("'''Arguments'''",""));
				foreach my $arg (keys(%{$functions->{$category}->{$func}->{arguments}})) {
					my $optional = "";
					my $default = "";
					my $description = "";
					if ($functions->{$category}->{$func}->{arguments}->{$arg}->{optional} == 0) {
						$optional = " (optional)";
						if (defined($functions->{$category}->{$func}->{arguments}->{$arg}->{default})) {
							$default = " Default: '".$functions->{$category}->{$func}->{arguments}->{$arg}->{default}."'";
						}
					}
					
					if (defined($functions->{$category}->{$func}->{arguments}->{$arg}->{description})) {
						$description = $functions->{$category}->{$func}->{arguments}->{$arg}->{description};
					}
					push(@{$output},("* ".$arg.$optional.": ".$description.$default,""));
				}
			}
			if (defined($functions->{$category}->{$func}->{example})) {
				push(@{$output},("'''Example'''","",$functions->{$category}->{$func}->{example},""));
			}
			push(@{$output},("----",""));
		}
	}
}

#Printing the documentation wiki
printFile($ENV{MODEL_SEED_CORE}."/docs/wiki/ModelDriver.wiki",$output);

1;
#Utility functions used by the configuration script
sub printFile {
    my ($filename,$arrayRef) = @_;
    open ( my $fh, ">", $filename) || die("Failure to open file: $filename, $!");
    foreach my $Item (@{$arrayRef}) {
    	print $fh $Item."\n";
    }
    close($fh);
}

sub loadFile {
    my ($filename) = @_;
    my $DataArrayRef = [];
    open (INPUT, "<", $filename) || die("Couldn't open $filename: $!");
    while (my $Line = <INPUT>) {
        chomp($Line);
        push(@{$DataArrayRef},$Line);
    }
    close(INPUT);
    return $DataArrayRef;
}