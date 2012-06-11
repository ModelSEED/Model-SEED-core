########################################################################
# runfba.pl - This is a KBase command script automatically built from server specifications
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
use strict;
use lib "/home/chenry/kbase/models_api/clients/";
use fbaModelServicesClient;
use JSON::XS;

use Getopt::Long;

my $input_file;
my $output_file;
my $sinput;
my $url = "http://bio-data-1.mcs.anl.gov/services/fba";

my $rc = GetOptions(
			'url=s'     => \$url,
		    'input=s'   => \$input_file,
		    'output=s'  => \$output_file,
		    'form=s' => \$sinput,
		    );

my $usage = "runfba [--input model-file] [--output model-file] [--form formulation] [--url service-url] [< model-file] [> model-file]";

@ARGV == 0 or die "Usage: $usage\n";

my $fbaModelServicesObj = fbaModelServicesClient->new($url);

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
    my $input_txt = <$in_fh>;
    $input = $json->decode($input_txt)
}

my $formulation;
if (-e $sinput) {
	my $in_sfh;
	open($in_sfh, "<", $sinput) or die "Cannot open $sinput: $!";
	$formulation = join("",@{<$in_sfh>});
	close($in_sfh);
} else {
	$formulation = $sinput;
}
my $output = $fbaModelServicesObj->runfba($input,$formulation);

$json->pretty(1);
print $out_fh $json->encode($output);
close($out_fh);
