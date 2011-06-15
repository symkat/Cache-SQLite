package Cache::SQLite;
use warnings;
use strict;
use DBI;
use Data::Dumper;

our $VERSION = '0.001000'; # 0.1.0
$VERSION = eval $VERSION;

my $timer = time();
my %hit;

sub new {
    my ( $class ) = @_;
    my $self = {};
    bless $self, $class;
    $self->connection(
        DBI->connect( "dbi:SQLite:dbname=:memory:", "", "" )
    );
    $self->_make_table();
    $self->sth("set", "INSERT into cache ( key, value, expires ) VALUES( ?, ?, ? )" );
    $self->sth("get", "SELECT * FROM cache WHERE key = ? LIMIT 1");
    $self->sth("purge", "DELETE FROM cache WHERE key = ?" );
    $self->sth("purge_expired", "DELETE FROM cache where expires <= ? AND expires != 0");
    $self->sth("purge_limit", "SELECT * from cache ORDER BY hit DESC LIMIT 1000 OFFSET ?");
    $self->sth("hit", "UPDATE cache SET hit = hit + 1 WHERE key = ?");
    $self->sth("exists", "SELECT key FROM cache WHERE key = ? LIMIT 1");

    return $self;
}

sub cache_limit {
    10;
}

sub work_lapse {
    600; # Every 10 minutes.
}

sub connection {
    my $self = shift;
    $self->{_connection} = shift if @_;
    return $self->{_connection};
}

sub sth {
  my ($self, $key, $value) = @_;

  $self->{_sth}{$key} = $self->connection->prepare($value) if ($value);
  return $self->{_sth}{$key};
}

sub _make_table {
    my ( $self ) = @_;
    my $sql = qq/
        CREATE TABLE cache ( 
            key text UNIQUE, 
            value text, 
            expires int, 
            hit int, 
            hit_count int )
    /;
    $self->connection->do( $sql );
}

sub set {
    my ( $self, $key, $value, $expires ) = @_;
    my $sth = $self->sth("set");
    $sth->execute( $key, $value, $expires || 0 );
    return $self;
}

sub get {
    my ( $self, $key ) = @_;

    if ( $timer >= time() + $self->work_lapse ) {
        $self->purge_over_limit;
        $self->purge_expired; 
    }

    my $sth = $self->sth("get");
    $sth->execute( $key );
    my $row = $sth->fetchrow_hashref;

    if ( $row ) {
        $self->hit( $row->{value} );
        return $row->{value};
    }
    return undef;
}

sub purge {
    my ( $self, $key ) = @_;
    my $sth = $self->sth("purge");
    $sth->execute( $key );
    return $self;
}

sub purge_expired {
    my ( $self ) = @_;
    my $sth = $self->sth("purge_expired");
    $sth->execute( time() );
    return $self;
}

sub purge_over_limit {
    my ( $self ) = @_;
    my $sth = $self->sth("purge_limit");
    $sth->execute( $self->cache_limit );
    my $delete = $self->$self->sth("delete");
    for my $row ( $sth->fetchrow_hashref ) {
        next unless $row;
        $delete->execute( $row->{key} );
    }
    return $self;
}

sub hit {
    my ( $self, $key ) = @_;
    if ( $hit{$key}++ % 15 == 0 ) {
        my $sth = $self->sth("hit");
        $sth->execute( $key );
    }
    return $self;
}

sub exists {
    my ( $self, $key ) = @_;
    my $sth = $self->sth("exists");
    $sth->execute( $key );
    my $row = $sth->fetchrow_hashref;
    return 0 unless defined $row and $row->{key} eq $key;
    return 1;
}

1;
