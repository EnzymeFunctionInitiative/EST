
package EFI::SSN::Util::Creator;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../..";

use EFI::Options;
use EFI::Sequence::Type qw(get_sequence_type);

use constant DEFAULT_MAX_EDGES => 200000000;
use constant VALID_BLAST_INPUT => 1;

use Exporter qw(import);
our @EXPORT_OK = qw(load_connectivity load_edges validate_and_process_options validate_input_blast DEFAULT_MAX_EDGES);




sub validate_and_process_options {
    my $computeRepnode = shift || 0;

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
    $optParser->addOption("stats=s", 0, "path to file to output SSN statistics to");
    if ($computeRepnode) {
        $optParser->addOption("cdhit=s", 1, "path to file containing CD-HIT clusters", OPT_FILE);
    }

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    my $opts = $optParser->getOptions();

    $opts->{max_edges} = DEFAULT_MAX_EDGES if not defined $opts->{max_edges};

    return $opts;
}



#
# load_edges
#
# Creates a generator function that returns edge data every time it is called.
#
# Parameters:
#    $inputBlast - path to input BLAST file from all-by-all
#
# Returns:
#    A "generator" function that yields edge data every time it is called.  The data returned
#    by the iterator contains a hash ref of edge data (source, target, pid, ascore, alen).  The
#    return value is undef when the end of the file is reached
#
# Notes:
#
# An edge consists of a source (the BLAST query ID, qid), target (the BLAST source ID, sid), an
# alignment score (ascore), percent identity (pid), and alignment length (alen).
#
sub load_edges {
    my $inputBlast = shift;

    open my $bfh, "<", $inputBlast or die "Could not open BLAST file '$inputBlast': $!";

    return sub {
        my $line = <$bfh>;
        return if not $line;

        chomp $line;

        my ($qid, $sid, $pid, $alen, $bitscore, $qlen, $slen, $alignmentScore) = split(/\t/, $line);

        return {
            source => $qid,
            target => $sid,
            pid => $pid,
            ascore => $alignmentScore,
            alen => $alen,
        };
    }
}


#
# load_connectivity
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
sub load_connectivity {
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
# validate_input_blast
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
sub validate_input_blast {
    my $inputBlast = shift;
    my $maxEdges = shift;

    # Grab first line of file
    open my $fh, "<", $inputBlast or die "Unable to read input BLAST file '$inputBlast': $!";
    my $line = "";
    # Skip empty lines
    while (not ($line = <$fh>) and not eof($fh)) {};
    close $fh;

    # File was empty
    return (1, undef, 0) if not $line;

    my ($sid, $qid, @p) = split(m/\t/, $line);
    my $seqType = get_sequence_type($sid);

    # No limit
    return (1, $seqType, 0) if not $maxEdges;

    my $blastlength = `wc -l $inputBlast`;
    my @blastlength = split(/\s+/, $blastlength);
    my $numEdges = $blastlength[0];
    chomp($numEdges);

    if (int($numEdges) > $maxEdges) {
        # Too many edges
        return (0, $seqType, $numEdges);
    } else {
        # Acceptable number
        return (VALID_BLAST_INPUT, $seqType, $numEdges);
    }
}


1;
