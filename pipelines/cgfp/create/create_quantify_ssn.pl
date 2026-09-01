
use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Options;
use EFI::SSN::AttributeWriter;
use EFI::SSN::AttributeWriter::Handler::ShortBredQuantify;
use EFI::SSN::Util::ID qw(parse_metanode_map_file);
use EFI::Util::ShortBRED qw(parse_shortbred_cdhit_table parse_metagenome_info);


# Exits if help is requested or errors are encountered
my $opts = validateAndProcessOptions();



my $cdhitData = parse_shortbred_cdhit_table($opts->{cdhit_table});

my ($idType, $sourceIdMap) = parse_metanode_map_file($opts->{seqid_source_map});

my $metagenomeInfo = parse_metagenome_info($opts->{metagenome_db});

my $abundanceData = parseAbundanceData($opts->{protein_abundance}, $opts->{cluster_abundance});


my $xwriter = new EFI::SSN::AttributeWriter(ssn => $opts->{input}, output_file => $opts->{output});

my $handler = new EFI::SSN::AttributeWriter::Handler::ShortBredQuantify(abundance_data => $abundanceData, metagenome_info => $metagenomeInfo, metanode_map => $sourceIdMap, cdhit => $cdhitData);
$xwriter->addAttributeHandler($handler);


$xwriter->write();


saveMetagenomeDesc($metagenomeInfo, $opts->{metagenome_desc});




















sub saveMetagenomeDesc {
    my $metagenomeInfo = shift;
    my $descFile = shift;

    open my $fh, ">", $descFile or die "Unable to write to metagenome description file '$descFile': $!";

    my $headerWritten = 0;
    foreach my $id (sort keys %$metagenomeInfo) {
        if (!$headerWritten) {
            my @headers = ("id");
            push @headers, "body_site" if $metagenomeInfo->{$id}->{body_site};
            push @headers, "gender" if $metagenomeInfo->{$id}->{gender};

            $fh->print(join("\t", @headers), "\n");
            $headerWritten = 1;
            next;
        }

        my @vals = ($id);
        push @vals, $metagenomeInfo->{$id}->{body_site} if $metagenomeInfo->{$id}->{body_site};
        push @vals, $metagenomeInfo->{$id}->{gender} if $metagenomeInfo->{$id}->{gender};

        $fh->print(join("\t", @vals), "\n");
    }

    close $fh;
}


sub parseAbundanceData {
    my $protFile = shift;
    my $clustFile = shift;

    my $cleanupId = 1; # cleanup IDs

    my $data = { metagenomes => [], proteins => {}, clusters => {} };

    if (defined $protFile and -f $protFile) {
        open my $pfh, "<", $protFile or die "Unable to open protein file $protFile: $!";

        my $header = <$pfh>;
        chomp($header);
        my @headerParts = split(m/\t/, $header);
        my ($protId, @mgIds) = @headerParts;
        push(@{$data->{metagenomes}}, @mgIds);

        while (my $line = <$pfh>) {
            chomp $line;
            my ($feature, @results) = split(m/\t/, $line);
            my ($clusterNum, $tempId) = split(m/\|/, $feature);
            $feature = $tempId if $cleanupId and $tempId;
     
            for (my $i = $#results; $i < $#mgIds; $i++) { # Ensure that there are the same amount of results as metagenome headers
                push(@results, 0);
            }
     
            for (my $i = 0; $i <= $#mgIds; $i++) {
                my $mgId = $mgIds[$i];
                $data->{proteins}->{$feature}->{$mgId} = $results[$i];
            }
        }

        close $pfh;
    }

    if (defined $clustFile and -f $clustFile) {
        open my $cfh, $clustFile or die "Unable to open cluster file $clustFile: $!";

        my $header = <$cfh>;
        chomp($header);
        my ($feat, @mgIds) = split(m/\t/, $header);
        push(@{$data->{metagenomes}}, @mgIds) if not scalar @{$data->{metagenomes}};

        while (my $line = <$cfh>) {
            chomp $line;
            my ($feature, @results) = split(m/\t/, $line);
            for (my $i = $#results; $i < $#mgIds; $i++) { # Ensure that there are the same amount of results as metagenome headers
                push(@results, 0);
            }

            for (my $i = 0; $i <= $#mgIds; $i++) {
                my $mgId = $mgIds[$i];
                $data->{clusters}->{$feature}->{$mgId} = $results[$i];
            }
        }

        close $cfh;
    }

    return $data;
}


sub validateAndProcessOptions {

    my $desc = "Creates a SSN XGMML file with ShortBRED marker data included";

    my $optParser = new EFI::Options(app_name => $0, desc => $desc);

    $optParser->addOption("input=s", 1, "path to input XGMML (XML) SSN file", OPT_FILE);
    $optParser->addOption("output=s", 1, "path to output SSN (XGMML) file containing ShortBRED results", OPT_FILE);
    $optParser->addOption("protein-abundance=s", 1, "path to protein abundance results file", OPT_FILE);
    $optParser->addOption("cluster-abundance=s", 1, "path to cluster abundance results file", OPT_FILE);
    $optParser->addOption("metagenome-db=s", 1, "path to metagenome database config file");
    $optParser->addOption("seqid-source-map=s", 1, "path to a file mapping repnode or UniRef IDs in the SSN to sequence IDs within the repnode or UniRef ID cluster", OPT_FILE);
    $optParser->addOption("cdhit-table=s", 1, "path to CD-HIT table file", OPT_FILE);
    $optParser->addOption("metagenome-desc=s", 1, "path to output file containing metagenome description", OPT_FILE);
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

