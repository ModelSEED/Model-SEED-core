use strict;
use warnings;
use File::Path;
use File::Copy::Recursive;
package ModelSEED::FIGMODEL::workspace;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
=head1 workspace

A user workspace is  directory structure containing files.

=head2 Methods

=head3 clear

    Clear the directory contents.

=head3 print
    
    Prints useful message reporting the current
    workspace status.

=cut

subtype 'DirectoryStr' => as Str => where { $_ =~ /^[a-zA-Z0-9_]+$/; };
has 'id' => ( is => 'ro', isa => 'DirectoryStr', lazy => 1, builder => '_build_id');
has 'owner' => ( is => 'ro', isa => 'DirectoryStr', required => 1);
has 'root' => ( is => 'ro', isa => 'Str', required => 1);
has 'directory' => ( is => 'ro', isa => 'Str',
    lazy => 1, builder => '_build_directory');

sub BUILD {
    my ($self, $params ) = @_;
    if(defined($params->{clear}) && $params->{clear} eq 1) {
        $self->clear();
    }
    if(defined($params->{copy}) &&
        ref($params->{copy}) eq 'ModelSEED::FIGMODEL::workspace') {
        File::Copy::Recursive::dircopy(
            $params->{copy}->directory, $self->directory);
    } 
	File::Path::mkpath($self->directory) unless(-f $self->directory);
}

sub _build_id {
    my $self = shift;
    my $currentFile = $self->root.$self->owner."/current.txt";
    if(-f $currentFile) {
        open(my $fh, "<", $currentFile) || die($@);
        my $id = <$fh>;
        chomp $id; 
        return $id;
    } else {
        return 'default';
    }
}

sub _build_directory {
    my $self = shift;
    return $self->root.$self->owner."/".$self->id."/";
}

sub clear {
    File::Path::rmtree($_[0]->directory);
    File::Path::mkpath($_[0]->directory);
}

sub printWorkspace {
    my ($self) = @_;
    my ($owner, $id, $dir) = ($self->owner, $self->id, $self->directory);
    return "Current workspace: $owner.$id\nAll output will be printed in $dir\n"
}
1;
