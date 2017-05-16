
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


sub reset {
    my ($self) = @_;

    $self->{other_ids} = [];
    $self->{raw_headers} = "";
    $self->{uniprot_ids} = [];
    $self->{duplicates} = {};
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
            if ($idType eq Biocluster::IdMapping::Util::UNKNOWN) {
                next;
            }

            # Check if the ID is in the idmapping database
            my $upId = $id;
            $upId =~ s/\..+$// if $idType eq Biocluster::IdMapping::Util::UNIPROT;
            if ($idType ne Biocluster::IdMapping::Util::UNIPROT) {
                my ($uniprotId, $noMatch) = $self->{id_mapper}->reverseLookup($idType, $id);
                if (defined $uniprotId and $#$uniprotId >= 0) {
                    $upId = $uniprotId->[0];
                    $idType = Biocluster::IdMapping::Util::UNIPROT;
                }
            }

            # Check if we known anything about the accession ID by querying the database.
            if ($idType eq Biocluster::IdMapping::Util::UNIPROT) {
                my $sql = "select accession from PFAM where accession = '$upId'";
                my $sth = $dbh->prepare($sql);
                $sth->execute();

                # We need to have a primary ID so we set that here if we haven't yet.
                if ($sth->fetch) {
                    if (not grep { $_->{uniprot_id} eq $upId } @{ $self->{uniprot_ids} }) {
#                        print "NEW $upId/$id\n";
                        push(@{ $self->{uniprot_ids} }, { uniprot_id => $upId, other_id => $id });
                        $self->{duplicates}->{$upId} = [];
                    } elsif (not grep { $_->{other_id} eq $id } @{ $self->{uniprot_ids} }) {
#                        print "DUP $upId/$id\n";
                        push(@{ $self->{duplicates}->{$upId} }, $id) if not grep { $_ eq $id } @{ $self->{duplicates}->{$upId} };
                    }
                } else {
                    push(@{ $self->{other_ids} }, $id);
                }
            } else {
                push(@{ $self->{other_ids} }, $id);
            }
        }
    } else {
        # If the line doesn't contain a whitespace character, and we have some IDs, we assume we have just
        # finished parsing the header, so we write the header info and reset the variables.
        if ($line =~ m/\S/ and $self->{raw_headers}) { #$#{ $self->{other_ids} } >= 0) {
            $result->{other_ids} = $self->{other_ids};
            ($result->{raw_headers} = $self->{raw_headers}) =~ s/^\s*>(.*?)\s*$/$1/g;
            $result->{raw_headers} =~ s/[\n\r\t]+/ /g;
            $result->{state} = FLUSH;
            $result->{uniprot_ids} = $self->{uniprot_ids};
            $result->{duplicates} = $self->{duplicates};
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


