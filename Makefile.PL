use inc::Module::Install;
  
# Define metadata
name           'Cache-SQLite';
all_from       'lib/Cache/SQLite.pm';
license        'bsd';

# Specific dependencies
requires       'DBI';
requires       'DBD::SQLite';

test_requires  'Test::More'             => '0.42';

WriteAll;
