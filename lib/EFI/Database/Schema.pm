
package EFI::Database::Schema;

use strict;


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless($self, $class);

    return undef if not exists $args{table_name};

    $self->{table_name} = $args{table_name};

    if (exists $args{indices}) {
        $self->{indices} = $args{indices};
    } else {
        $self->{indices} = [];
    }

    if (exists $args{column_defs}) {
        $self->{column_defs} = $args{column_defs};
    } else {
        $self->{column_defs} = "";
    }

    return $self;
}


sub columnDefinitions {
    my ($self, $colDefs) = @_;

    $self->{column_defs} = $colDefs;
}


sub addIndex {
    my ($self, $name, $columns) = @_;

    push(@{ $self->{indices} }, {name => $name, definition => $columns});
}


sub getCreateSql {
    my ($self) = @_;

    my @sql = ("create table " . $self->{table_name} . " (" . $self->{column_defs} . ")");
    foreach my $idx (@{ $self->{indices} }) {
        push(@sql, "create index " . $idx->{name} . " on " . $self->{table_name} . " (" . $idx->{definition} . ")");
    }

    return @sql;
}


1;


