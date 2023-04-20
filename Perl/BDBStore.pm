package BDBStore;

use strict;
use Carp;
use BerkeleyDB;
use Data::Dumper;
use File::Basename;
use File::Path qw(mkpath);

use lib qw(/data/cheetah/lib);
use CTAH::TTBClient;

use constant TRUE  => 1;
use constant FALSE => 0;

=head1 NAME

BDBStore - OOP wrapper for access to BDB databases.



=head1 VERSION

0.10



=head1 SYNOPSIS

  use lib '/data/clientdev/lib';
  use BDBStore;

  $said    = 123456789;
  $bdb_dir = '/client/123456789/etc/bdb';

  $r = BDBStore->new({said => $said, bdb_dir => $bdb_dir});



=head1 DESCRIPTION

BDBStore encapsulates the storage of key, value pairs in multiple BDB files. This is to avoid exceeding the file size limitations. The module does not allow for multiple occurances of a key.



=head1 METHODS

=over

=item BDBStore->new({said => $said, bdb_dir => $bdb_dir})

$said - required. Client's SAID.

$bdb_dir - required. Location of where the BDB files will be stored.

Creates an instance of the class.


=item $r->exists($key)

$key - required.

Checks for existance of a key in the database and returns a '1' if $key exists, otherwise returns a '0'.


=item $r->insert($key, $value)

$key   - required.

$value - optional.

Inserts key, value pair into the database. If no value provided, '1' gets inserted as $value for $key.


=item $r->delete($key)

$key - required.

Deletes record matching $key from the database if exists, otherwise no action taken.


=item $r->get_value($key)

$key - required.

Returns value of $key if $key exists, otherwise returns undef.


=item $r->get_key($value)

$value - required.

Returns a list of keys for a matching $value.


=item $r->dump()

Prints 'key=value' for each record in the database to STDOUT.

=back



=head1 AUTHOR

Mariusz Kula <mariusz.kula@experian.com>



=head1 BUGS

None found.



=head1 SEE ALSO



=cut

##----------------------------------------------------------
sub new {
##----------------------------------------------------------
  my ($class, $args) = @_;

  ref $args eq 'HASH'     || croak "Call to BDBStore->new(\$args): \$args must be a hash ref. \$args->{said => \$said, bdb_dir => \$bdb_dir}.\n";
  exists $args->{said}    || croak "Call to BDBStore->new({said => \$said, bdb_dir => \$bdb_dir}): missing \$args->{said => \$said}.\n";
  exists $args->{bdb_dir} || croak "Call to BDBStore->new({said => \$said, bdb_dir => \$bdb_dir}): missing \$args->{bdb_dir => \$bdb_dir}.\n";
  
  my $rClient = CTAH::TTBClient->new({said => $args->{said}});

  my $self = {
    said    => $args->{said},
    etc_dir => $rClient->get_path('etc'),
    bdb_dir => -d $args->{bdb_dir}
            ?  $args->{bdb_dir}
            :  mkpath($args->{bdb_dir}),
  };
  
  return bless $self, $class;
}

## PUBLIC METHODS
##----------------------------------------------------------
sub exists {
##----------------------------------------------------------
  my ($self, $key) = @_;
 
  $key || croak "Call to BDBStore->exists(\$key) missing key\n";
  $key  = lc $key;

  $self->_get_value_for_key($key) ? return TRUE : return FALSE;
}

##----------------------------------------------------------
sub insert {
##----------------------------------------------------------
  my ($self, $key, $value) = @_; 

  $key   ||  croak "Call to BDBStore->insert(\$key, [\$value]) missing key\n";
  $key    =  lc $key;
  $value ||= 1;

  $self->_tie_for_key($key);

  $self->{bdb_object}->db_get($key, $value) == 0 || $self->{bdb_object}->db_put($key, $value); 

  return $self;
}

##----------------------------------------------------------
sub delete {
##----------------------------------------------------------
  my ($self, $key) = @_;

  $key || croak "Call to BDBStore->delete(\$key) missing key\n";
  $key  = lc $key;

  $self->_tie_for_key($key);

  $self->{bdb_object}->db_get($key, my $value) == 0 || $self->{bdb_object}->db_del($key);

  return $self;
}

##----------------------------------------------------------
sub get_value {
##----------------------------------------------------------
  my ($self, $key) = @_;

  $key || croak "Call to BDBStore->get_value(\$key) missing key\n";
  $key  = lc $key;

  return $self->_get_value_for_key($key);
}

##----------------------------------------------------------
sub get_key {
##----------------------------------------------------------
  my ($self, $value) = @_;

  $value || croak "Call to BDBStore->get_key(\$value) missing value\n";
  
  my @keys;
  for my $bdb (glob "$self->{'bdb_dir'}/*.bdb") {
    $self->_tie_for_key(basename($bdb));
   
    my $cursor = $self->{bdb_object}->db_cursor();
    while ($cursor->c_get(my $k, my $v, DB_NEXT) == 0) {
      push @keys, $k if $v eq $value;
    }
  } 

  return @keys; 
}

##----------------------------------------------------------
sub dump {
##----------------------------------------------------------
  my $self = shift;

  for my $bdb (glob "$self->{'bdb_dir'}/*.bdb") {
    $self->_tie_for_key(basename($bdb));

    print Dumper $self;
    my $cursor = $self->{bdb_object}->db_cursor();
    while ($cursor->c_get(my $key, my $value, DB_NEXT) == 0) {
      print "$key=$value\n";
    }
  }
}

## PRIVATE METHODS
##----------------------------------------------------------
sub _get_value_for_key {
##----------------------------------------------------------
  my ($self, $key) = @_;

  $key || croak "Call to \$self->_get_value_for_key(\$key) missing key\n";
  $key  = lc $key;

  $self->_tie_for_key($key);

  my $value;
  $self->{bdb_object}->db_get($key, $value) == 0 ? return $value
                                                 : return undef;
}

##----------------------------------------------------------
sub _tie_bdb {
##----------------------------------------------------------
  ## tie a bdb
  my ($self, $bdb) = @_;

  # fail unless we've got all required info
  $bdb || croak "Call to \$self->_tie_bdb(\$bdb) missing bdb name\n";

  my $bdb_path = join '/', $self->{'bdb_dir'}, $bdb;

  $self->{bdb_path} = $self->{bdb_path} eq $bdb_path
                    ? return $self
                    : $bdb_path;

  $self->{bdb_object} = new BerkeleyDB::Hash
                        -Filename => $self->{bdb_path},
                        -Flags => DB_CREATE
    or croak "Unable to open file $self->{bdb_path}: $! $BerkeleyDB::Error\n";

  return $self;
}

##----------------------------------------------------------
sub _tie_for_key {
##----------------------------------------------------------
  my ($self, $key) = @_;

  $key || croak "Call to \$self->_tie_for_key(\$key) missing key\n";

  # get name of BDB from key
  my $bdb = substr($key, 0, 1) . '.bdb';

  return $self->_tie_bdb($bdb);
}

1;
