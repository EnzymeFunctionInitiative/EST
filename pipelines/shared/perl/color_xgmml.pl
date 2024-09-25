
use strict;
use warnings;

use Getopt::Long;
use FindBin;




my ($err, $opts) = validateAndProcessOptions();

if ($opts->{help}) {
    printHelp($0);
    exit(0);
}

if (@$err) {
    printHelp($0, $err);
    die "\n";
}


my $colors = getColorizer($opts->{color_file});

my $clusterSizes = parseClusterSizeFile($opts->{cluster_size});
my $xwriter = ColorXgmmlWriter->new(ssn => $opts->{ssn}, color_ssn => $opts->{color_ssn}, cluster_map => $opts->{cluster_map}, cluster_sizes => $clusterSizes, colors => $colors);

$xwriter->write();

if ($opts->{cluster_color_map}) {
    saveClusterColorMap($opts->{cluster_color_map}, $xwriter->getClusterColors());
}


















sub saveClusterColorMap {
    my $mapFile = shift;
    my $clusterColors = shift;

    open my $fh, ">", $mapFile or die "Unable to write to cluster color map file '$mapFile': $!";

    $fh->print(join("\t", "cluster_num_seq", "color"), "\n");

    my @clusters = sort { $a <=> $b } keys %$clusterColors;
    foreach my $cnum (@clusters) {
        $fh->print(join("\t", $cnum, $clusterColors->{$cnum}), "\n");
    }

    $fh->close();
}


sub parseClusterSizeFile {
    my $mapFile = shift;

    open my $fh, "<", $mapFile or die "Unable to read cluster map file '$mapFile': $!";

    my $headerLine = <$fh>;

    my $seqSizes = {};
    my $nodeSizes = {};

    while (my $line = <$fh>) {
        chomp $line;
        my ($seqNum, $seqSize, $nodeNum, $nodeSize) = split(m/\t/, $line);
        $seqSizes->{$seqNum} = $seqSize;
        $nodeSizes->{$nodeNum} = $nodeSize;
    }

    close $fh;

    return {seq => $seqSizes, node => $nodeSizes};
}


sub getColorizer {
    my $colorFile = shift;

    return new ClusterColorizer(color_file => $colorFile);
}


sub validateAndProcessOptions {
    my $opts = {};
    my $result = GetOptions(
        $opts,
        "ssn=s",
        "color-ssn=s",
        "cluster-map=s",
        "cluster-size=s",
        "cluster-color-map=s",
        "color-file=s",
        "help",
    );

    foreach my $opt (keys %$opts) {
        my $newOpt = $opt =~ s/\-/_/gr;
        my $val = $opts->{$opt};
        delete $opts->{$opt};
        $opts->{$newOpt} = $val;
    }

    my @errors;
    push @errors, "Missing --ssn file argument or does not exist" if not $opts->{ssn};
    push @errors, "Missing --color-ssn file argument" if not $opts->{color_ssn};
    push @errors, "Missing --cluster-map file argument" if not $opts->{cluster_map};
    push @errors, "Missing --cluster-size file argument" if not $opts->{cluster_size};

    $opts->{color_file} = "$FindBin::Bin/colors.tab" if not $opts->{color_file};
    push @errors, "Missing --color-file (or colors.tab in script directory)" if not $opts->{color_file} or not -f $opts->{color_file};

    return \@errors, $opts;
}


sub printHelp {
    my $script = shift || $0;
    my $errors = shift || [];
    print <<HELP;
Usage: perl $script --ssn <FILE> --color-ssn <FILE> --cluster-map <FILE> --cluster-size <FILE>
    [--color-file <FILE>]

Description:
    Parses a SSN XGMML file and writes it to a new SSN file after coloring and numbering
    the nodes based on cluster.

Options:
    --ssn               path to input SSN (XGMML) file
    --color-ssn         path to output SSN (XGMML) file
    --cluster-map       path to output file mapping node index (col 1) to cluster numbers (num nodes, num sequences)
    --cluster-color-map path to output file mapping cluster number (sequence count) to a color
    --cluster-size      path to input file containing the cluster sizes
    --color-file        path to a file containing a list of colors by cluster;
                        if not specified defaults to 'colors.tab' in the script directory

HELP
    map { print "$_\n"; } @$errors;
}





package ColorXgmmlWriter;

use strict;
use warnings;

use XML::LibXML::Reader;
use XML::Writer;
use FindBin;
use IO::File;

use lib "$FindBin::Bin/../../../lib";

use EFI::Annotations;

use constant SEQ_NUM_FIELD => "Sequence Count Cluster Number";
use constant NODE_NUM_FIELD => "Node Count Cluster Number";
use constant SINGLETON_FIELD => "Singleton Number";
use constant SEQ_NUM_COLOR_FIELD => "node.fillColor";
use constant NODE_NUM_COLOR_FIELD => "Node Count Fill Color";
use constant SEQ_COUNT_FIELD => "Cluster Sequence Count";
use constant NODE_COUNT_FIELD => "Cluster Node Count";


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    $self->{ssn} = $args{ssn};
    $self->{color_ssn} = $args{color_ssn};
    $self->{colors} = $args{colors};
    $self->{cluster_map_file} = $args{cluster_map};
    $self->{cluster_sizes} = $args{cluster_sizes};
    $self->{cluster_color_map} = {};

    $self->{anno} = new EFI::Annotations;

    return $self;
}


#
# getClusterColors
#
# Returns a mapping of cluster numbers (based on number of sequences) to color
#
# Returns:
#    hash ref of cluster number to hex color
#
sub getClusterColors {
    my $self = shift;
    return $self->{cluster_color_map};
}


#
# write
#
# Reads an input XGMML SSN file and writes it to a different file while including cluster information
# such as cluster number and color
#
sub write {
    my $self = shift;

    $self->parseClusterFile($self->{cluster_map_file});

    my $reader = XML::LibXML::Reader->new(location => $self->{ssn}) or die "Cannot read input XGMML file '$self->{ssn}': $!";
    my $output = IO::File->new(">" . $self->{color_ssn});
    # Disable error checking with the UNSAFE keyword; this improves performance
    my $writer = XML::Writer->new(OUTPUT => $output, UNSAFE => 1, PREFIX_MAP => '');
    $self->{writer} = $writer;
    $self->{reader} = $reader;

    # Find out which node attribute we should insert the cluster info at
    $self->{cluster_info_loc} = $self->{anno}->get_cluster_info_insert_location();
    # Skip these fields in the input SSN from being output
    $self->{skip_att} = {&SEQ_NUM_FIELD => 1, &NODE_NUM_FIELD => 1, &SINGLETON_FIELD => 1, &SEQ_NUM_COLOR_FIELD => 1, &NODE_NUM_COLOR_FIELD => 1, &SEQ_COUNT_FIELD => 1, &NODE_COUNT_FIELD => 1, "source" => 1};
    $self->{current_cluster} = undef;

    $self->{writer}->xmlDecl("UTF-8");

    # Notes:
    #    - XML_READER_TYPE_ELEMENT = start of an XML element, both empty and non-empty
    #    - XML_READER_TYPE_END_ELEMENT = end of a non-empty XML element
    #    - an empty element is one without open-close tags (e.g. <att A="B" />)
    #    - the XML reader doesn't load everything into memory, just the current XML element
    #    - the XML writer streams directly to the output file without constructing a DOM
    #    - a SSN node has: 1) node index (the internal numbering for the edgelist);
    #      2) node ID (the value from the SSN 'id' attribute on a 'node' element); and
    #      3) node label (the sequence ID)

    while ($reader->read) {
        my $ntype = $reader->nodeType;
        my $nname = $reader->name;

        if ($nname eq "node") {
            if ($ntype == XML_READER_TYPE_ELEMENT) {
                my $seqId = $reader->getAttribute("label");
                my $id = $reader->getAttribute("id");
                $self->{current_cluster} = $self->getClusterInfo($seqId);
                my @attr = ("id" => $id, "label" => $seqId);
                $self->startTag("node", @attr);
            } elsif ($ntype == XML_READER_TYPE_END_ELEMENT) {
                $self->endTag("node");
                $self->{current_cluster} = undef;
            }
        } elsif ($nname eq "att") {
            if ($ntype == XML_READER_TYPE_ELEMENT) {
                $self->processAttElement();
            } elsif ($ntype == XML_READER_TYPE_END_ELEMENT) {
                $self->endTag("att");
            }
        } elsif ($nname eq "edge") {
            $self->copyEdge();
        } else {
            if ($nname eq "graph") {
                $self->copyElement($ntype);
            } else {
                $self->copyElementWithoutNamespace($ntype);
            }
        }
    }

    $writer->end();
    $output->close();
}


sub copyElement {
    my $self = shift;
    my $ntype = shift;
    if ($ntype == XML_READER_TYPE_ELEMENT) {
        my @attr;
        foreach my $attr ($self->{reader}->copyCurrentNode(0)->getAttributes()) {
            push @attr, $attr->name, $attr->value;
        }
        $self->createElementWithAttr(@attr);
    } elsif ($ntype == XML_READER_TYPE_END_ELEMENT) {
        $self->endTag($self->{reader}->name);
    }
}


sub createElementWithAttr {
    my $self = shift;
    if ($self->{reader}->isEmptyElement()) {
        $self->emptyTag($self->{reader}->name, @_);
    } else {
        $self->startTag($self->{reader}->name, @_);
    }
}

sub copyElementWithoutNamespace {
    my $self = shift;
    my $ntype = shift;
    if ($ntype == XML_READER_TYPE_ELEMENT) {
        my @attr;
        foreach my $attr ($self->{reader}->copyCurrentNode(0)->getAttributes()) {
            next if $attr->name eq "xmlns";
            push @attr, $attr->name, $attr->value;
        }
        $self->createElementWithAttr(@attr);
    } elsif ($ntype == XML_READER_TYPE_END_ELEMENT) {
        $self->endTag($self->{reader}->name);
    }
}


#
# copyEdge - internal method
#
# Copy the current XML element (SSN edge) from the reader to the writer
#
sub copyEdge {
    my $self = shift;
    if ($self->{reader}->nodeType == XML_READER_TYPE_ELEMENT) {
        my @attr;
        # Add attribute to element if it exists in the reader element
        my $addAttr = sub { my $attrName = shift; my $attrValue = $self->{reader}->getAttribute($attrName); push @attr, $attrName => $attrValue if $attrValue; };
        $addAttr->("id");
        $addAttr->("label");
        $addAttr->("source");
        $addAttr->("target");
        if ($self->{reader}->isEmptyElement()) {
            $self->emptyTag("edge", @attr);
        } else {
            $self->startTag("edge", @attr);
        }
    } elsif ($self->{reader}->nodeType == XML_READER_TYPE_END_ELEMENT) {
        $self->endTag("edge");
    }
}


#
# endTag - internal method
#
# Wrapper around the XML writer endTag() method so additional information can be added if needed
#
# Parameters:
#    $name - name of the element tag
#    @_ - the rest of the values passed to the function are attributes for the tag
#
sub endTag {
    my $self = shift;
    $self->{writer}->endTag(@_);
    $self->{writer}->characters("\n");
}


#
# startTag - internal method
#
# Wrapper around the XML writer startTag() method so additional information can be added if needed
#
# Parameters:
#    $name - name of the element tag
#    @_ - the rest of the values passed to the function are attributes for the tag
#
sub startTag {
    my $self = shift;
    $self->{writer}->startTag(@_);
    $self->{writer}->characters("\n");
}


#
# emptyTag - internal method
#
# Wrapper around the XML writer emptyTag() method so additional information can be added if needed
#
# Parameters:
#    $name - name of the element tag
#    @_ - the rest of the values passed to the function are attributes for the tag
#
sub emptyTag {
    my $self = shift;
    $self->{writer}->emptyTag(@_);
    $self->{writer}->characters("\n");
}


#
# processAttElement - internal method
#
# Process the 'att' element that is part of a SSN node by copying the attributes and
# inserting new ones
#
sub processAttElement {
    my $self = shift;

    my $attName = $self->{reader}->getAttribute("name");

    # An 'empty' element is a leaf (e.g. no child elements; <att X="Y" /> is empty);
    # also, skip existing color or cluster number attrs
    if (not $self->{skip_att}->{$attName}) {
        my @attr = $self->getAttAttr($attName);

        # Write the current 'empty' element plus the cluster info if we're at the right column
        if ($self->{reader}->isEmptyElement()) {
            $self->emptyTag("att", @attr);
            # If this att is part of a node, then write the cluster info at the
            # proper location in the child atts of the node
            if ($self->{current_cluster} and $attName eq $self->{cluster_info_loc}) {
                foreach my $info (@{ $self->{current_cluster} }) {
                    my @clusterAttr = ("name" => $info->[0], "value" => $info->[1]);
                    push @clusterAttr, "type" => $info->[2] if $info->[2];
                    $self->emptyTag("att", @clusterAttr);
                }
            }
        # Start the tag for a nested att
        } else {
            $self->startTag("att", @attr);
        }
    }
}


#
# getAttAttr - internal function
#
# Get the attribute from the 'att' element at the current XML reader cursor
#
# Parameters:
#    $attName - attribute name
#
# Returns:
#    List of attributes in the input element
#
sub getAttAttr {
    my $self = shift;
    my $attName = shift;
    my $value = $self->{reader}->getAttribute("value");
    my $attType = $self->{reader}->getAttribute("type");
    my @attr = (name => $attName);
    push @attr, ("value" => $value) if $value;
    push @attr, ("type" => $attType) if $attType;
    return @attr;
}


#
# getClusterInfo - internal function
#
# Get the cluster number, size, and color info for the input sequence ID; the return
# value can be passed directly into the 'emptyTag' method of the XML writer, and
# uses the constants defined at the start of the module.  If the sequence doesn't
# exist in the cluster mapping, then it is a singleton and it is not colored.
#
# Parameters:
#    $seqId - sequence ID (e.g. UniProt)
#
# Returns:
#    Array ref of fields and values
#
sub getClusterInfo {
    my $self = shift;
    my $seqId = shift;

    my @info;
    my $cmap = $self->{cluster_map}->{$seqId};
    if ($cmap) {
        # Cluster number by number of sequences in cluster
        my $seqNum = $cmap->[0];
        # Cluster number by number of nodes in cluster
        my $nodeNum = $cmap->[1];
        my $seqCount = $self->{cluster_sizes}->{seq}->{$seqNum} // 0;
        my $nodeCount = $self->{cluster_sizes}->{node}->{$nodeNum} // 0;
        my $seqColor = $self->{colors}->getColor($seqNum);
        my $nodeColor = $self->{colors}->getColor($nodeNum);

        $self->{cluster_color_map}->{$seqNum} = $seqColor;

        push @info, [SEQ_NUM_FIELD, $seqNum, "integer"];
        push @info, [NODE_NUM_FIELD, $nodeNum, "integer"];
        push @info, [SEQ_NUM_COLOR_FIELD, $seqColor, "string"];
        push @info, [NODE_NUM_COLOR_FIELD, $nodeColor, "string"];
        push @info, [SEQ_COUNT_FIELD, $seqCount, "integer"];
        push @info, [NODE_COUNT_FIELD, $nodeCount, "integer"];
    } else {
        my $singNum = 0; #TODO
        push @info, [SINGLETON_FIELD, $singNum, "integer"];
    }

    return \@info;
}


#
# parseClusterFile - internal function
#
# Parse the cluster info file provided to the script to obtain a mapping of sequence ID
# to cluster number and size
#
# Parameters:
#    $clusterFile - path to file to load
#
sub parseClusterFile {
    my $self = shift;
    my $clusterFile = shift;
    
    open my $fh, "<", $clusterFile or die "Unable to read cluster file '$clusterFile': $!";

    my $header = <$fh>;

    while (my $line = <$fh>) {
        chomp $line;
        my ($seqId, $seqNum, $nodeNum) = split(m/\t/, $line);
        $self->{cluster_map}->{$seqId} = [$seqNum, $nodeNum];
    }

    close $fh;
}




package ClusterColorizer;

use strict;
use warnings;


sub new {
    my ($class, %args) = @_;

    my $self = {colors => {}, default_color => "#6495ED"};
    bless($self, $class);

    $self->parseColorFile($args{color_file});

    return $self;
}


sub parseColorFile {
    my $self = shift;
    my $file = shift;

    open my $fh, "<", $file or die "Unable to parse color file '$file': $!";

    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ m/^\s*$/;
        my ($clusterNum, $color) = split(m/\t/, $line);
        $self->{colors}->{$clusterNum} = $color;
    }

    close $fh;
}


sub getColor {
    my $self = shift;
    my $clusterNum = shift;
    return $self->{colors}->{$clusterNum} // $self->{default_color};
}


1;


__END__


