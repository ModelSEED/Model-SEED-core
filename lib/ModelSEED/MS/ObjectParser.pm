use strict;
use warnings;
use Carp qw(cluck);
package ModelSEED::ObjectParser;

my $loadableTypes = {
	media => 1
};

=head3 loadObjectFile
Definition:
	{} = ModelSEED::ObjectParser::loadObjectFile({
		type => string:object type,
		id => string:object ID
	});
Description:
	This function loads object data from file
Example:
{} = ModelSEED::ObjectParser::loadObjectFile({type => "media",id=>"LB"});
=cut
sub loadObjectFile {
	my ($args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["type","id"],{
		filedata => undef,
		filename => undef,
		directory => undef
	});
	if (!defined($loadableTypes->{$args->{type}})) {
		ModelSEED::utilities::ERROR("Type ".$args->{type}." cannot be loaded!");
	}
	if (!defined($args->{filedata})) {
		if (!defined($args->{filename})) {
			if (!defined($args->{directory})) {
				ModelSEED::utilities::ERROR("Must provide directory, filename, or filedata!");
			}
			$args->{filename} = $args->{directory}.$args->{id}.$args->{type};
		}
		if (!-e $args->{filename}) {
			ModelSEED::utilities::ERROR("Object file ".$args->{filename}." not found!");
		}
		$args->{filedata} = ModelSEED::utilities::LOADFILE($args->{filename});
	}
	if (!defined($args->{filedata})) {
		ModelSEED::utilities::ERROR("File data not loaded!");
	}
	my $function = "ModelSEED::ObjectParser::".$args->{type}."Parser";
	return $function($args->{filedata});
}

=head3 mediaParser
Definition:
	{} = ModelSEED::ObjectParser::mediaParser({
		filedata => [string]
	});
Description:
	This function parses the media file into the object datastructure
Example:
{} = ModelSEED::ObjectParser::mediaParser({filedata => [...]});
=cut
sub mediaParser {
	my ($args) = @_;
	$args = ModelSEED::utilities::ARGS($args,["filedata"],{});
	my $data;
	my $acceptedAttributes = {
		id => 1,name => 1,type => 1
	};
	my $translation = {
		"ID" => "compound_id",
		"Concentration"  => "concentration",
		"Min flux"  => "minflux",
		"Max flux"  => "maxflux"
	};
	my $section = "none";
	my $headings;
	for (my $i=0; $i < @{$args->{filedata}}; $i++) {
		if ($args->{filedata}->[$i] =~ m/^Attributes\{/) {
			$section = "attributes";	
		} elsif ($args->{filedata}->[$i] =~ m/^\}/) {
			$section = "none";
		} elsif ($args->{filedata}->[$i] =~ m/^Compounds\{/) {
			$section = "compounds";
			$headings = [split(/\t/,$args->{filedata}->[$i+1])];
			$i++;
		} elsif ($section eq "attributes") {
			my $array = [split(/\t/,$args->{filedata}->[$i])];
			if (defined($acceptedAttributes->{$array->[0]})) {
				$data->{attributes}->{$array->[0]} = $array->[1];
			}
		} elsif ($section eq "compounds") {
			my $cpdData = {
				attributes => {media_id => $data->{attributes}->{id}}
			};
			my $array = [split(/\t/,$args->{filedata}->[$i])];
			for (my $j=0; $j < @{$array}; $j++) {
				$cpdData->{attributes}->{$translation->{$headings->[$j]}} = $array->{$j};
			}
			push(@{$data->{relationships}},$cpdData);
		}
	}
	return $data;
}

1;
