
package Biocluster::Fasta::Headers;

use File::Basename;
use Cwd qw(abs_path);
use strict;
use lib abs_path(dirname(__FILE__)) . "/../../";
use Exporter;
use Biocluster::IdMapping;
use Biocluster::IdMapping::Util;
use Biocluster::Database;


use constant HEADER     => 1;
use constant SEQUENCE   => 2;
use constant FLUSH      => 3;

our @ISA        = qw(Exporter);
our @EXPORT     = qw();



sub new {
    my ($class, %args) = @_;

    my $self = bless {}, $class;

    die "config_file_path argument must be passed to Biocluster::Fasta::Headers." if not exists $args{config_file_path};

    $self->reset();
    $self->{id_mapper} = new Biocluster::IdMapping(config_file_path => $args{config_file_path});
    $self->{db_obj} = new Biocluster::Database(%args);

    return $self;
}


sub get_primary_id {
    my ($self) = @_;

    return defined $self->{primary_id} ? $self->{primary_id} : "";
}


sub get_fasta_header_ids {
    my ($line) = @_;

    chomp $line;
    my @ids;

    my @headers = split(m/>/, $line);
    foreach my $id (@headers) {
        next if $id =~ m/^\s*$/;
        $id =~ s/^\s*(tr|sp|pdb)\|([^\s\|]+).*$/$2/;
        $id =~ s/^(\S+)\s*.*$/$1/;
        push(@ids, $id); # if (check_id_type($id) ne UNKNOWN);
    }

    return @ids;
}


sub get_state {
    my ($self) = @_;

    my $result = { state => HEADER, ids => [], primary_id => undef };
    $result->{primary_id} = $self->{primary_id};
    $result->{ids} = $self->{ids};

    return $result;
}


sub reset {
    my ($self) = @_;

    $self->{primary_id} = undef;
    $self->{ids} = [];
    $self->{orig_primary_id} = "";
    $self->{raw_headers} = "";
}


sub parse_line_for_headers {
    my ($self, $line) = @_;

    my $result = { state => HEADER, ids => [], primary_id => undef };

    my $dbh = $self->{db_obj}->getHandle();

    # This checks the user-fasta Option C case.
    if ($line =~ m/^>z/) {
        ($self->{primary_id} = $line) =~ s/^>//;
        push(@{ $self->{cur_ids} }, $self->{primary_id});

    # Handle multiple headers on a single line.
    } elsif ($line =~ m/>/) {
        $self->{raw_headers} .= $line;
        # Iterate over each ID in the header line to check if we know anything about it.
        foreach my $id (get_fasta_header_ids($line)) {
            # Check the ID type and if it's unknown, we add it to the ID list and move on.
            my $idType = check_id_type($id);
            my $queryId = $id;
            if ($idType eq Biocluster::IdMapping::Util::UNKNOWN) {
                #push(@{ $self->{ids} }, $id);
                next;
            } elsif ($idType eq Biocluster::IdMapping::Util::UNIPROT) {
                ($queryId = $id) =~ s/\..+$//;
            }

            # Check if the ID is in the idmapping database
            my $upId = $queryId;
            if ($idType ne Biocluster::IdMapping::Util::UNIPROT) {
                my ($uniprotId, $noMatch) = $self->{id_mapper}->reverseLookup($idType, $id);
                if (defined $uniprotId and $#$uniprotId >= 0) {
                    $upId = $uniprotId->[0];
                    $idType = Biocluster::IdMapping::Util::UNIPROT;
                }
            }

            # Check if we known anything about the accession ID by querying the database.
            if (not defined $self->{primary_id} and $idType eq Biocluster::IdMapping::Util::UNIPROT) {
                my $sql = "select accession from PFAM where accession = '$upId'";
                my $sth = $dbh->prepare($sql);
                $sth->execute();

                # We need to have a primary ID so we set that here if we haven't yet.
                if ($sth->fetch) {
                    $self->{primary_id} = $upId;
                    $self->{orig_primary_id} = $queryId;
                }
                # else {
                    push(@{ $self->{ids} }, $id);
                    #}
            } else {
                push(@{ $self->{ids} }, $id);
            }
        }
    } else {
        # If the line doesn't contain a whitespace character, and we have some IDs, we assume we have just
        # finished parsing the header, so we write the header info and reset the variables.
        if ($line =~ m/\S/ and $self->{raw_headers}) { #$#{ $self->{ids} } >= 0) {
            $result->{primary_id} = $self->{primary_id};
            $result->{ids} = $self->{ids};
            $result->{orig_primary_id} = $self->{orig_primary_id};
            ($result->{raw_headers} = $self->{raw_headers}) =~ s/^\s*>(.*?)\s*$/$1/g;
            $result->{state} = FLUSH;
            # Reset for the next header
            $self->reset();
        } else {
            $result->{state} = SEQUENCE;
        }
    }

    $dbh->disconnect();

    return $result;
}


1;


