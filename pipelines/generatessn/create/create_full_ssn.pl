#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use Getopt::Long;
use JSON;
use List::MoreUtils qw{uniq};

use lib "$FindBin::Bin/../../../lib";

use EFI::Annotations::Fields qw(:annotations);
use EFI::EST::AlignmentScore qw(compute_ascore);
use EFI::Options;
use EFI::Sequence::Collection;
use EFI::Sequence::Type qw(get_sequence_type);
use EFI::SSN::XgmmlWriter;
use EFI::Util::FASTA qw(read_fasta_file);

use constant DEFAULT_MAX_EDGES => 10000000;
use constant VALID => 1;




# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();


my ($status, $seqType, $numEdges) = validateInputBlast($opts->{blast}, $opts->{max_edges});
if ($status != VALID) {
    print "Unable to create SSN: BLAST file size ($numEdges edges) exceeds the maximum number of edges ($opts->{max_edges})\n";
    exit(1);
}




my $title = $opts->{title} ? "$opts->{title} Full Network" : "Full Network";
my $dbVersion = $opts->{db_version} // 0;

my $inputIds = new EFI::Sequence::Collection();
$inputIds->load($opts->{metadata});

my $sequences = read_fasta_file($opts->{fasta});

my $connectivity = loadConnectivity($opts->{nc_map});

my $edges = loadEdges($opts->{blast});

my $writer = new EFI::SSN::XgmmlWriter(output_file => $opts->{output}, use_min_edge_attr => $opts->{use_min_edge_attr}, db_version => $dbVersion, seq_type => $seqType);
$writer->write($inputIds, $sequences, $connectivity, $title, $edges);


saveStats($opts->{stats}, $writer->getStats()) if $opts->{stats};

















#
# saveStats
#
# Saves SSN statistics to a JSON-formatted output file.
#
# Parameters:
#    $stats - hash ref returned from EFI::SSN::XgmmlWriter
#
sub saveStats {
    my $file = shift;
    my $stats = shift;

    my $mergedStats = {};
    if (-f $file) {
        my $json = "";
        open my $fh, "<", $file or die "Unable to open existing stats file '$file': $!";
        while (my $line = <$fh>) {
            chomp $line;
            $json .= $line;
        }
        close $fh;

        $mergedStats = decode_json($json);
        $mergedStats = {} if not $mergedStats;
    }

    foreach my $key (keys %$stats) {
        $mergedStats->{$key} = $stats->{$key};
    }

    my $json = encode_json($mergedStats);

    open my $fh, ">", $file or die "Unable to write to stats file '$file': $!";
    $fh->print($json);
    close $fh;
}


#
# loadEdges
#
# Loads the SSN edges by reading the BLAST results file and computing the alignment score.
#
# Parameters:
#    $inputBlast - path to input BLAST file from all-by-all
#
# Returns:
#    array ref of edges, with each edge being a hash ref of edge data
#
# Notes:
#
# An edge consists of a source (the BLAST query ID, qid), target (the BLAST source ID, sid), an
# alignment score (ascore), percent identity (pid), and alignment length (alen).
#
sub loadEdges {
    my $inputBlast = shift;

    # Write edges to the SSN
    open my $bfh, "<", $inputBlast or die "Could not open BLAST file '$inputBlast': $!";

    my @edges;

    while (my $line = <$bfh>) {
        chomp $line;

        my @parts = split /\t/, $line;
        #   0     1     2     3      4          5      6
        my ($qid, $sid, $pid, $alen, $bitscore, $qlen, $slen) = @parts;

        my $alignmentScore = compute_ascore(@parts);

        push @edges, { source => $qid, target => $sid, pid => $pid, ascore => $alignmentScore, alen => $alen };
    }

    close $bfh;

    return \@edges;
}


#
# loadConnectivity
#
# Loads the neighborhood connectivity data.
#
# Parameters:
#    $ncMapFile - path to file containing sequence ID, neighborhood connectivity (NC) value, and
#        color of the node as computed by the NC tool
#
# Returns:
#    hash ref mapping ID to NC and color; empty hash if file doesn't exist or is not specified
#
sub loadConnectivity {
    my $ncMapFile = shift;

    my $connectivity = {};

    return $connectivity if not $ncMapFile or not -f $ncMapFile;

    open my $fh, "<", $ncMapFile;
    while (my $line = <$fh>) {
        chomp($line);
        my ($id, $nc, $color) = split(m/\t/, $line);
        $connectivity->{$id} = {nc => $nc, color => $color};
    }
    close $fh;

    return $connectivity;
}


#
# validateInputBlast
#
# Verify that the number of edges (i.e. the number of results from the all-by-all BLAST) is within
# an acceptable range.  A zero value indicates an unlimited amount of edges are permitted.
#
# Parameters:
#    $inputBlast - path to results from all-by-all BLAST
#    $maxEdges - maximum number of edges to use
#
# Returns:
#    1 if number of edges is valid, 0 otherwise
#    sequence type (e.g. family domain or full)
#    number of edges in the BLAST file (computed using the Linux 'wc' command)
#
sub validateInputBlast {
    my $inputBlast = shift;
    my $maxEdges = shift;

    # Grab first line of file
    open my $fh, "<", $inputBlast or die "Unable to read input BLAST file '$inputBlast': $!";
    my $line = "";
    while (not ($line = <$fh>)) {};
    close $fh;

    my ($sid, $qid, @p) = split(m/\t/, $line);
    my $seqType = get_sequence_type($sid);

    return (VALID, $seqType, 0) if not $maxEdges;

    my $blastlength = `wc -l $inputBlast`;
    my @blastlength = split(/\s+/, $blastlength);
    my $numEdges = $blastlength[0];
    chomp($numEdges);

    if (int($numEdges) > $maxEdges) {
        return (0, $seqType, $numEdges);
    } else {
        return (VALID, $seqType, $numEdges);
    }
}


sub validateAndProcessOptions {

    my $optParser = new EFI::Options(app_name => $0, desc => "Organizes the IDs in the input cluster map file into files by cluster");

    $optParser->addOption("blast=s", 1, "path to file containing BLAST all-by-all results", OPT_FILE);
    $optParser->addOption("fasta=s", 1, "path to file containing FASTA sequences used in BLAST", OPT_FILE);
    $optParser->addOption("metadata=s", 1, "path to file containing sequence metadata", OPT_FILE);
    $optParser->addOption("output=s", 1, "path to output file");
    $optParser->addOption("title=s", 0, "SSN title");
    $optParser->addOption("max-edges=i", 0, "maximum number of edges to write to file; exits with error if number of edges exceeds this value");
    $optParser->addOption("db-version=s", 0, "EFI database version");
    $optParser->addOption("use-min-edge-attr", 0, "only use the minimum number of edge attributes required; makes file size smaller");
    $optParser->addOption("nc-map=s", 0, "path to a network connectivity map file");
    $optParser->addOption("stats=s", 0, "path to file containing SSN statistics");

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    my $opts = $optParser->getOptions();

    $opts->{max_edges} = DEFAULT_MAX_EDGES if not defined $opts->{max_edges};

    return $opts;
}


