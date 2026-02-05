
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
__END__

=head1 NAME

B<EFI::Import::Filter::Taxonomy> - Perl module for applying taxonomy-based filters to sequence data


=head1 SYNOPSIS

This document describes the JSON file format used by the B<EFI::Import::Filter::Taxonomy> module
to define taxonomy filters. These filters are used to include or exclude sequences based on their
taxonomic classification.


=head1 JSON FILE FORMAT

The JSON file format is an array of filter objects. Each object can define a filter by name, which can be referenced later.

    [
        {
            "name": "filter_name_1",
            "operator": "AND" | "OR",
            "conditions": [ ... ]
        },
        {
            "name": "filter_name_2",
            "operator": "AND" | "OR",
            "conditions": [ ... ]
        }
    ]

=head2 Top-Level Filter Object

Each top-level object in the array represents a single, named filter.

=over

=item B<name> (string, required)

A unique name for the filter. This name is used to load a predefined filter from the file.

=item B<operator> (string, required)

The logical operator that combines the conditions within the filter. Supported values are:

=over

=item C<"AND">: All conditions must be met.

=item C<"OR">: At least one condition must be met.

=back

=item B<conditions> (array of objects, required)

An array of condition objects. Each object defines a single filtering rule.

=back

=head2 Condition Object

Each object within the C<conditions> array defines a specific filtering rule.

=over

=item B<field> (string, required)

The name of the taxonomic field to filter on. Examples include C<"domain">, C<"phylum">, or C<"species">.

=item B<value> (string, required)

The value to match against the specified field.

=item B<negate> (string, optional)

----------------------------------------------------------------------------------------------------
If present and set to C<"true">, the condition is negated. This effectively changes the operator
from equality to inequality (e.g., C<"="> becomes C<"!=">) or from C<"LIKE"> to C<"NOT LIKE">.

=item B<exact> (string, optional)

If present and set to C<"false">, the condition uses SQL's C<LIKE> operator for a pattern match
instead of an exact equality match (C<"=">). When C<exact> is C<"false">>, the C<value> can contain
SQL wildcard characters like C<%> and C<_>. If C<negate> is also C<"true">, it will use C<"NOT LIKE">.

=back


=head1 SUPPORTED OPERATORS

The module translates the JSON filter objects into SQL C<WHERE> clauses. The following operators
are supported based on the combination of the C<negate> and C<exact> fields:

=over

=item B<Exact Match>

Uses the SQL C<=> operator. This is the default if both C<negate> and C<exact> are not specified,
or if C<exact> is not C<"false">.

Example: C<< { "field": "domain", "value": "Bacteria" } >>

SQL equivalent: C<< domain = 'Bacteria' >>

=item B<Not Equal>

Uses the SQL C<!=> operator. This is used when C<negate> is C<"true"> and C<exact> is not C<"false">.

Example: C<< { "field": "domain", "value": "Eukaryota", "negate": "true" } >>

SQL equivalent: C<< domain != 'Eukaryota' >>

=item B<Pattern Match (LIKE)>

Uses the SQL C<LIKE> operator. This is used when C<exact> is C<"false"> and C<negate> is not C<"true">.

Example: C<< { "field": "species", "value": "%metagenome%", "exact": "false" } >>

SQL equivalent: C<< species LIKE '%metagenome%' >>

=item B<Pattern Match (NOT LIKE)>

Uses the SQL C<NOT LIKE> operator. This is used when both C<negate> is C<"true"> and C<exact> is C<"false">.

Example: C<< { "field": "phylum", "value": "Ascomycota", "negate": "true", "exact": "false" } >>

SQL equivalent: C<< phylum NOT LIKE 'Ascomycota' >>

=back


=head1 EXAMPLES

A filter that represents Eukaryota but excludes fungi:

	[
	    {
            "name": "eukaroyta_no_fungi",
            "operator": "AND",
            "conditions": [
                {
                    "field": "domain",
                    "value": "Eukaryota"
                },
                {
                    "field": "phylum",
                    "value": "Ascomycota",
                    "operator": "NOT"
                },
                {
                    "field": "phylum",
                    "value": "Basidiomycota",
                    "operator": "NOT"
                },
                {
                    "field": "phylum",
                    "value": "Fungi incertae sedis",
                    "operator": "NOT"
                },
                {
                    "field": "phylum",
                    "value": "unclassified Fungi",
                    "operator": "NOT"
                },
                {
                    "field": "species",
                    "value": "%metagenome%",
                    "operator": "NOT",
                    "exact": false
                }
            ]
        }
	]

A user-defined filter that includes Bacteria only:

    [
        {
            "name": "bacteria",
            "operator": "OR",
            "conditions": [
                {
                    "field": "domain",
                    "value": "Bacteria"
                }
            ]
        }
    ]


=cut

