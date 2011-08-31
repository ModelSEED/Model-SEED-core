#!/usr/bin/env perl
use File::Temp qw(tempfile tempdir);

# NOTE: This should get added onto the init script
# Assume that there's a configuration connection parameters:
my $modelDBFile = '/path/to/modelDB.sqlite'; # where we want the file to be created
my $flatDataDir = '/data/'; # Where ReactioDB, models, etc. are located

my $tarball = $faltDataDir."dumps/modelDB.tar.gz";
# Fail if no download of the database exists
if(!-d $flatDataDir . "dumps" || !-f $flatDataDir . "dumps/modelDB.tar.gz") {
    warn "Could not find modelDB file in download. Tried looking in ". 
    $flatDataDir . "dumps/modelDB.tar.gz\n".
    "Please contact the software developers for assistance.\n";
    exit();
}

# Fail if there already exists a database in the target location.
if(-f$modelDBFile) {
    warn "Database file already exists at $modelDBFile\n".
    "Skipping install of standard database. To install a ".
    "clean modelDB copy, delete this file and try again.";
    exit();
}

# Fail if there's no copy of sqlite
my $binary = `whcih sqlite3`;
unless(defined($binary) && -f $binary) {
    warn "Could not find a copy of SQLite3! ".
    "Install that and try again!";
    exit();
}
# Create temporary directory to extract into
my $tmpDir = tempdir();
system("tar -xzf $tarball -C $tmpDir");
# Fail if there's no file where we expect it to be
unless(-f "$tmpDir/modelDB/modelDB.sqlite") {
    warn "Unable to find sqlite file in $tarball!\n";
    exit();
}
system("cat $tmpDir/modelDB/modelDB.sqlite | $binary $modelDBFile");
