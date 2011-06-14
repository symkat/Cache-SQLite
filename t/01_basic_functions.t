#!/usr/bin/perl
use warnings;
use strict;
use Test::More;
use Cache::SQLite;

ok my $Cache = Cache::SQLite->new;

ok $Cache->isa( 'Cache::SQLite' );

ok $Cache->set( "hello", "world" );
ok $Cache->set( "Dr", "Who", time() + 10 );

is $Cache->get( "hello" ), "world";
is $Cache->get( "Dr" ), "Who";

ok $Cache->purge( "hello" );
is $Cache->get( "hello" ), undef;

done_testing;
