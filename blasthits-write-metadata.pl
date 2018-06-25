#!/usr/bin/env perl

BEGIN {
    die "Please load efishared before runing this script" if not $ENV{EFISHARED};
    use lib $ENV{EFISHARED};
}


use strict;
use warnings;

use Getopt::Long;
use FindBin;

use EFI::Annotations;

use lib $FindBin::Bin . "/lib";
use BlastUtil;



my ($idListFile, $metaFile, $sequence);
my $result = GetOptions(
    "accessions=s"          => \$idListFile,
    "meta-file=s"           => \$metaFile,
    "sequence=s"            => \$sequence,
);


die "Missing accession file" if not defined $idListFile or not -f $idListFile;
die "Missing metadata file option" if not defined $metaFile or not $metaFile;


my @ids;

open IDFILE, $idListFile or die "Unable to open accessions file $idListFile: $!";
while (<IDFILE>) {
    chomp;
    push @ids, $_;
}
close IDFILE;



open METAFILE, ">$metaFile" or die "Unable to write to metadata file $metaFile: $!";
foreach my $id (@ids) {
    print METAFILE "$id\n";
    print METAFILE "\t" . EFI::Annotations::FIELD_SEQ_SRC_KEY . "\t" . EFI::Annotations::FIELD_SEQ_SRC_VALUE_BLASTHIT . "\n";
}

BlastUtil::write_input_sequence_metadata($sequence, \*METAFILE);

close METAFILE;



