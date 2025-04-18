
package EFI::Import::Filter::Taxonomy;

use strict;
use warnings;

use JSON;

use Cwd qw(abs_path);
use File::Basename qw(dirname);
use lib dirname(abs_path(__FILE__)) . "/../../../"; # Import libs
use parent qw(EFI::Import::Filter);

use EFI::Sequence::Type qw(is_unknown_sequence);


sub new {
    my $class = shift;
    my %args = @_;

    die "Require either a predefined filter name or a user-defined filter" if (not $args{predef_filter} and not $args{filter_file});

    my $self = $class->SUPER::new(%args);
    $self->{filter_sql} = {};

    if ($args{predef_filter_file} and -f $args{predef_filter_file}) {
        $self->loadPredefinedFilters($args{predef_filter_file});
    }

    if ($args{predef_filter}) {
        if ($self->{filter_sql}->{$args{predef_filter}}) {
            $self->{filter_clause} = $self->{filter_sql}->{$args{predef_filter}};
        }
    } else {
        $self->{filter_clause} = $self->parseFilter($args{filter_file});
    }

    die "Unable to apply taxonomy filter because no filter was detected" if not $self->{filter_clause};

    return $self;
}


sub applyFilter {
    my $self = shift;
    my $seqs = shift;

    my @ids = $seqs->getAllSequenceIds();
    @ids = grep { not is_unknown_sequence($_) } @ids;
    my $sql = "SELECT accession FROM annotations LEFT JOIN taxonomy ON annotations.taxonomy_id = taxonomy.taxonomy_id WHERE accession IN (<IDS>) AND ($self->{filter_clause})";
    my $matched = $self->getMatchedSequences(\@ids, $sql);

    my $numRemoved = 0;
    foreach my $id (@ids) {
        $seqs->removeSequence($id) and $numRemoved++ if not exists $matched->{$id};
    }

    $self->{stats}->addValue("num_filter_taxonomy", $numRemoved);
}


sub parseFilter {
    my $self = shift;
    my $filterFile = shift;

    my $filterString = $self->readFile($filterFile);

    my $json = decode_json($filterString);
    die "Invalid JSON filter string" if not $json or not $json->[0];

    my $whereClause = $self->parseFilterJson($json->[0]);

    return $whereClause;
}


sub loadPredefinedFilters {
    my $self = shift;
    my $file = shift;

    my $fileContents = $self->readFile($file);

    my $json = decode_json($fileContents);
    die "Invalid JSON predefined filter string" if not $json;

    foreach my $filter (@$json) {
        my $whereClause = $self->parseFilterJson($filter);
        $self->{filter_sql}->{$filter->{name}} = $whereClause;
    }
}


sub readFile {
    my $self = shift;
    my $file = shift;

    my $fileContents = "";
    open my $fh, "<", $file or die "Unable to read predefined taxonomy filter file '$file': $!";
    while (my $line = <$fh>) {
        $fileContents .= $line;
    }
    close $fh;

    return $fileContents;
}


sub parseFilterJson {
    my $self = shift;
    my $filter = shift;

    my @conditions;
    foreach my $cond (@{ $filter->{conditions} }) {
        my $negate = (exists $cond->{negate} and $cond->{negate} eq "true");
        my $useLike = (exists $cond->{exact} and $cond->{exact} eq "false");
        my $compOp = $useLike ? ($negate ? "NOT LIKE" : "LIKE") : ($negate ? "!=" : "=");
        push @conditions, "$cond->{field} $compOp '$cond->{value}'";
    }
    my $condOp = (exists $filter->{operator} and $filter->{operator} eq "AND") ? " AND " : " OR ";
    my $whereClause = join($condOp, @conditions);

    return $whereClause;
}


1;

