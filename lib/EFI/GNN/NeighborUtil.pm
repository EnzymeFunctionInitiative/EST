
package EFI::GNN::NeighborUtil;

use List::MoreUtils qw{uniq};
use Array::Utils qw(:all);
use Data::Dumper;
use Time::HiRes qw(time);


sub new {
    my ($class, %args) = @_;

    $self->{dbh} = $args{dbh};
    $self->{use_new_neighbor_method} = exists $args{use_nnm} ? $args{use_nnm} : 1;
    $self->{anno} = $args{efi_anno};
    
    return bless($self, $class);
}


sub parseInterpro {
    my $self = shift;
    my $row = shift;

    return if not exists $row->{ipro_fam};

    my @fams = split m/,/, $row->{ipro_fam};
    my @types = split m/,/, $row->{ipro_type};

    my @info;
    my %u;

    for (my $i = 0; $i < scalar @fams; $i++) {
        next if exists $u{$fams[$i]};
        $u{$fams[$i]} = 1;
        my $info = {family => $fams[$i], type => lc($types[$i])};
        #TODO: remove hardcoded constants here
        if ($info->{type} eq "domain" or $info->{type} eq "family" or $info->{type} eq "homologous_superfamily") {
            push @info, $info;
        }
    }

    return @info;
}


sub printTime {
    my ($t1, $name) = @_;
    $name = $name // "t";
    printf("$name=%.6f s\n", (time - $t1));
    return time;
}

sub findNeighbors {
    my $self = shift;
    my $ac = shift;
    my $neighborhoodSize = shift;
    my $warning_fh = shift;
    my $testForCirc = shift;
    my $noneFamily = shift;
    my $accessionData = shift;

    my $debug = 0;

    my $genomeId = "";
    my $noNeighbors = 0;
    my %pfam;
    my %ipro;
    my $numqable = 0;
    my $numneighbors = 0;

    if (not $self->{dbh}->ping()) {
        warn "Database disconnected at " . scalar localtime;
        $self->{dbh} = $self->{dbh}->clone() or die "Cannot reconnect to database.";
    }

    my $isCircSql = "select * from ena where AC='$ac' order by TYPE limit 1";
    $sth = $self->{dbh}->prepare($isCircSql);
    $sth->execute;

#    my $t1 = time;

    my $row = $sth->fetchrow_hashref;
    if (not defined $row or not $row) {
        print $warning_fh "$ac\tnomatch\n" if $warning_fh;
        return \%pfam, \%ipro, 1, -1, $genomeId;
    }

    $genomeId = $row->{ID};

    if ($self->{use_new_neighbor_method}) {
        # If the sequence is a part of any circular genome(s), then we check which genome, if their are multiple
        # genomes, has the most genes and use that one.
        if ($row->{TYPE} == 0) {
            my $sql = "select *, max(NUM) as MAX_NUM from ena where ID in (select ID from ena where AC='$ac' and TYPE=0 order by ID) group by ID order by TYPE, MAX_NUM desc limit 1";
            my $sth = $self->{dbh}->prepare($sql);
            $sth->execute;
            my $frow = $sth->fetchrow_hashref;
            if (not defined $frow or not $frow) {
                die "Unable to execute query $sql";
            }
            $genomeId = $frow->{ID};
        } else {
            my $sql = <<SQL;
select
        ena.ID,
        ena.AC,
        ena.NUM,
        ABS(ena.NUM / max_table.MAX_NUM - 0.5) as PCT,
        (ena.NUM < max_table.MAX_NUM - 10) as RRR,
        (ena.NUM > 10) as LLL
    from ena
    inner join
        (
            select *, max(NUM) as MAX_NUM from ena where ID in
            (
                select ID from ena where AC='$ac' and TYPE=1 order by ID
            )
        ) as max_table
    where
        ena.AC = '$ac'
    order by
        LLL desc,
        RRR desc,
        PCT
    limit 1
SQL
            ;
            my $sth = $self->{dbh}->prepare($sql);
            $sth->execute;
            my $row = $sth->fetchrow_hashref;
            $genomeId = $row->{ID};
            if ($debug) {
                do {
                    print join("\t", $row->{ID}, $row->{AC}, $row->{NUM}, $row->{LLL}, $row->{RRR}, $row->{PCT}), "\n";
                } while ($row = $sth->fetchrow_hashref);
            }
        }
    }

#    $t1 = printTime($t1, "t1");

    print "Using $genomeId as genome ID\n"                                              if $debug;

    my $colSql = join(", ", 
            "ena.ID as ID", "ena.AC as AC", "ena.NUM as NUM", "ena.TYPE as TYPE", "ena.DIRECTION as DIRECTION", "ena.start as start", "ena.stop as stop",
            "annotations.metadata as metadata",
            "group_concat(PFAM.id) as pfam_fam",
            "group_concat(I.id) as ipro_fam",
            "group_concat(I.family_type) as ipro_type",
            #"group_concat(I.parent) as ipro_parent", "group_concat(I.is_leaf) as ipro_is_leaf"
        );
    my $joinSql = join(" ",
            "left join annotations on ena.AC = annotations.accession",
            "left join PFAM on ena.AC = PFAM.accession",
            "left join INTERPRO as I on ena.AC = I.accession",
        );

    my $selSql = "select $colSql from ena $joinSql where ena.ID = '$genomeId' and AC = '$ac' group by ena.AC limit 1;";
    $sth=$self->{dbh}->prepare($selSql);
    $sth->execute;

    $row = $sth->fetchrow_hashref;
    if($row->{DIRECTION}==0){
        $origdirection='complement';
    }elsif($row->{DIRECTION}==1){
        $origdirection='normal';
    }else{
        die "Direction of ".$row->{AC}." does not appear to be normal (0) or complement(1)\n";
    }
    my $queryPfam = join('-', sort {$a <=> $b} uniq split(",",$row->{pfam_fam}));
    my @ipInfo = $self->parseInterpro($row);
    my $queryIpro = join('-', map { $_->{family} } @ipInfo);

    my $num = $row->{NUM};
    my $id = $row->{ID};
    my $acc_start = int($row->{start});
    my $acc_stop = int($row->{stop});
    my $acc_seq_len = int(abs($acc_stop - $acc_start) / 3 - 1);
    print "WARNING: missing metadata for $row->{AC}; is entry obsolete? [N]\n" if not $row->{metadata};
    my $md = $self->{anno}->decode_meta_struct($row->{metadata});
    my $acc_strain = $md->{strain} // "";
    
    $low=$num-$neighborhoodSize;
    $high=$num+$neighborhoodSize;
    my $acc_type = $row->{TYPE} == 1 ? "linear" : "circular";

    $query="select $colSql from ena $joinSql where ena.ID = '$id' ";
    my $clause = "and ena.num >= $low and ena.num <= $high";

    # Handle circular case
    my ($max, $circHigh, $circLow, $maxCoord);
    my $maxQuery = "select NUM,stop from ena where ID = '$id' order by NUM desc limit 1";
    my $maxSth = $self->{dbh}->prepare($maxQuery);
    $maxSth->execute;
    my $maxRow = $maxSth->fetchrow_hashref;
    $max = $maxRow->{NUM};
    $maxCoord = $maxRow->{stop};

    if (defined $testForCirc and $testForCirc and $acc_type eq "circular") {
        if ($neighborhoodSize < $max) {
            my @maxClause;
            if ($low < 1) {
                $circHigh = $max + $low;
                push(@maxClause, "num >= $circHigh");
            }
            if ($high > $max) {
                $circLow = $high - $max;
                push(@maxClause, "num <= $circLow");
            }
            my $subClause = join(" or ", @maxClause);
            $subClause = "or " . $subClause if $subClause;
            $clause = "and ((num >= $low and num <= $high) $subClause)";
        }
    }
#    $t1 = printTime($t1, "t2");

    $query .= $clause . " group by ena.AC order by NUM";

    my $neighbors = $self->{dbh}->prepare($query);
    $neighbors->execute;

    if ($neighbors->rows > 1) {
        $noNeighbors = 0;
        push @{$pfam{'withneighbors'}{$queryPfam}}, $ac;
        push @{$ipro{'withneighbors'}{$queryIpro}}, $ac;
    } else {
        $noNeighbors = 1;
        print "WARNING $ac $id\n";
        print $warning_fh "$ac\tnoneighbor\n" if $warning_fh;
    }

    my $isBound = ($low < 1 ? 1 : 0);
    $isBound = $isBound | ($high > $max ? 2 : 0);

    $pfam{'genome'}{$ac} = $id;
    $ipro{'genome'}{$ac} = $id;
    $accessionData->{attributes} = {accession => $ac, num => $num, family => $queryPfam, id => $id,
       start => $acc_start, stop => $acc_stop, rel_start => 0, rel_stop => $acc_stop - $acc_start, 
       strain => $acc_strain, direction => $origdirection, is_bound => $isBound,
       type => $acc_type, seq_len => $acc_seq_len, ipro_family => $queryIpro, ipro_info => \@ipInfo};

    while(my $neighbor=$neighbors->fetchrow_hashref){
#        $t1 = time;
        my $pfamFam = join('-', sort {$a <=> $b} uniq split(",",$neighbor->{pfam_fam}));
        @ipInfo = $self->parseInterpro($neighbor);
        my $iproFam = join('-', map { $_->{family} } @ipInfo);
        if ($pfamFam eq '') {
            $pfamFam = 'none';
            $noneFamily->{$neighbor->{AC}} = 1;
        }
        $iproFam = 'none' if not $iproFam;
        push @{$pfam{'orig'}{$pfamFam}}, $ac;
        push @{$ipro{'orig'}{$iproFam}}, $ac;

        my $nbStart = int($neighbor->{start});
        my $nbStop = int($neighbor->{stop});
        my $nbSeqLen = abs($neighbor->{stop} - $neighbor->{start});
        my $nbSeqLenBp = int($nbSeqLen / 3 - 1);

        my $relNbStart;
        my $relNbStop;
        my $neighNum = $neighbor->{NUM};
        if ($neighNum > $high and defined $circHigh and defined $max) {
            $distance = $neighNum - $num - $max;
            $relNbStart = $nbStart - $maxCoord;
        } elsif ($neighNum < $low and defined $circLow and defined $max) {
            $distance = $neighNum - $num + $max;
            $relNbStart = $maxCoord + $nbStart;
        } else {
            $distance = $neighNum - $num;
            $relNbStart = $nbStart;
        }
        $relNbStart = int($relNbStart - $acc_start);
        $relNbStop = int($relNbStart + $nbSeqLen);

        print join("\t", $ac, $neighbor->{AC}, $neighbor->{NUM}, $neighbor->{pfam_fam}, $neighNum, $num, $distance), "\n"               if $debug;

        unless($distance==0){
            my $type;
            if($neighbor->{TYPE}==1){
                $type='linear';
            }elsif($neighbor->{TYPE}==0){
                $type='circular';
            }else{
                die "Type of ".$neighbor->{AC}." does not appear to be circular (0) or linear(1)\n";
            }
            if($neighbor->{DIRECTION}==0){
                $direction='complement';
            }elsif($neighbor->{DIRECTION}==1){
                $direction='normal';
            }else{
                die "Direction of ".$neighbor->{AC}." does not appear to be normal (1) or complement(0)\n";
            }

            push @{$accessionData->{neighbors}}, {accession => $neighbor->{AC}, num => int($neighbor->{NUM}),
                family => $pfamFam, id => $neighbor->{ID}, distance => $distance, # include distance here in addition to num, because the num is hard to compute in rare circular DNA cases
                rel_start => $relNbStart, rel_stop => $relNbStop, start => $nbStart, stop => $nbStop,
                #strain => $neighbor->{strain},
                direction => $direction, type => $type, seq_len => $nbSeqLenBp, ipro_family => $iproFam, ipro_info => \@ipInfo};
            push @{$pfam{'neigh'}{$pfamFam}}, "$ac:".$neighbor->{AC};
            push @{$pfam{'neighlist'}{$pfamFam}}, $neighbor->{AC};
            push @{$pfam{'dist'}{$pfamFam}}, "$ac:$origdirection:".$neighbor->{AC}.":$direction:$distance";
            push @{$pfam{'stats'}{$pfamFam}}, abs $distance;
            push @{$pfam{'data'}{$pfamFam}}, { query_id => $ac,
                                           neighbor_id => $neighbor->{AC},
                                           distance => (abs $distance),
                                           direction => "$origdirection-$direction"
                                         };
            push @{$ipro{'neigh'}{$iproFam}}, "$ac:".$neighbor->{AC};
            push @{$ipro{'neighlist'}{$iproFam}}, $neighbor->{AC};
            push @{$ipro{'dist'}{$iproFam}}, "$ac:$origdirection:".$neighbor->{AC}.":$direction:$distance";
            push @{$ipro{'stats'}{$iproFam}}, abs $distance;
            push @{$ipro{'data'}{$iproFam}}, { query_id => $ac,
                                           neighbor_id => $neighbor->{AC},
                                           distance => (abs $distance),
                                           direction => "$origdirection-$direction"
                                         };
        }
#        $t1 = printTime($t1, "t3");
    }

    foreach my $key (keys %{$pfam{'orig'}}){
        @{$pfam{'orig'}{$key}}=uniq @{$pfam{'orig'}{$key}};
    }
    foreach my $key (keys %{$ipro{'orig'}}){
        @{$ipro{'orig'}{$key}}=uniq @{$ipro{'orig'}{$key}};
    }

    return \%pfam, \%ipro, 0, $noNeighbors, $genomeId;
}

1;

