
use strict;
use warnings;

use Getopt::Long;
use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Annotations::Fields;




my ($err, $opts) = validateAndProcessOptions();

if ($opts->{help}) {
    printHelp($0);
    exit(0);
}

if (@$err) {
    printHelp($0, $err);
    die "\n";
}


my $parser = XgmmlReader->new(xgmml_file => $opts->{ssn});

$parser->parse();

my $edgelist = $parser->getEdgeList();
saveEdgelist($edgelist, $opts->{edgelist});

my $indexSeqIdMap = $parser->getIndexSeqIdMap();
my $nodeSizeMap = {}; #TODO
saveIndexSeqIdMapping($indexSeqIdMap, $nodeSizeMap, $opts->{index_seqid}, ["node_index", "node_seqid", "node_size"]);

my $idIndexMap = $parser->getIdIndexMap();
saveMapping($idIndexMap, $opts->{id_index}, ["node_id", "node_index"]);










sub saveEdgelist {
    my $edgelist = shift;
    my $file = shift;

    open my $fh, ">", $file or die "Unable to write to edgelist file '$file': $!";

    foreach my $edge (@$edgelist) {
        $fh->print(join(" ", @$edge), "\n");
    }

    close $fh;
}


sub saveIndexSeqIdMapping {
    my $data = shift;
    my $nodeSizes = shift;
    my $file = shift;
    my $header = shift;

    open my $fh, ">", $file or die "Unable to write to mapping file '$file': $!";

    $fh->print(join("\t", @$header), "\n") if $header and ref($header) eq "ARRAY";

    my @keys = sort { $a <=> $b } keys %$data;

    foreach my $key (@keys) {
        my @vals = ($data->{$key});
        push @vals, $nodeSizes->{$key} if $nodeSizes->{$key};
        $fh->print(join("\t", $key, @vals), "\n");
    }

    close $fh;
}


sub saveMapping {
    my $data = shift;
    my $file = shift;
    my $header = shift;

    open my $fh, ">", $file or die "Unable to write to mapping file '$file': $!";

    $fh->print(join("\t", @$header), "\n") if $header and ref($header) eq "ARRAY";

    my @keys = sort keys %$data;
    foreach my $key (@keys) {
        my $val = $data->{$key};
        $fh->print(join("\t", $key, $val), "\n");
    }

    close $fh;
}


sub validateAndProcessOptions {
    my $opts = {};
    my $result = GetOptions(
        $opts,
        "ssn=s",
        "edgelist=s",
        "index-seqid=s",
        "id-index=s",
        "help",
    );

    foreach my $opt (keys %$opts) {
        my $newOpt = $opt =~ s/\-/_/gr;
        my $val = $opts->{$opt};
        delete $opts->{$opt};
        $opts->{$newOpt} = $val;
    }

    my @errors;
    push @errors, "Missing --ssn file argument or doesn't exist" if not ($opts->{ssn});
    push @errors, "Missing --edgelist file argument" if not $opts->{edgelist};
    push @errors, "Missing --index-seqid file argument" if not $opts->{index_seqid};
    push @errors, "Missing --id-index file argument" if not $opts->{id_index};

    return \@errors, $opts;
}


sub printHelp {
    print <<HELP;
Usage: perl $0 --ssn <FILE> --edgelist <FILE> --index-seqid <FILE> --id-index <FILE>

Description:
    Parses an XGMML file to retrieve an edgelist and mapping info.

Options:
    --ssn           path to XGMML (XML) SSN file
    --edgelist      path to an output edgelist file (two column space-separated file)
    --index-seqid   path to an output file mapping node index to XGMML nodeseqid 
                    (and optionally node size for UniRef/repnodes)
    --id-index      path to an output file mapping XGMML node ID to node index

HELP
}





package XgmmlReader;

use strict;
use warnings;

use XML::LibXML::Reader;
use FindBin;

use lib "$FindBin::Bin/../../../lib";

use EFI::Annotations;


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    $self->{input} = $args{xgmml_file};
    $self->{id_idx} = {};
    $self->{idx_seqid} = {};
    $self->{node_idx} = 0;
    $self->{edgelist} = [];
    $self->{anno} = new EFI::Annotations;
    $self->{save_att_names} = { map { $_ => 1 } $self->{anno}->get_expandable_attr() };

    return $self;
}


sub getEdgeList {
    my $self = shift;
    return $self->{edgelist};
}


sub getIndexSeqIdMap {
    my $self = shift;
    return $self->{idx_seqid};
}


sub getIdIndexMap {
    my $self = shift;
    return $self->{id_idx};
}


sub parse {
    my $self = shift;

    my $reader = XML::LibXML::Reader->new(location => $self->{input}) or die "cannot read $self->{input}\n";
    while ($reader->read) {
        $self->processXmlNode($reader);
    }
}


sub processXmlNode {
    my $self = shift;
    my $reader = shift;
    my $ntype = $reader->nodeType;
    my $nname = $reader->name;
    return if $ntype == XML_READER_TYPE_WHITESPACE || $ntype == XML_READER_TYPE_SIGNIFICANT_WHITESPACE;

    #print " " x ($reader->depth * 4);
    #print join(" ", $reader->depth,
    #                         $reader->nodeType,
    #                         $reader->name,
    #                         $reader->isEmptyElement,
    #                     ), "\n";

    $self->{save_att_values} = {};
    my $currentNodeId = "";

    if ($ntype == XML_READER_TYPE_ELEMENT) {
        #print " " x (($reader->depth + 1) * 4);
        if ($nname eq "node") {
            $currentNodeId = $self->processNode($reader);
        } elsif ($nname eq "att") {
            # An 'empty' element is a leaf (e.g. no child elements; <att X="Y" /> is empty)
            if ($reader->isEmptyElement()) {
                $self->processAtt($reader, $currentNodeId);
            }
        } elsif ($nname eq "edge") {
            $self->processEdge($reader);
        }
    }
}


sub processNode {
    my $self = shift;
    my $reader = shift;
    my $id = $reader->getAttribute("id");
    my $seqid = $reader->getAttribute("label") // $id;
    $self->{id_idx}->{$id} = $self->{node_idx};
    $self->{idx_seqid}->{$self->{node_idx}} = $seqid;
    #print "$id,$seqid\n";
    $self->{node_idx}++;
}


sub processEdge {
    my $self = shift;
    my $reader = shift;
    my $source = $reader->getAttribute("source");
    my $target = $reader->getAttribute("target");
    my $sidx = $self->{id_idx}->{$source};
    my $tidx = $self->{id_idx}->{$target};
    push @{ $self->{edgelist} }, [$sidx, $tidx];
    #print "$source,$target\n";
}


sub processAtt {
    my $self = shift;
    my $reader = shift;
    my $currentNodeId = shift;
    my $name = $reader->getAttribute("name");
    my $value = $reader->getAttribute("value");
    my $type = $reader->getAttribute("type") // "string";
    if ($currentNodeId) {
        if ($self->{save_att_names}->{$name}) {
            push @{ $self->{save_att_values}->{$currentNodeId}->{$name} }, $value;
        }
    }
    #print "$name,$value,$type\n";
}


1;


__END__


