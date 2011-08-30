package WebBrowser;
use URI::Escape;

use strict;

our $have_fileop;
eval
{
    require Win32::FileOp;
    $have_fileop = 1;
};

sub open
{
    my($url) = @_;
    $url =~ s/\|/%7C/g;
    if ($^O eq 'darwin')
    {
	system("open", $url);
    }
    elsif ($^O =~ /win32/i && $have_fileop)
    {
	print "win32 shellexecute $url\n";
	Win32::FileOp::ShellExecute($url);
    }
    elsif ($^O =~ /win32/i)
    {
	print "win32 start $url\n";
	system("start", $url);
    }
    elsif ($^O =~ /linux/i)
    {
	my $rc = system("xdg-open", $url);
	if ($rc != 0)
	{
	    system("firefox", $url);
	}
    }
	    
	
}

1;
