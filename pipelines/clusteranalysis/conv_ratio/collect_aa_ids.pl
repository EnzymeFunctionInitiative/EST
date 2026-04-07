
use strict;
use warnings;

use Getopt::Long;


my ($countFile, $idMappingFile, $outputDir);
my $result = GetOptions(
    "aa-count-file=s"   => \$countFile,
    "id-mapping=s"      => \$idMappingFile,
    "output-dir=s"      => \$outputDir,
);


die "Need input aa-count-file file " if not $countFile or not -f $countFile;
die "Need input id-mapping file" if not $idMappingFile or not -f $idMappingFile;
die "Need output-dir" if not $outputDir or not -d $outputDir;



my $groupCounts = parseCountGroup($countFile);

getIdListFiles($idMappingFile, $groupCounts);






#
# Create files for each residue count and save the IDs in the cluster to the files.
# For example, the output will be count_3.txt, count_4.txt, etc., and count_3.txt
# will contain a list of UniProt IDs that have clusters with 3 residues, etc.
#
sub getIdListFiles {
    my $file = shift;
    my $counts = shift;

    my %rev;
    foreach my $count (keys %$counts) {
        open my $fh, ">", "$outputDir/count_$count.txt" or die "unable to write to output $outputDir/count_$count.txt: $!";
        map { $rev{$_} = $fh } @{$counts->{$count}};
    }

    open my $fh, "<", $file or die "Unable to read id mapping file $file: $!";

    while (<$fh>) {
        chomp;
        my ($id, $clId, @junk) = split(m/\t/);
        $id =~ s/:\d+:\d+$//;
        if (exists $rev{$clId}) {
            $rev{$clId}->print($id, "\n");
        }
    }

    close $fh;
}





#
# Parse the consensus residue position file and return a hash ref that maps residue count to
# list of clusters.
#
sub parseCountGroup {
    my $file = shift;

    open my $fh, "<", $file or die "Unable to read input count file $file: $!";

    my %counts;

    scalar <$fh>;
    while (<$fh>) {
        chomp;
        my ($clId, $size, $numSeq, $numUniprot, @pos) = split(m/\t/);
        push @{$counts{scalar @pos}}, $clId;
    }

    close $fh;

    return \%counts;
}


