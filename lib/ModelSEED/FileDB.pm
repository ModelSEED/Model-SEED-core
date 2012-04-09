use strict;
use warnings;
use JSON::Any;
use Data::Dumper;
use Fcntl qw( :flock );
use File::stat; # for testing mod time
use IO::Compress::Gzip qw(gzip);
use IO::Uncompress::Gunzip qw(gunzip);

package ModelSEED::FileDB;
use Moose;
use namespace::autoclean;




with 'ModelSEED::Database';

=head

TODO
  * Put index file back in memory (stored in moose object)
      - test if changed via mod time and size
      - should speed up data access (as long as index hasn't changed)
      - would this work with the locking?
  * Check for .tmp file in BUILD, if it exists then the previous index was not saved
=cut

my $INDEX_EXT = 'ind';
my $META_EXT  = 'met';
my $DATA_EXT  = 'dat';
my $LOCK_EXT  = 'lock';

# External attributes (configurable)
has filename => (is => 'rw', isa => 'Str', required => 1);

=head

Index Structure
{
    ids => { $id => [start, end] }

    end_pos => int

    num_del => int

    ordered_ids => [id, id, id, ...]
}

=cut

sub BUILD {
    my ($self) = @_;

    my $file = $self->filename;

    my $ind = -f "$file.$INDEX_EXT";
    my $met = -f "$file.$META_EXT";
    my $dat = -f "$file.$DATA_EXT";

    if ($ind && $met && $dat) {
	# all exist
    } elsif (!$ind && !$met && !$dat) {
	# new database
	my $index = _initialize_index();
	
	# use a semaphore to lock the files
	open LOCK, ">$file.$LOCK_EXT" or die "$!";
	flock LOCK, LOCK_EX or die "";

	open INDEX, ">$file.$INDEX_EXT" or die "";
	print INDEX _encode($index);
	close INDEX;

	open META, ">$file.$META_EXT" or die "";
	print META _encode({});
	close META;

	open DATA, ">$file.$DATA_EXT" or die;
	close DATA;

	close LOCK;
    } else {
	die "Corrupted database: $file";
    }
}

sub _initialize_index {
    return {
	end_pos     => 0,
	num_del     => 0,
	ids         => {},
	ordered_ids => []
    };
}

sub _perform_transaction {
    my ($self, $files, $sub, @args) = @_;

    # determine which files are required and the mode to open
    my $index_mode = $files->{index};
    my $meta_mode  = $files->{meta};
    my $data_mode  = $files->{data};

    my $file = $self->filename;

    # use a semaphore file for locking
    open LOCK, ">$file.$LOCK_EXT" or die "Couldn't open file: $!";

    # if we're only reading, get a shared lock, otherwise get exclusive
    if ((!defined($index_mode) || $index_mode eq 'r') &&
	(!defined($meta_mode)  || $meta_mode eq 'r') &&
	(!defined($data_mode)  || $data_mode eq 'r')) {

	flock LOCK, LOCK_SH or die "Couldn't lock file: $!";
    } else {
	flock LOCK, LOCK_EX or die "Couldn't lock file: $!";
    }

    # check for errors if last transaction died
    # TODO: implement

=head
    # check if rebuild died between two rename statements
    if (-f "$file.$DATA_EXT.tmp") {
	if (-f "$file.$INDEX_EXT.tmp") {
	    # both exist, roll back transaction by deleting
	    unlink "$file.$DATA_EXT.tmp";
	    unlink "$file.$INDEX_EXT.tmp";
	} else {
	    # index tmp has been copied but data has not
	    rename "$file.$DATA_EXT.tmp", "$file.$DATA_EXT";
	}
    }
=cut

    my $sub_data = {};
    my ($index, $meta, $data);
    if (defined($index_mode)) {
	open INDEX, "<$file.$INDEX_EXT" or die "Couldn't open file: $!";
	$index = _decode(<INDEX>);
	$sub_data->{index} = $index;
	close INDEX;
    }

    if (defined($meta_mode)) {
	open META, "<$file.$META_EXT" or die "Couldn't open file: $!";
	$meta = _decode(<META>);
	$sub_data->{meta} = $meta;
	close META;
    }

    if (defined($data_mode)) {
	if ($data_mode eq 'r') {
	    open DATA, "<$file.$DATA_EXT" or die "Couldn't open file: $!";
	    $data = *DATA;
	    $sub_data->{data} = $data;
	} elsif ($data_mode eq 'w') {
	    # open r/w, '+>' clobbers the file
	    open DATA, "+<$file.$DATA_EXT" or die "Couldn't open file: $!";
	    $data = *DATA;
	    $sub_data->{data} = $data;
	}
    }

    my ($ret, $save) = $sub->($sub_data, @args);

    if (defined($data_mode)) {
	close $data;
    }

    # save files atomically by creating temp files and renaming
    if (defined($save)) {
	if ($save->{index}) {
	    if ($index_mode ne 'w') {
		die "Cannot write to index file, wrong permissions";
	    }

	    open INDEX_TEMP, ">$file.$INDEX_EXT.tmp" or die "Couldn't open file: $!";
	    print INDEX_TEMP _encode($index);
	    close INDEX_TEMP;
	    rename "$file.$INDEX_EXT.tmp", "$file.$INDEX_EXT";
	}

	if ($save->{meta}) {
	    if ($meta_mode ne 'w') {
		die "Cannot write to meta file, wrong permissions";
	    }

	    open META_TEMP, ">$file.$META_EXT.tmp" or die "Couldn't open file: $!";
	    print META_TEMP _encode($meta);
	    close META_TEMP;
	    rename "$file.$META_EXT.tmp", "$file.$META_EXT";
	}
    }

    close LOCK;

    return $ret;
}

# removes deleted objects from the data file
# this locks the database while rebuilding
# much duplicate logic here for locking, should be fixed
# with _perform_transaction rewrite

=head
sub rebuild_data {
    my ($self) = @_;

    # get locked filehandles for index and data files
    my $file = $self->filename;

    # use a semaphore to lock the files
    open LOCK, ">$file.$LOCK_EXT" or die "";
    flock LOCK, LOCK_EX or die "";

    open INDEX, "<$file.$INDEX_EXT" or die "";
    my $index = _decode(<INDEX>);
    close INDEX;

    if ($index->{num_del} == 0) {
	# no need to rebuild
	return 1;
    }

    open DATA, "<$file.$DATA_EXT" or die "";

    # open INDEX_TEMP first
    open INDEX_TEMP, ">$file.$INDEX_EXT.tmp" or die "";
    open DATA_TEMP, ">$file.$DATA_EXT.tmp" or die "";

    my $end = -1;
    my $uuids = []; # new ordered uuid list
    foreach my $uuid (@{$index->{ordered_uuids}}) {
	if (defined($index->{uuid_index}->{$uuid})) {
	    my $uuid_hash = $index->{uuid_index}->{$uuid};
	    my $length = $uuid_hash->{end} - $uuid_hash->{start} + 1;

	    # seek and read the object
	    my $data;
	    seek DATA, $uuid_hash->{start}, 0 or die "";
	    read DATA, $data, $length;

	    # set the new start and end positions
	    $uuid_hash->{start} = $end + 1;
	    $uuid_hash->{end} = $end + $length;

	    # print object to temp file
	    print DATA_TEMP $data;

	    $end += $length;
	    push(@$uuids, $uuid);
	}
    }

    $end++;
    $index->{num_del} = 0;
    $index->{end_pos} = $end;
    $index->{ordered_uuids} = $uuids;

    close DATA;
    close DATA_TEMP;

    print INDEX_TEMP _encode($index);
    close INDEX_TEMP;

    # only point we could get corrupted is between next two statements
    # in '_do_while_locked' check if .dat.tmp exists, but not .int.tmp
    # if it does then indicates we failed here, so rename data
    rename "$file.$INDEX_EXT.tmp", "$file.$INDEX_EXT";
    rename "$file.$DATA_EXT.tmp", "$file.$DATA_EXT";

    close LOCK;

    return 1;
}

=cut

sub has_object {
    my ($self, $id) = @_;

    return $self->_perform_transaction({ index => 'r' },
				       \&_has_object, $id);
}

sub _has_object {
    my ($data, $id) = @_;

    if (defined($data->{index}->{ids}->{$id})) {
	return 1;
    } else {
	return 0;
    }
}

sub get_object {
    my ($self, $id) = @_;

    return $self->_perform_transaction({ index => 'r', data => 'r' },
				       \&_get_object, $id);
}

sub _get_object {
    my ($data, $id) = @_;

    unless (_has_object($data, $id)) {
	return;
    }

    my $start = $data->{index}->{ids}->{$id}->[0];
    my $end   = $data->{index}->{ids}->{$id}->[1];

    my $data_fh = $data->{data};
    my ($json_obj, $gzip_obj);
    seek $data_fh, $start, 0 or die "Couldn't seek file: $!";
    read $data_fh, $gzip_obj, ($end - $start + 1);
    gunzip \$gzip_obj => \$json_obj;

    return _decode($json_obj)
}

sub save_object {
    my ($self, $id, $object) = @_;

    return $self->_perform_transaction({ index => 'w', data => 'w', meta => 'w' },
				       \&_save_object, $id, $object);
}

sub _save_object {
    my ($data, $id, $object) = @_;

    if (_has_object($data, $id)) {
	return 0;
    }

    my $json_obj = _encode($object);
    my $gzip_obj;

    gzip \$json_obj => \$gzip_obj;

    my $data_fh = $data->{data};
    my $start = $data->{index}->{end_pos};
    seek $data_fh, $start, 0 or die "Couldn't seek file: $!";
    print $data_fh $gzip_obj;

    $data->{index}->{ids}->{$id} = [$start, $start + length($gzip_obj) - 1];
    push(@{$data->{index}->{ordered_ids}}, $id);
    $data->{index}->{end_pos} = $start + length($gzip_obj);

    $data->{meta}->{$id} = {};

    return (1, { index => 1, meta => 1 });
}

sub delete_object {
    my ($self, $id) = @_;

    return $self->_perform_transaction({ index => 'w', meta => 'w' },
				       \&_delete_object, $id);
}

sub _delete_object {
    my ($data, $id) = @_;

    unless (_has_object($data, $id)) {
	return 0;
    }

    # should we rebuild the database every once in a while?
    delete $data->{index}->{ids}->{$id};
    $data->{index}->{num_del}++;

    delete $data->{meta}->{$id};

    return (1, { index => 1, meta => 1 });
}

sub get_metadata {
    my ($self, $id, $selection) = @_;

    return $self->_perform_transaction({ meta => 'r' },
				       \&_get_metadata, $id, $selection);
}

sub _get_metadata {
    my ($data, $id, $selection) = @_;

    my $meta = $data->{meta}->{$id};
    unless (defined($meta)) {
	# no object with id
	return;
    }

    if (!defined($selection) || $selection eq "") {
	return $meta;
    }

    my @path = split(/\./, $selection);
    my $last = pop(@path);

    # search through hash for selection
    my $inner_hash = $meta;
    for (my $i=0; $i<scalar @path; $i++) {
	my $cur = $path[$i];
	unless (ref($inner_hash->{$cur}) eq 'HASH') {
	    return;
	}
	$inner_hash = $inner_hash->{$cur};
    }

    unless (exists($inner_hash->{$last})) {
	return;
    }

    return $inner_hash->{$last};
}

sub set_metadata {
    my ($self, $id, $selection, $metadata) = @_;

    return $self->_perform_transaction({ meta => 'w' },
				       \&_set_metadata, $id, $selection, $metadata);
}

sub _set_metadata {
    my ($data, $id, $selection, $metadata) = @_;

    my $meta = $data->{meta}->{$id};
    unless (defined($meta)) {
	# no object with id
	return 0;
    }

    if (!defined($selection) || $selection eq "") {
	if (ref($metadata) eq "HASH") {
	    $data->{meta}->{$id} = $metadata;
	    return (1, { meta => 1 });
	} else {
	    return 0;
	}
    }

    my @path = split(/\./, $selection);

    my $last = pop(@path);
    my $inner_hash = $meta;
    for (my $i=0; $i<scalar @path; $i++) {
	my $cur = $path[$i];

	if (ref($inner_hash->{$cur}) ne 'HASH') {
	    $inner_hash->{$cur} = {};
	}
	$inner_hash = $inner_hash->{$cur};
    }

    $inner_hash->{$last} = $metadata;

    return (1, { meta => 1 });
}

sub remove_metadata {
    my ($self, $id, $selection) = @_;

    return $self->_perform_transaction({ meta => 'w' },
				       \&_remove_metadata, $id, $selection);
}

sub _remove_metadata {
    my ($data, $id, $selection) = @_;

    my $meta = $data->{meta}->{$id};
    unless (defined($meta)) {
	# no object with id
	return 0;
    }

    if (!defined($selection) || $selection eq "") {
	$data->{meta}->{$id} = {};
	return (1, { meta => 1 });
    }

    my @path = split(/\./, $selection);

    my $last = pop(@path);
    my $inner_hash = $meta;
    for (my $i=0; $i<scalar @path; $i++) {
	my $cur = $path[$i];
	if (ref($inner_hash->{$cur}) ne 'HASH') {
	    return 0;
	}
	$inner_hash = $inner_hash->{$cur};
    }

    unless (exists($inner_hash->{$last})) {
	return 0;
    }

    delete $inner_hash->{$last};

    return (1, { meta => 1 });
}

sub find_objects {

}

sub _sleep_test {
    my ($self, $time) = @_;

    $self->_do_while_locked(sub {
	my ($time, $index, $data_fh) = @_;
	my $sleep = sleep $time;
    }, $time);
}

sub _encode {
    my ($data) = @_;

    return JSON::Any->encode($data);
}

sub _decode {
    my ($data) = @_;

    return JSON::Any->decode($data);
}

no Moose;
__PACKAGE__->meta->make_immutable;
