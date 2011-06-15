package Cache::SQLite;
use warnings;
use strict;
use DBI;
use Data::Dumper;

our $VERSION = '0.001000'; # 0.1.0
$VERSION = eval $VERSION;

my $timer = time();

sub new {
    my ( $class ) = @_;
    my $self = {};
    bless $self, $class;
    $self->connection(
        DBI->connect( "dbi:SQLite:dbname=:memory:", "", "" )
    );
    $self->_make_table();
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
    my $sth = $self->connection
        ->prepare( "INSERT into cache ( key, value, expires ) VALUES( ?, ?, ? )" );
    $sth->execute( $key, $value, $expires || 0 );
    return $self;
}

sub get {
    my ( $self, $key ) = @_;

    if ( $timer >= time() + $self->work_lapse ) {
        $self->purge_over_limit;
        $self->purge_expired; 
    }

    my $sth = $self->connection->prepare( "SELECT * FROM cache WHERE key = ? LIMIT 1" );
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
    my $sth = $self->connection->prepare( "DELETE FROM cache WHERE key = ?" );
    $sth->execute( $key );
    return $self;
}

sub purge_expired {
    my ( $self ) = @_;
    my $sth = $self->connection->prepare("DELETE FROM cache where expires <= ? AND expires != 0");
    $sth->execute( time() );
    return $self;
}

sub purge_over_limit {
    my ( $self ) = @_;
    my $sth = $self->connection->prepare( "SELECT * from cache ORDER BY hit DESC LIMIT 1000 OFFSET ?" );
    $sth->execute( $self->cache_limit );
    my $delete = $self->connection->prepare( "DELETE FROM cache WHERE key = ?" );
    for my $row ( $sth->fetchrow_hashref ) {
        next unless $row;
        $delete->execute( $row->{key} );
    }
    return $self;
}

sub hit {
    my ( $self, $key ) = @_;
    my $sth = $self->connection->prepare( "UPDATE cache SET hit = hit + 1 WHERE key = ?" );
    $sth->execute( $key );
    return $self;
}

sub exists {
    my ( $self, $key ) = @_;
    my $sth = $self->connection->prepare( "SELECT key FROM cache WHERE key = ? LIMIT 1" );
    $sth->execute( $key );
    my $row = $sth->fetchrow_hashref;
    return 0 unless defined $row and $row->{key} eq $key;
    return 1;
}

1;
