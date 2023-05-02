#!/usr/bin/perl
# this script generates a mapping file of MID_WOSTART => ISSUE_ID that is then used in autoproc
# to map base64 ISSUE_ID to base64alt ISSUE_ID in the Omniture Event Exports before they are sent out to Omniture

use strict;
use warnings;

use DateTime;
use Data::Dumper;
use File::Basename;
use IO::File;

use lib '/data/cheetah/lib';
use CTAH::Constants::Global;
use CTAH::Content_Store;
use CTAH::IOHandle;


my $dt = DateTime->now;

my $tx      = '/data/cheetah/bin/tx';
my $cdbdump = '/usr/local/bin/cdbdump';

my $transfer_host = 'REDACTED';
my $transfer_file = '/client/REDACTED/autoproc/incoming/mid_wostart_issueid_mapping_' . $dt->ymd('') . '.txt.gz';

my $omniture_conf_dir = '/eve/summail/conf';
my $delim             = "\t";

# all client SAIDs
my %client_saids = (
  REDACTED => 1,
  REDACTED  => 1,
  REDACTED => 1,
  REDACTED => 1,
  REDACTED => 1,
  REDACTED => 1,
  REDACTED => 1,
  REDACTED  => 1,
  REDACTED  => 1,
  REDACTED  => 1,
  REDACTED  => 1,
  REDACTED  => 1,
  REDACTED  => 1,
  REDACTED => 1,
);

# get all AIDs for client SAIDs
my %client_aids = ();
for my $said (keys %client_saids) {
  for my $aid (split /,/, `$tx said_aid $said`) {
    chomp $aid;
    next unless $aid;
    $client_aids{$aid} = 1;
  }
}

# gather all client Omniture AIDs from Omniture Exports config files
my %omniture_aids = ();
opendir my $dir_fh, $omniture_conf_dir
  or die "Unable to opendir $omniture_conf_dir for listing: $!\n";

while (defined(my $file = readdir $dir_fh)) {
  my $in_fh = IO::File->new("$omniture_conf_dir/$file", "r")
    or die "Unable to open $omniture_conf_dir/$file for reading: $!";

  while (my $line = <$in_fh>) {
    chomp $line;

    $line =~ s/^\s+//g;

    if ($line =~ /^aids/) {
      my ($garbage, $aids) = split /=/, $line;

      for my $aid (split /,/, $aids, -1) {
        chomp $aid;
        next unless exists $client_aids{$aid};
        $omniture_aids{$aid} = 1;
      }
    }
  }
  $in_fh->close
    or die "Unable to close $omniture_conf_dir/$file after reading: $!";
}
closedir $dir_fh
  or die "Unable to closedir $omniture_conf_dir after traversing: $!\n";


# generate a list of all MIDs for the client Omniture Exports AIDs
my @mids = ();
for my $aid (sort keys %omniture_aids) {
  push @mids, grep { /^\d+$/ } split /,/, `$tx aid_pid $aid`;
}


# open a connection with TTB
my $out_fh = CTAH::IOHandle->new(host => $transfer_host, file => $transfer_file)
  or die "Could not open $transfer_host:$transfer_file for writing: $!\n";


for my $mid (@mids) {
  # get the directory for the MID redirects if it exists
  my ($redir_path) = map { /(.+\/)\d+$/ } $redir_share . '/p/'. _path_from_id($mid);
  # otherwise skip the MID
  next unless -d $redir_path;

  # get the redirects for the MID
  my @redirs = map { basename($_) } split /\n/, `find $redir_path | grep $mid`;

  for my $redir (@redirs) {
    # only interested in redirects for deployed MIDs
    # if there's no WOSTART then this redirect is not
    # for a mailing that has been deployed. skip it.
    #                MID ------|   |------ WOSTART
    next unless $redir =~ /^r_\d+_\d+$/;

    # the first line of the redirect will contain External Link Tracking if it was enabled for the MID
    # get ISSUE_ID from Omniture External Link Tracking (om_mid)
    my ($issue_id) = map { /&om_mid=([^&]+)/ } `$cdbdump < $redir_path/$redir | head -n1`;

    # if ISSUE_ID doesn't exist then the MID did not have Omniture External Link Tracking enabled
    # move on to the next redirect
    next unless $issue_id;

    my ($mid_wostart) = $redir =~ /^r_(\d+_\d+)$/;

    $out_fh->print(join $delim, $mid_wostart, $issue_id);
    $out_fh->print("\n");
  }
}

$out_fh->close
  or die "Could not close $transfer_host:$transfer_file after writing: $!\n";
