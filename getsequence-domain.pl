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


print "config file is located at: ".$ENV{'EFICFG'}."\n";
$configfile=read_file($ENV{'EFICFG'}) or die "could not open $ENV{'EFICFG'}\n";
eval $configfile;

print "Configfile is \n > $configfile\n";

$result = GetOptions("ipro=s"               => \$ipro,
                     "pfam=s"               => \$pfam,
                     "gene3d=s"             => \$gene3d,
                     "ssf=s"                => \$ssf,
                     "accession-output=s"   => \$access,
                     "maxsequence=s"        => \$maxsequence,
                     "accession-id=s"       => \$manualAccession,
                     "accession-file=s"     => \$accessionFile,
                     "out=s"                => \$out,
                     "userfasta=s"          => \$userfasta,
                     "domain=s"             => \$domain,
                     "fraction=i"           => \$fraction,
                     "no-match-file=s"      => \$noMatchFile,
                     "config=s"             => \$configFile,
                    );

@accessions = ();
$perpass=$ENV{'EFIPASS'};
%ids = ();
%accessionhash = ();

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


my $showNoMatches = $#manualAccessions >= 0 ? 1 : 0;
my $idMapper;
if ($showNoMatches) {
    die "Config file (--config=...) option is required" unless (defined $configFile and -f $configFile);
    $idMapper = new Biocluster::IdMapping(config_file_path => $configFile);
}


print "Getting Acession Numbers in specified Families\n";



foreach $element (@ipros) {
    $sth=$dbh->prepare("select accession,start,end from INTERPRO where id = '$element'");
    $sth->execute;
    while($row = $sth->fetch) {
        push @{$accessionhash{$row->[0]}}, {'start' => $row->[1], 'end' => $row->[2]};
    }
}
@accessions=keys %accessionhash;
print "Initial ".scalar @accessions."sequences in IPR\n";

foreach $element (@pfams) {
    $sth=$dbh->prepare("select accession,start,end from PFAM where id = '$element'");
    $sth->execute;
    while($row = $sth->fetch) {
        push @{$accessionhash{$row->[0]}}, {'start' => $row->[1], 'end' => $row->[2]};
    }
}
@accessions=keys %accessionhash;
print "Initial ".scalar @accessions."sequences in PFAM\n";

foreach $element (@gene3ds) {
    $sth=$dbh->prepare("select accession,start,end from GENE3D where id = '$element'");
    $sth->execute;
    while($row = $sth->fetch) {
        push @{$accessionhash{$row->[0]}}, {'start' => $row->[1], 'end' => $row->[2]};
    }
}
@accessions=keys %accessionhash;
print "Initial ".scalar @accessions."sequences in G3D\n";

foreach $element (@ssfs) {
    $sth=$dbh->prepare("select accession,start,end from SSF where id = '$element'");
    $sth->execute;
    while($row = $sth->fetch) {
        push @{$accessionhash{$row->[0]}}, {'start' => $row->[1], 'end' => $row->[2]};
    }
}
@accessions=keys %accessionhash;
print "Initial ".scalar @accessions."sequences in SSF\n";


# Reverse map any IDs that aren't UniProt.
#TODO: need to add this in when the idmapping table is populated
#my ($uniprotIds, $noMatches) = $idMapper->reverseLookup(AUTO, @manualAccessions)
#    if $#manualAccessions >= 0;

# Write out the no matches to a file.
if (defined $noMatches and $showNoMatches) {
    open NOMATCH, "> $noMatchFile" or die "Unable to create nomatch file: $!" if (defined $noMatchFile);
    foreach my $noMatch (@$noMatches) {
        print "$noMatch\n" if not defined $noMatchFile;
        print NOMATCH "$noMatch\n" if defined $noMatchFile;
    }
    close NOMATCH if defined $noMatches;
}

# Lookup each manual accession ID to get the domain as well as verify that it exists.
foreach $element (@manualAccessions) {
    $sql = "select accession,start,end from PFAM where accession = '$element'";
    $sth=$dbh->prepare("select accession,start,end from PFAM where accession = '$element'");
    $sth->execute;
    print "SQL: $sql\n";
    while($row = $sth->fetch) {
        push @{$accessionhash{$row->[0]}}, {'start' => $row->[1], 'end' => $row->[2]};
    }
}
@accessions=keys %accessionhash;
print "Initial ".scalar @accessions."sequences in manual accessions\n";

@accessions=uniq @accessions;
print scalar @accessions." after uniquing\n";


#one more unique in case of accessions being added in multiple databases
@accessions=keys %accessionhash;

if (scalar @accessions>$maxsequence and $maxsequence != 0) {
    open ERROR, ">$access.failed" or die "cannot write error output file $access.failed\n";
    print ERROR "Number of sequences ".scalar @accessions." exceeds maximum specified $maxsequence\n";
    close ERROR;
    die "Number of sequences ".scalar @accessions." exceeds maximum specified $maxsequence\n";
}
print "Print out accessions\n";
open GREP, ">$access" or die "Could not write to $access\n";
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
open OUT, ">$out" or die "Cannot write to output fasta $out\n";
while(scalar @accessions) {
    @batch=splice(@accessions, 0, $perpass);
    $batchline=join ',', @batch;
    print "fastacmd -d $data_files/combined.fasta -s $batchline\n";
    @sequences=split /\n>/, `fastacmd -d $data_files/combined.fasta -s $batchline`;
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
            #do nothing
        } else {
            die "Domain must be either on or off\n";
        }
    }

}
close OUT;

if ($userfasta =~ /\w+/ and -s $userfasta) {
    #add user supplied fasta to the list
    system("cat $userfasta >> $out");
}

