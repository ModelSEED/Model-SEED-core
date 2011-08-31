#
# Little class to wrap up a file that has a
# label for a button used to trigger a view of it.
#

package ViewableFile;
use File::Basename;

our $is_win32;
eval {
    require Win32;
    $is_win32 = 1;
};

use Moose;

has 'filename' => (is => 'ro',
		   isa => 'Str');

has 'label' => (is => 'ro',
		isa => 'Str');

sub get_path
{
    my($self) = @_;
    my $f = $self->filename;
    if (!$is_win32)
    {
	return $f;
    }
    
    if (-f $f || -d $f)
    {
	return Win32::GetShortPathName($f);
    }
    else
    {
	my $dir = dirname($f);
	my $base = basename($f);
	return Win32::GetShortPathName($dir) . "\\$base";
    }
}


1;
