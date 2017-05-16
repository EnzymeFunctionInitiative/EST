#!/usr/bin/env perl


#version 0.9.0 moved from getting accesions by grepping files to using sqlite database
#version 0.9.0 options of specifing ssf and gene3d numbers added
#version 0.9.2 modified to accept 6-10 characters as accession ids
#version 0.9.3 modified to use cfg file to load location of variables for database
#version 0.9.4 change way cfg file used to load database location

use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;
use DBD::SQLite;
use DBD::mysql;
use File::Slurp;
use FindBin;
use lib "$FindBin::Bin/lib";
use Biocluster::IdMapping;
use Biocluster::Config;
use Biocluster::IdMapping::Util;
use Biocluster::Fasta::Headers;
use Biocluster::Database;


#print "config file is located at: ".$ENV{'EFICFG'}."\n";
#$configfile=read_file($ENV{'EFICFG'}) or die "could not open $ENV{'EFICFG'}\n";
#eval $configfile;
#
#print "Configfile is \n > $configfile\n";

my ($ipro, $pfam, $gene3d, $ssf, $access, $maxsequence, $manualAccession, $accessionFile, $fastaFileOut, $fastaFileIn, $metaFileOut, $useFastaHeaders, $domain, $fraction, $noMatchFile, $configFile);
my $result = GetOptions(
    "ipro=s"               => \$ipro,
    "pfam=s"               => \$pfam,
    "gene3d=s"             => \$gene3d,
    "ssf=s"                => \$ssf,
    "accession-output=s"   => \$access,
    "maxsequence=s"        => \$maxsequence,
    "accession-id=s"       => \$manualAccession,
    "accession-file=s"     => \$accessionFile,
    "out=s"                => \$fastaFileOut,
    "fasta-file=s"         => \$fastaFileIn,
    "meta-file=s"          => \$metaFileOut,
    "use-fasta-headers"    => \$useFastaHeaders,
    "domain=s"             => \$domain,
    "fraction=i"           => \$fraction,
    "no-match-file=s"      => \$noMatchFile,
    "config=s"             => \$configFile,
);

die "Command-line arguments are not valid: missing -config=config_file_path argument" if not defined $configFile or not -f $configFile;
die "Environment variables not set properly: missing EFIDB variable" if not exists $ENV{EFIDB};

my @accessions = ();
my $perpass = $ENV{EFIPASS};
my $data_files = $ENV{EFIDBPATH};
my %ids = ();
my %accessionhash = ();

if (defined $domain) {
    unless($domain eq "off" or $domain eq "on") {
        die "domain value must be either on or off\n";
    }
} else {
    $domain="off";
}

if (defined $fraction) {
    unless($fraction =~ /^\d+$/ and $fraction >0) {
        die "if fraction is defined, it must be greater than zero\n";
    }
} else {
    $fraction=1;
}

if (defined $ipro and $ipro ne 0) {
    print ":$ipro:\n";
    @ipros=split /,/, $ipro;
} else {
    @ipros = ();
}

if (defined $pfam and $pfam ne 0) {
    print ":$pfam:\n";
    @pfams=split /,/, $pfam;
} else {
    @pfams = ();
}

if (defined $gene3d and $gene3d ne 0) {
    print ":$gene3d:\n";
    @gene3ds=split /,/, $gene3d;
} else {
    @gene3ds = ();
}

if (defined $ssf and $ssf ne 0) {
    print ":$ssf:\n";
    @ssfs=split /,/, $ssf;
} else {
    @ssfs = ();
}

if (defined $manualAccession and $manualAccession ne 0) {
    print ":manual $manualAccession:\n";
    @manualAccessions = split m/,/, $manualAccession;
} else {
    @manualAccessions = ();
}

if (defined $accessionFile and -f $accessionFile) {
    print ":accessionFile $accessionFile:\n";
    push(@manualAccessions, grep m/.+/, map { $_ =~ s/[\s\r\n]//g; split(",", $_) } read_file($accessionFile));
}


unless(defined $maxsequence) {
    $maxsequence=0;
}

die "Config file (--config=...) option is required" unless (defined $configFile and -f $configFile);
my $db = new Biocluster::Database(config_file_path => $configFile);

my $idMapper;
if ($#manualAccessions >= 0) {
    $idMapper = new Biocluster::IdMapping(config_file_path => $configFile);
}


print "Getting Acession Numbers in specified Families\n";

my $dbh = $db->getHandle();


#######################################################################################################################
# GETTING ACCESSIONS FROM INTERPRO FAMILY(S)
#
foreach $element (@ipros) {
    $sth = $dbh->prepare("select accession,start,end from INTERPRO where id = '$element'");
    $sth->execute;
    while($row = $sth->fetch) {
        push @{$accessionhash{$row->[0]}}, {'start' => $row->[1], 'end' => $row->[2]};
    }
}
@accessions=keys %accessionhash;
print "Initial " . scalar @accessions . " sequences after INTERPRO\n";


#######################################################################################################################
# GETTING ACCESSIONS FROM PFAM FAMILY(S)
#
foreach $element (@pfams) {
    $sth = $dbh->prepare("select accession,start,end from PFAM where id = '$element'");
    $sth->execute;
    while($row = $sth->fetch) {
        push @{$accessionhash{$row->[0]}}, {'start' => $row->[1], 'end' => $row->[2]};
    }
}
@accessions=keys %accessionhash;
print "Initial " . scalar @accessions . " sequences after PFAM\n";


#######################################################################################################################
# GETTING ACCESSIONS FROM GENE3D FAMILY(S)
#
foreach $element (@gene3ds) {
    $sth = $dbh->prepare("select accession,start,end from GENE3D where id = '$element'");
    $sth->execute;
    while($row = $sth->fetch) {
        push @{$accessionhash{$row->[0]}}, {'start' => $row->[1], 'end' => $row->[2]};
    }
}
@accessions=keys %accessionhash;
print "Initial " . scalar @accessions . " sequences after G3D\n";

#######################################################################################################################
# GETTING ACCESSIONS FROM SSF FAMILY(S)
#
foreach $element (@ssfs) {
    $sth = $dbh->prepare("select accession,start,end from SSF where id = '$element'");
    $sth->execute;
    while($row = $sth->fetch) {
        push @{$accessionhash{$row->[0]}}, {'start' => $row->[1], 'end' => $row->[2]};
    }
}
@accessions=keys %accessionhash;
print "Initial " . scalar @accessions . " sequences after SSF\n";


#######################################################################################################################
# PARSE FASTA FILE FOR HEADER IDS (IF ANY)
#
my @fastaUniprotIds;
if ($fastaFileIn =~ /\w+/ and -s $fastaFileIn) {
    $useFastaHeaders = defined $useFastaHeaders ? 1 : 0;
    # Returns the Uniprot IDs that were found in the file.  If there were sequences found that didn't map
    # to a Uniprot ID, they are written to the output FASTA file directly.  The sequences that corresponded
    # to a Uniprot ID are not written, they are retrieved from the sequences below.
    @fastaUniprotIds = parseFastaHeaders($fastaFileIn, $fastaFileOut, $metaFileOut, $useFastaHeaders, $idMapper, $configFile);
    print "The uniprotIds that were found in the FASTA file:\n", "\t", join("\n\t", @fastaUniprotIds), "\n";
}

#######################################################################################################################
# ADDING MANUAL ACCESSION IDS FROM FILE OR ARGUMENT
#
# Reverse map any IDs that aren't UniProt.
my $uniprotIds = [];
my $noMatches = [];
my $uniprotRevMap = {};
if ($#manualAccessions >= 0) { 
    ($uniprotIds, $noMatches, $uniprotRevMap) = $idMapper->reverseLookup(Biocluster::IdMapping::Util::AUTO, @manualAccessions);
}

#print "There were ", scalar(@manualAccessions), " input ids, ", scalar(@$uniprotIds), " mapped ids, ", scalar(uniq(@$uniprotIds)), " unique mapped ids, and ", scalar(@$noMatches), " unmatched ids.\n";

my $showNoMatches = $#manualAccessions >= 0 ? 1 : 0 and defined $noMatchFile;
# Write out the no matches to a file.
if ($showNoMatches) {
    open NOMATCH, ">$noMatchFile" or die "Unable to create nomatch file '$noMatchFile': $!";
    foreach my $noMatch (@$noMatches) {
        print NOMATCH "$noMatch\tNOT_FOUND_IDMAPPING\n";
    }
}


my %inDb;
# Lookup each manual accession ID to get the domain as well as verify that it exists.
foreach $element (@$uniprotIds, @fastaUniprotIds) {
    $sql = "select accession,start,end from PFAM where accession = '$element'";
    $sth = $dbh->prepare("select accession,start,end from PFAM where accession = '$element'");
    $sth->execute;
    if ($row = $sth->fetch) {
        print NOMATCH "$element\tDUPLICATE\n" if exists $accessionhash{$row->[0]} and $showNoMatches;
        push @{$accessionhash{$row->[0]}}, {'start' => $row->[1], 'end' => $row->[2]};
        $inDb{$element} = 1;
    } else {
        print NOMATCH "$element\tNOT_FOUND_DATABASE\n" if $showNoMatches;
    }
}

$sth->finish if $sth;

close NOMATCH if $showNoMatches;

# Now write out the IDs that were included in the input file that mapped back to a Uniprot ID.
if ($#manualAccessions >= 0) { 
    open META, "> $metaFileOut";
    foreach my $id (sort keys %inDb) {
        print META "$id\n";
        print META "\tQuery_IDs\t", join(",", uniq @{ $uniprotRevMap->{$id} }), "\n";
    }
    close META;
}

@accessions=keys %accessionhash;
print "Initial " . scalar @accessions . " sequences after manual accessions\n";

$dbh->disconnect();


#one more unique in case of accessions being added in multiple databases
@accessions=keys %accessionhash;
print scalar @accessions . " total accessions\n";
@accessions=uniq @accessions;
print scalar @accessions . " after uniquing\n";


if (scalar @accessions>$maxsequence and $maxsequence != 0) {
    open ERROR, ">$access.failed" or die "cannot write error output file $access.failed\n";
    print ERROR "Number of sequences ".scalar @accessions." exceeds maximum specified $maxsequence\n";
    close ERROR;
    die "Number of sequences ".scalar @accessions." exceeds maximum specified $maxsequence";
}
print "Print out accessions\n";
open GREP, ">$access" or die "Could not write to output accession ID file '$access': $!";
foreach $accession (keys %accessionhash) {
    my @domains = @{$accessionhash{$accession}};
    foreach $piece (@domains) {
        if ($domain eq "off") {
            print GREP "$accession\n";
        } elsif ($domain eq "on") {
            print GREP "$accession:${$piece}{'start'}:${$piece}{'end'}\n"
        } else {
            die "domain must be set to either on or off\n";
        }
    }
}
close GREP;


print "there are ".scalar @accessions." accessions before removing fractions\n";

if ($fraction>1) {
    print "removing all but one of $fraction accessions\n";
    my $modcount=1;
    my @modaccessions = ();
    foreach my $accession (@accessions) {
        if (($modcount%$fraction) == 0) {
            #print "keeping $modcount\n";
            push @modaccessions, $accession;
        }
        $modcount++;
    }
    @accessions = @modaccessions;
    print "There are ".scalar @accessions." after keeping one of $fraction\n";
}
print "Final accession count ".scalar @accessions."\n";
print "Grab Sequences\n";

use Capture::Tiny ':all';
my @err;

if ($fastaFileIn =~ /\w+/ and -s $fastaFileIn) {
    open OUT, ">>$fastaFileOut" or die "Cannot write to output fasta $fastaFileOut\n";
} else {
    open OUT, ">$fastaFileOut" or die "Cannot write to output fasta $fastaFileOut\n";
}

while(scalar @accessions) {
    @batch=splice(@accessions, 0, $perpass);
    $batchline=join ',', @batch;
    my ($fastacmdOutput, $fastaErr) = capture {
        system("fastacmd", "-d", "${data_files}/combined.fasta", "-s", "$batchline");
    };
    push(@err, $fastaErr);
    #print "fastacmd -d $data_files/combined.fasta -s $batchline\n"; #[[[$fastacmdOutput]]]\n";
    @sequences=split /\n>/, $fastacmdOutput;
    $sequences[0] = substr($sequences[0], 1) if $#sequences >= 0 and substr($sequences[0], 0, 1) eq ">";
    foreach $sequence (@sequences) { 
        print "raw $sequence\n";
        if ($sequence =~ s/^\w\w\|(\w{6,10})\|.*//) {
            $accession=$1;
        } else {
            $accession="";
        }
        if ($domain eq "off" and $accession ne "") {
            print OUT ">$accession$sequence\n";
            #print "accession: $accession\n > $sequence\n";
        } elsif ($domain eq "on" and $accession ne "") {
            $sequence =~ s/\s+//g;
            my @domains = @{$accessionhash{$accession}};
            #print "accession $accession has ".scalar(@domains)." domains\n";
            foreach my $piece (@domains) {
                my $thissequence=join("\n", unpack("(A80)*", substr $sequence,${$piece}{'start'}-1,${$piece}{'end'}-${$piece}{'start'}+1));
                print OUT ">$accession:${$piece}{'start'}:${$piece}{'end'}\n$thissequence\n";
                #print "$accession:${$piece}{'start'}:${$piece}{'end'}\t".length substr $sequence,${$piece}{'start'}-1,(${$piece}{'end'}-${$piece}{'start'}+1)."\n";
                #print "\n";
            }
        } elsif ($accession eq "") {
            print "HELP\n";
            #do nothing
        } else {
            die "Domain must be either on or off\n";
        }
    }

}
close OUT;

foreach my $err (@err) {
    my @lines = split(m/[\r\n]+/, $err);
    foreach my $line (@lines) {
        if ($line =~ s/^\[fastacmd\]\s+ERROR:\s+Entry\s+"([^"]+)"\s+not\s+found\s*$/$1/) {
            print NOMATCH "$line\tFASTACMD\n" if $showNoMatches;
        } else {
            print STDERR $line, "\n";
        }
    }
}

close NOMATCH if $showNoMatches;






















sub parseFastaHeaders {
    my ($fastaFileIn, $fastaFileOut, $metadataFile, $useFastaHeaders, $idMapper, $configFile) = @_;

    my $parser = new Biocluster::Fasta::Headers(config_file_path => $configFile);

    open INFASTA, $fastaFileIn;
    open META, ">$metadataFile" or die "Unable to open user fasta ID file '$metadataFile' for writing: $!";
    open FASTAOUT, ">$fastaFileOut";

    my $lastId = "";
    my $id;
    my $seqLength = 0;
    my $seqCount = 0;
    while (my $line = <INFASTA>) {
        #$line =~ s/^\s*(.*?)\s*$/$1/;
        $line =~ s/[\r\n]+$//;

        my $headerLine = 0;
        my $writeSeq = 0;

        # Option E
        if ($useFastaHeaders) {
            my $result = $parser->parse_line_for_headers($line);

            # When we get here we are at the end of the headers and have started reading a sequence.
            if ($result->{state} eq Biocluster::Fasta::Headers::FLUSH) {
                # Here we save the first Uniprot ID (reversed-mapped if necessary from above) that was found in the
                # header list to the FASTA file so that it can be used later in the process.

                # $id is written to the file at the bottom of the while loop.
                #
                # The primary ID is the first Uniprot ID that was found. If there were no primary IDs found,
                # we treat the sequence like Option C and assign an internal zzz sequence ID, and save the
                # header(s) as the description. If a primary ID was found, then save the original unmapped
                # ID that was in the file (for example the NCBI ID that mapped to the Uniprot ID we are using.

                my $ss = {};
                if (not scalar @{ $result->{uniprot_ids} }) {
                    $id = makeSequenceId($seqCount);
                    $ss->{description} = substr($result->{raw_headers}, 0, 200);
                    $ss->{query_id} = "";
                } else {
                    my $primaryId = ${$result->{uniprot_ids}}[0];
                    $id = $primaryId->{uniprot_id};
                    print "Merging sequence for $id\n" if exists $seq{$id};
                    if (exists $seq{$id}) {
                        $ss = $seq{$id};
                        $ss->{num_seq_merged} = exists $ss->{num_seq_merged} ? $ss->{num_seq_merged} + 1 : 2;
                    }
                    $ss->{query_id} = $primaryId->{other_id}; #$result->{primary_id}->{other_id};
                }
                push(@{ $ss->{uniprot_ids} }, grep { $_->{uniprot_id} ne $id } @{ $result->{uniprot_ids} } );
                push(@{ $ss->{duplicates} }, $result->{duplicates});
                #$ss->{uniprot_ids} = [ grep { $_->{uniprot_id} ne $id } @{ $result->{uniprot_ids} } ];
                #$ss->{duplicates} = $result->{duplicates};
                
                # Any other IDs (either Uniprot or non-Uniprot) that were found in the header(s) are saved
                # to the metadata file here.
                $ss->{other_ids} = $result->{other_ids};
            
                # Ensure that the first line of the sequence is written to the file.
                $writeSeq = 1;
                $seqCount++;
                $headerLine = 1;

                $seq{$id} = $ss;
                #push(@{ $seq{$id} }, $ss);

            # Here we have encountered a sequence line.
            } elsif ($result->{state} eq Biocluster::Fasta::Headers::SEQUENCE) {
                $writeSeq = 1;
            }
        # Option C
        } else {
            # Custom header for Option C
            if ($line =~ s/^>//) {
                # $id is written to the file at the bottom of the while loop.
                $id = makeSequenceId($seqCount);
                my $ss = exists $seq{$id} ? $seq{$id} : {};
                
                $ss->{description} = $line;

                $seqCount++;
                #$writeSeq = 1;
                $headerLine = 1;

                $seq{$id} = $ss;
                #push(@{ $seq{$id} }, $ss);
            } elsif ($line =~ /\S/) {
                $writeSeq = 1;
            }
        }

        if ($writeSeq) {
            #my $ss = @{ $seq{$id} }[-1];
            my $ss = $seq{$id};
            if (not exists $ss->{seq}) {
                $ss->{seq} = $line . "\n";
            } else {
                $ss->{seq} .= $line . "\n";
            }
            $seqLength += length($line);
        }

        if ($headerLine) {
            if ($lastId) {
                #my $ss = @{ $seq{$id} }[-1];
                my $ss = $seq{$lastId};
                $ss->{seq_length} = $seqLength    if $lastId =~ /^z/;
                $ss->{src} = Biocluster::Config::FIELD_SEQ_SRC_VALUE_FASTA;
            }
            $seqLength = 0;
            $lastId = $id;
        }
    }

    $seq{$id}->{seq_length} = $seqLength    if $id =~ /^z/;
    $seq{$id}->{src} = Biocluster::Config::FIELD_SEQ_SRC_VALUE_FASTA;

    foreach my $id (sort sortFn keys %seq) {
        #foreach my $ss (@{ $seq{$id} }) {
        #    writeSeqData($id, $ss, \*FASTAOUT, \*META);
        #}
        print "Expanding sequence for ", join(", ", @{ $seq{$id}->{uniprot_ids} }), "\n" if scalar @{ $seq{$id}->{uniprot_ids} };
        writeSeqData($id, $seq{$id}, \*FASTAOUT, \*META);
    }

    close FASTAOUT;
    close META;
    close INFASTA;

    return sort sortFn grep !/^z/, keys %seq;
}


sub sortFn {
    (my $aa = $a) =~ s/\D//g;
    (my $bb = $b) =~ s/\D//g;

    return $aa <=> $bb;
}


sub writeSeqData {
    my ($id, $seq, $ffh, $mfh) = @_;

    my $firstOne = 1;
    foreach my $upId ({ uniprot_id => $id, other_id => $seq->{query_id} }, @{ $seq->{uniprot_ids} }) {
        # Only write out sequences that do not have a Uniprot ID, instead we retrieve them from the database rather
        # than use them from the FASTA file.
        if ($upId->{uniprot_id} =~ /^z/) {
            print $ffh ">" . $upId->{uniprot_id} . "\n";
            print $ffh $seq->{seq};
            print $ffh "\n";
        }
        
        my @queryIds = ();
        push(@queryIds, $upId->{other_id})                                                      if $upId->{uniprot_id} !~ /^z/;
        push(@queryIds, @{ $seq->{duplicates}->{$upId->{uniprot_id}} })                         if exists $seq->{duplicates}->{$upId->{uniprot_id}};
    
        print $mfh $upId->{uniprot_id} . "\n";
        print $mfh "\tDescription\t" . $seq->{description} . "\n"                               if $seq->{description};
        print $mfh "\tSequence_Length\t" . $seq->{seq_length} . "\n"                            if exists $seq->{seq_length};
        print $mfh "\t" . Biocluster::Config::FIELD_SEQ_SRC_KEY . "\t" . $seq->{src} . "\n"     if exists $seq->{src};
        print $mfh "\tOther_IDs\t" . join(",", @{ $seq->{other_ids} }) . "\n"                   if exists $seq->{other_ids};
        print $mfh "\tQuery_IDs\t" . join(",", @queryIds) . "\n"                                if scalar @queryIds;
        print $mfh "\tNum_Seq_Merged\t" . $seq->{num_seq_merged} . "\n"                         if exists $seq->{num_seq_merged};

        $firstOne = 0;
    }
}


sub makeSequenceId {
    my ($seqCount) = @_;
    my $id = sprintf("%6d", $seqCount);
    $id =~ tr/ /z/;
    return $id;
}


