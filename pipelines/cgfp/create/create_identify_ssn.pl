
use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Options;
use EFI::SSN::AttributeWriter;
use EFI::SSN::AttributeWriter::Handler::ShortBredMarker;
use EFI::SSN::Util::ID qw(invert_cluster_map parse_cluster_map_file parse_metanode_map_file);
use EFI::Util::CdHit::Parser qw(parse_cdhit_clstr);


# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();



my $cdhitClusters = parse_cdhit_clstr($opts->{cdhit_file});
my $cdhitData = remapCdhitClusters($cdhitClusters);

my (undef, $clusterToSeqMap) = parse_cluster_map_file($opts->{cluster_map});
my $clusterMap = invert_cluster_map($clusterToSeqMap);

my ($idType, $sourceIdMap) = parse_metanode_map_file($opts->{seqid_source_map});

my $markerData = parseMarkerData($opts->{marker_file});


my $xwriter = new EFI::SSN::AttributeWriter(ssn => $opts->{input}, output_file => $opts->{output});

my $markerHandler = new EFI::SSN::AttributeWriter::Handler::ShortBredMarker(marker_data => $markerData, metanode_map => $sourceIdMap, cdhit => $cdhitData);
$xwriter->addAttributeHandler($markerHandler);


$xwriter->write();





















sub remapCdhitClusters {
    my $cdhitClusters = shift;

    my %clusters;
    my %members;

    foreach my $clusterId (keys %$cdhitClusters) {
        my $repId = $cdhitClusters->{$clusterId}->{representative};
        $clusters{ $repId } = undef;
        foreach my $memberId (@{ $cdhitClusters->{$clusterId}->{members} }) {
            $members{$memberId} = $repId if $memberId ne $repId; # Only include non-seed (i.e. representative) IDs in the members list
        }
    }

    return { clusters => \%clusters, members => \%members };
}


sub parseMarkerData {
    my $file = shift;

    open my $fh, "<", $file or die "Unable to read marker data file '$file': $!";

    my $markerData = {};
    while (my $line = <$fh>) {
        chomp $line;

        if ($line =~ m/^>/) {
            # Examples:
            #    >tr|UNIPROTID_TM3_
            #    >UNIPROTID_QM3_
            #    >OTHER_ID3_JM3_
            my ($id, $type) = $line =~ m/^>(?:(?:tr|sp)\|)?([A-Z0-9_\.]+?)_([TJQ]M)[0-9]*_/;
            next if not $id or not $type;
            $markerData->{$id} = {count => 0, type => $type} if not exists $markerData->{$id};
            $markerData->{$id}->{count}++;
        }
    }

    close $fh;

    return $markerData;
}


sub validateAndProcessOptions {

    my $desc = "Creates a SSN XGMML file with ShortBRED marker data included";

    my $optParser = new EFI::Options(app_name => $0, desc => $desc);

    $optParser->addOption("input=s", 1, "path to input XGMML (XML) SSN file", OPT_FILE);
    $optParser->addOption("output=s", 1, "path to output SSN (XGMML) file containing color metadata", OPT_FILE);
    $optParser->addOption("marker-file=s", 1, "path to marker file output from ShortBRED", OPT_FILE);
    $optParser->addOption("cluster-map=s", 1, "path to a file mapping sequence ID to cluster number", OPT_FILE);
    $optParser->addOption("seqid-source-map=s", 1, "path to a file mapping repnode or UniRef IDs in the SSN to sequence IDs within the repnode or UniRef ID cluster (optional)", OPT_FILE);
    $optParser->addOption("cdhit-file=s", 1, "path to CD-HIT .clstr file output from ShortBRED", OPT_FILE);
    $optParser->addOption("title=s", 1, "SSN title to save");

    if (not $optParser->parseOptions() or $optParser->wantHelp()) {
        print $optParser->printHelp();
        exit(not $optParser->wantHelp());
    }

    my $opts = $optParser->getOptions();

    my @errors;
    push @errors, "Error: invalid --input path '$opts->{input}'" if not -f $opts->{input};

    if (@errors) {
        print $optParser->printHelp(\@errors);
        exit(1);
    }

    return $opts;
}

