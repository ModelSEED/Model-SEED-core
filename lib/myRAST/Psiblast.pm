
package Psiblast;

use Moose;
use LWP::UserAgent;
use File::Temp;
use Time::HiRes 'gettimeofday';

use Wx ':everything';
use wxPerl::Constructors;
use Wx::Event qw(EVT_TIMER);

has 'ua' => (isa => 'LWP::UserAgent',
	     is => 'ro',
	     lazy => 1,
	     default => sub { LWP::UserAgent->new() },
	     );

has 'url' => (isa => 'Str',
	      is => 'rw',
	      default => 'http://blast.ncbi.nlm.nih.gov/Blast.cgi',
	      );

has 'open_in_iframe' => (isa => 'Bool',
			 is => 'rw',
			 default => 1);

=head1 NAME

Psiblast - support for NCBI Psiblast runs

=head1 DESCRIPTION

Wrapper code for invoking psiblast at NCBI.

=head1 METHODS

=over 4

=item B<<($rid, $cdd_rid) = $psiblast->psiblast($sequence)>>

Run a psiblast, and return the "run id" C<$rid> and "CDD run id" C<$cdd_rid>.

These may then be used in the C<show_psiblast> and C<show_cdd> methods.

=item B<< $psiblast->show_psiblast($run_rid)>>

=item B<< $psiblast->show_cdd($cdd_rid)>>


=cut

sub psiblast
{
    my($self, $seq) = @_;

    my $dialog = Wx::Dialog->new(undef, -1, "NCBI Psiblast Progress");

    my $sizer = Wx::BoxSizer->new(wxVERTICAL);
    my $msg = wxPerl::StaticText->new($dialog, "");
    $sizer->Add($msg, 0, wxEXPAND);
    
    my $gauge = wxPerl::Gauge->new($dialog, 10, style => wxGA_HORIZONTAL);
    $sizer->Add($gauge, 0, wxEXPAND);

    my $bsizer = $dialog->CreateButtonSizer(wxCANCEL);
    $sizer->Add($bsizer);

    $dialog->SetSizer($sizer);
    $dialog->Layout();
    $dialog->Show();

    my $timer = Wx::Timer->new($dialog);

    my $req = {
	QUERY => $seq,
	DATABASE => 'nr',
	CDD_SEARCH => 'on',
	COMPOSITION_BASED_STATISTICS => 'on,',
	FILTER => 0,
	EXPECT => 10,
	WORD_SIZE => 3,
	MATRIX_NAME => 'BLOSUM62',
	NCBI_GI => 'on',
	GRAPHIC_OVERVIEW => 'is_set',
	FORMAT_OBJECT => 'Alignment',
	FORMAT_TYPE => 'HTML',
	DESCRIPTIONS => 500,
	ALIGNMENTS => 250,
	ALIGNMENT_VIEW => 'Pairwise',
	SHOW_OVERVIEW => 'on',
	RUN_PSIBLAST => 'on',
	I_THRESH => 0.002,
	AUTO_FORMAT => 'on',
	PROGRAM => 'blastp',
	CLIENT => 'web',
	PAGE => 'Proteins',
	SERVICE => 'plain',
	CMD => 'Put',
    };
    print STDERR "Post..\n";
    $msg->SetLabel("Query NCBI...");
    $dialog->Update();
    $dialog->Refresh();
    my $res = $self->ua->post($self->url, $req);
    print STDERR "returned\n";

    my $done = 0;
    my($rid, $cdd_rid);
    while (!$done)
    {
	if ($res->is_success)
	{
	    my $dat = $res->content;
	    
	    my($timeout) = $dat =~ /var\s*tm\s*=\s*"(\d+)"/;
	    ($rid) = $dat =~ /input name="RID".*?value="([A-Z0-9]+)"/;
	    ($cdd_rid) = $dat =~ /input name="CDD_RID".*?value="([A-Z0-9]+)"/;
	    my $waiting = $dat =~ /This page will be automatically updated/;
	    print "timeout=$timeout cdd_rid=$cdd_rid rid=$rid waiting=$waiting\n";

	    if ($waiting)
	    {
		if (defined($timeout))
		{
		    $timeout /= 1000;
		    $msg->SetLabel("Waiting $timeout seconds for results...");
		    $dialog->Update();
		    $dialog->Refresh();
		    print STDERR "Sleeping $timeout\n";

		    $gauge->SetRange($timeout * 10);
		    $gauge->SetValue(0);
		    my $finish = gettimeofday + $timeout;
		    my $left = $timeout;
		    EVT_TIMER($dialog, $timer, sub {
			my $now = gettimeofday;
			$left = $finish - gettimeofday;
			my $v = int(($timeout - $left) * 10);
			$gauge->SetValue($v);
		    });
		    $timer->Start(100);
		    
		    my $app = Wx::App::GetInstance();
		    while ($left > 0)
		    {
			while ($app->Pending())
			{
			    $app->Dispatch();
			}
		    }
		    $timer->Stop();
		}
		print STDERR "get res\n";
		$msg->SetLabel("Query NCBI...");
		$dialog->Update();
		$dialog->Refresh();
		$res = $self->ua->get("http://blast.ncbi.nlm.nih.gov/Blast.cgi?CMD=Get&VIEW_RESULTS=FromRes&RID=$rid&QUERY_INDEX=0");
		print "STDERR done\n";
	    }
	    else
	    {
		print STDERR "done rid=$rid \n";
		$done = 1;
	    }
	}
	else
	{
	    warn "failure " . $res->content;
	    $dialog->Destroy();
	    return undef;
	}
    }

    $dialog->Destroy();

    return($rid, $cdd_rid);
}

sub show_psiblast
{
    my($self, $rid, $cdd_rid) = @_;

    print "Show $rid $cdd_rid\n";
    my @params = (RID => $rid,
	       ViewReport => 'View+report',
	       FORMAT_OBJECT => 'Alignment',
	       FORMAT_TYPE => 'HTML',
	       PSSM_FORMAT_TYPE => 'Text',
	       BIOSEQ_FORMAT_TYPE => 'ASN.1',
	       PSSM_SC_FORMAT_TYPE => 'ASN.1',
	       ALIGNMENT_VIEW => 'Pairwise',
	       SHOW_OVERVIEW => 'on',
	       SHOW_LINKOUT => 'on',
	       GET_SEQUENCE => 'on',
	       MASK_CHAR => '2',
	       MASK_COLOR => '1',
	       DESCRIPTIONS => '100',
	       NUM_OVERVIEW => '100',
	       ALIGNMENTS => '50',
	       FORMAT_ORGANISM => '',
	       FORMAT_EQ_TEXT => '',
	       EXPECT_LOW => '',
	       EXPECT_HIGH => '',
	       RUN_PSIBLAST_FORM => 'on',
	       I_THRESH => '0.002',
	       CDD_RID => $cdd_rid,
	       CDD_SEARCH_STATE => '0',
	       STEP_NUMBER => '1',
	       CMD => 'Get',
	       FORMAT_EQ_OP => 'AND',
	       QUERY_INFO => '',
	       ENTREZ_QUERY => '',
	       QUERY_INDEX => '0',
	       BLAST_PROGRAMS => 'psiBlast',
	       PAGE => 'Proteins',
	       PROGRAM => 'blastp',
	       MEGABLAST => '',
	       RUN_PSIBLAST => 'on',
	       BLAST_SPEC => '',
#	       QUERY => '%3Efig|12149.1.peg.2373+MDYTLTRIDPNGENDRYPLQKQEIVTDPLEQEVNKNVFMGKLHDMVNWGRKNSIWPYNFGLSCCYVEMVT+SFTAVHDVARFGAEVLRASPRQADLMVVAGTCFTKMAPVIQRLYDQMLEPKWVISMGACANSGGMYDIYS+VVQGVDKFIPVDVYIPGCPPRPEAYMQALMLLQESIGKERRPLSWVVGDQGVYRANMQSERERKRGERIA+VTNLRTPDEI',
#	       JOB_TITLE => 'fig|12149.1.peg.2373+%28220+letters%29',
	       QUERY_TO => '',
	       QUERY_FROM => '',
	       EQ_TEXT => '',
	       ORGN => '',
	       EQ_MENU => '',
	       ORG_EXCLUDE => '',
	       PHI_PATTERN => '',
	       EXPECT => '10',
	       DATABASE => 'nr',
	       DB_GROUP => '',
	       SUBGROUP_NAME => '',
	       GENETIC_CODE => '',
	       WORD_SIZE => '3',
	       MATCH_SCORES => '',
	       MATRIX_NAME => 'BLOSUM62',
	       GAPCOSTS => '11+1',
	       MAX_NUM_SEQ => '100',
	       COMPOSITION_BASED_STATISTICS => '0',
	       NEWWIN => '',
	       SHORT_QUERY_ADJUST => '',
	       FILTER => '',
	       REPEATS => '',
	       ID_FOR_PSSM => '',
	       EXCLUDE_MODELS => '',
	       EXCLUDE_SEQ_UNCULT => '',
	       NUM_ORG => '1',
	       LCASE_MASK => '',
	       TEMPLATE_TYPE => '',
	       TEMPLATE_LENGTH => '',
	       I_THRESH => '0.002',
	       PSI_PSEUDOCOUNT => '0',
	       HSP_RANGE_MAX => '0',
	       ADJUSTED_FOR_SHORT_QUERY => '',
	       MIXED_QUERIES => ''
	       );

    my @x;
    while (my($k, $v) = splice(@params, 0,2 ))
    {
	push(@x, "$k=$v");
    }
    my $q = join("&", @x);
    my $url = "http://blast.ncbi.nlm.nih.gov/Blast.cgi?$q";
    print "open $url\n";
    WebBrowser::open($url);
}

sub show_cdd
{
    my($self, $cdd_rid) = @_;
    my $url = "http://www.ncbi.nlm.nih.gov/Structure/cdd/wrpsb.cgi?RID=$cdd_rid&mode=all";
    WebBrowser::open($url);
}

1;
