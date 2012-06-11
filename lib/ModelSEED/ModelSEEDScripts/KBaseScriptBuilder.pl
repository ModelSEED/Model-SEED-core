use strict;
use ModelSEED::utilities;
use DateTime;

my $packages = {
	fbaModelServices => {
		host => "bio-data-1.mcs.anl.gov/services/fba",
	},
};

my $scripts = [{
		name => "genome_to_fbamodel",
		"package" => "fbaModelServices",
		primaryInput => ["genome-file","ref"],
		primaryOutput => ["model-file","ref"],
	},{
		name => "fbamodel_to_exchangeformat",
		"package" => "fbaModelServices",
		primaryInput => ["model-file","ref"],
		primaryOutput => ["exchange-file","txt"],
	},{
		name => "exchangeformat_to_fbamodel",
		"package" => "fbaModelServices",
		primaryInput => ["exchange-file","txt"],
		primaryOutput => ["model-file","ref"],
	},{
		name => "fbamodel_to_sbml",
		"package" => "fbaModelServices",
		primaryInput => ["model-file","ref"],
		primaryOutput => ["sbml-file","txt"],
	},{
		name => "fbamodel_to_html",
		"package" => "fbaModelServices",
		primaryInput => ["model-file","ref"],
		primaryOutput => ["html-file","txt"],
	},{
		name => "get_gapfilling_formulation",
		"package" => "fbaModelServices",
		primaryInput => ["formulation-id","txt"],
		primaryOutput => ["formulation-file","ref"],
	},{
		name => "gapfillingFormulation_to_exchangeFormat",
		"package" => "fbaModelServices",
		primaryInput => ["formulation-file","ref"],
		primaryOutput => ["exchange-file","txt"],
	},{
		name => "exchangeFormat_to_gapfillingFormulation",
		"package" => "fbaModelServices",
		primaryInput => ["exchange-file","txt"],
		primaryOutput => ["formulation-file","ref"],
	},{
		name => "gapfill_fbamodel",
		"package" => "fbaModelServices",
		primaryInput => ["model-file","ref"],
		primaryOutput => ["model-file","ref"],
		secondaryInput => ["form","formulation"]
	},{
		name => "runfba",
		"package" => "fbaModelServices",
		primaryInput => ["model-file","ref"],
		primaryOutput => ["model-file","ref"],
		secondaryInput => ["form","formulation"]
},];

foreach my $curr (@{$scripts}) {
	my $secusage = '';
	my $secvar = '';
	my $secload = '';
	my $secargs = '';
	my $jsonparse = '';
	my $outputFormatting = 'print $out_fh $output;';
	if ($curr->{primaryInput}->[1] eq "ref") {
		$jsonparse = "\n".'    $input = $json->decode($input_txt)';	
	}
	if ($curr->{primaryOutput}->[1] eq "ref") {
		$outputFormatting = '$json->pretty(1);'."\n".'print $out_fh $json->encode($output);'
	}
	if (defined($curr->{secondaryInput})) {
		$secvar = "\n".'my $sinput;';
		$secusage = '[--'.$curr->{secondaryInput}->[0].' '.$curr->{secondaryInput}->[1].'] ';
		$secload = 'my $'.$curr->{secondaryInput}->[1].';
if (-e $sinput) {
	my $in_sfh;
	open($in_sfh, "<", $sinput) or die "Cannot open $sinput: $!";
	$'.$curr->{secondaryInput}->[1].' = join("",@{<$in_sfh>});
	close($in_sfh);
} else {
	$'.$curr->{secondaryInput}->[1].' = $sinput;
}';
		$secargs = ',$'.$curr->{secondaryInput}->[1];
	}
	my $text = 
'########################################################################
# '.$curr->{name}.'.pl - This is a KBase command script automatically built from server specifications
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use lib "/home/chenry/kbase/models_api/clients/";
use '.$curr->{"package"}.'Client;
use JSON::XS;

use Getopt::Long;

my $input_file;
my $output_file;'.$secvar.'
my $url = "http://'.$packages->{$curr->{"package"}}->{host}.'";

my $rc = GetOptions(
			\'url=s\'     => \$url,
		    \'input=s\'   => \$input_file,
		    \'output=s\'  => \$output_file,
		    '.( defined($curr->{secondaryInput}) ? '\''.$curr->{secondaryInput}->[0].'=s\' => \$sinput,
		    ' : "" ).');

my $usage = "'.$curr->{name}.' [--input '.$curr->{primaryInput}->[0].'] [--output '.$curr->{primaryOutput}->[0].'] '.$secusage.'[--url service-url] [< '.$curr->{primaryInput}->[0].'] [> '.$curr->{primaryOutput}->[0].']";

@ARGV == 0 or die "Usage: $usage\n";

my $'.$curr->{"package"}.'Obj = '.$curr->{"package"}.'Client->new($url);

my $in_fh;
if ($input_file)
{
    open($in_fh, "<", $input_file) or die "Cannot open $input_file: $!";
}
else
{
    $in_fh = \*STDIN;
}

my $out_fh;
if ($output_file)
{
    open($out_fh, ">", $output_file) or die "Cannot open $output_file: $!";
}
else
{
    $out_fh = \*STDOUT;
}
my $json = JSON::XS->new;

my $input;
{
    local $/;
    undef $/;
    my $input_txt = <$in_fh>;'.$jsonparse.'
}

'.$secload.'
my $output = $'.$curr->{"package"}.'Obj->'.$curr->{name}.'($input'.$secargs.');

'.$outputFormatting.'
close($out_fh);';
ModelSEED::utilities::PRINTFILE("../../KBaseScripts/".$curr->{"package"}."/".$curr->{name}.".pl",[$text]);
};
