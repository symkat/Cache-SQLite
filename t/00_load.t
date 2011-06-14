#!/usr/bin/perl
use warnings;
use strict;
use Test::More;

my @required_modules = qw/
    DBI
    DBD::SQLite
    Cache::SQLite
/;

use_ok( $_ ) for @required_modules;

done_testing;
