#!/usr/bin/perl -w
use strict;

#Creating the temporary scratch directory
if (!-d "/scratch/temp_unwrap_kegg/") {
	system("mkdir /scratch/temp_unwrap_kegg/");
}

#Getting pathway files
chdir("/scratch/temp_unwrap_kegg/");
system("wget ftp://ftp.genome.jp/pub/kegg/pathway/map_title.tab");
system("wget -m ftp://ftp.genome.jp/pub/kegg/pathway/map");

#Unwrapping the tar
if (-e "/vol/biodb/kegg/current/ligand.tar.gz") {
	system("mkdir /scratch/temp_unwrap_kegg/ligand/");
	system("tar -xzf /vol/biodb/kegg/current/ligand.tar.gz /scratch/temp_unwrap_kegg/ligand/")
}

#Deleting the temporary scratch directory
#system("rm -rf /scratch/temp_unwrap_kegg/");
