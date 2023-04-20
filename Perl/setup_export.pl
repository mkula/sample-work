#!/usr/bin/perl

use strict;
use lib '/data/cheetah/lib';
use File::Path qw(make_path remove_tree);
use File::Copy;
use Getopt::Long;

my $userid = getpwuid($>);
my $top = qq{/historical/$userid};
my $eventmaster = qq{/data/cheetah/backend/event_master};

if (! -d $top ){
  print "directory $top doesn't exist - please create!\n";
  exit;
}

# ------------------------------------------
# command line options
# ------------------------------------------
# /data/home/historical/setup_export.pl --said=SAID --email=EMAIL
my %options = ();
GetOptions('said=s'	=>	\$options{said},
           'email=s'    =>      \$options{email},
           'cdb=s'      =>      \$options{cdb}
          );

if ($options{said} eq ""){
  print "usage: $0 --said=<said> [--email=email address] [--cdb=path to existing CDBs (e.g. /eve/gen)]\n";
  print "email defaults to youruserid\@cheetahmail.com ($userid\@cheetahmail.com) unless specified by --email\n";
  exit;
}

my $email = $userid . q{@cheetahmail.com};
if ($options{email} ne ""){
  $email = $options{email};
}

print qq(SAID: $options{said}\n);
print qq(root directory: $top\n);
print qq(email: $email\n);

# create event export directory structure
make_path("$top/$options{said}/eve", 
          "$top/$options{said}/eve/conf",
          "$top/$options{said}/eve/data",
          "$top/$options{said}/eve/tmp",
          "$top/$options{said}/eve/done",
          "$top/$options{said}/eve/scripts",
          "$top/$options{said}/cdb",
{
          verbose => 1,
          #mode => 0777,
});

# copy conf file over
print qq(copying /eve/conf/$options{said} -> $top/$options{said}/eve/conf\n);
if ( ! copy("/eve/conf/$options{said}","$top/$options{said}/eve/conf") ) {
  print "Copy failed for /eve/conf/$options{said}: No such file or directory\n";
  print "Creating skeleton export configuration file\n";
  open(my $conf,">$top/$options{said}/eve/conf/$options{said}");
print $conf <<EOF;
# $options{said}
delim=T

# format scripts 
event=0_format

# output options
compress=gzip
ssh_path=/z0/client/$options{said}/autoproc/incoming

# export selection options
# incl={sent      ebm_sent        bounce  clickopens      unsubs  iid_keys}

# use cdb 
cdb=1
cdb_event=1

EOF
close $conf;
}

# add wo2cdbpath to config file
open(my $f,">>$top/$options{said}/eve/conf/$options{said}");
print qq(adding wo2cdb_path=$top/$options{said}/cdb/ to config file\n);
print $f qq(wo2cdb_path=$top/$options{said}/cdb/\n);
close $f;  

# read config file 
my $config_items = read_config("$top/$options{said}/eve/conf/$options{said}");

# copy scripts over
my @scripts = qw(event loader sub);
foreach my $script (@scripts) {
  if (exists $config_items->{$script}) {
    print qq(copying /eve/scripts/$config_items->{$script} -> $top/$options{said}/eve/scripts\n);
    copy("/eve/scripts/$config_items->{$script}","$top/$options{said}/eve/scripts") or die "Copy failed: $!";
    chmod 0777, "$top/$options{said}/eve/scripts/$config_items->{$script}";
  }
}

# determine if the export runs in a special queue
my $queue = ""; 
if (exists $config_items->{queue}) {
  $queue = "-q" . $config_items->{queue};
}

# cdb path
my $cdb_path = qq(/historical/$userid/$options{said}/cdb/);
if ($options{cdb} ne ""){
  $cdb_path = $options{cdb};
}

# create shell script to run the export
my $script = "";
while (<main::DATA>){
  $script .= $_;
}
$script =~ s|\@\@queue\@\@|$queue|;
$script =~ s|\@\@userid\@\@|$userid|g;
$script =~ s|\@\@said\@\@|$options{said}|g;
$script =~ s|\@\@email\@\@|$email|g;
$script =~ s|\@\@cdb\@\@|$cdb_path|g;
open(my $f,">$top/$options{said}/$options{said}.sh");
print $f $script;
close $f;
chmod 0755, "$top/$options{said}/$options{said}.sh";

sub read_config{
  my $path = shift;
  my @arr = ();
  my %hash = ();

  open(my $f,"<$path") || die $!;

  while (<$f>) {
    chomp;                  # no newline
    s/#.*//;                # no comments
    s/^\s+//;               # no leading white
    s/\s+$//;               # no trailing white
    next unless length;     # anything left?
    my ($var, $value) = split(/\s*=\s*/, $_, 2);
    $hash{$var} = $value;
  } 

  close $f;

  return (\%hash);
  
}

__END__
#!/bin/bash 

control_c()
# run if user hits control-c
{
  echo -en "\n*** Ouch! Exiting ***\n"
  PID=$(ps -ef | grep $current | grep event_master | awk '{print $2}')
  if [[ $PID -gt 0 ]]; then
    pkill -9 -s $PID
  fi
  exit $?
}
 
# trap keyboard interrupt (control-c)
trap control_c SIGINT

declare -A hash
# store arguments in a special array
args=("$@")
# get number of elements
ELEMENTS=${#args[@]}

exports=${args[$#-1]}

OIFS="$IFS"

# echo each element in array
# for loop
for (( i=0;i<$ELEMENTS-1;i++)); do
  IFS=',' read -a arr <<< "${args[${i}]}"
  for element in "${arr[@]}"
    do
      element=${element//[\{\}]/}   # remove any braces if date was incorrectly specified
      hash[$element]=""
    done
done

IFS=$OIFS

# assign dates to daterange array
daterange=()

for i in "${!hash[@]}"
do
  daterange+=($i)
done

# date1-date2
# e.g. 20130801-20130810
if [[ ${#hash[@]} -eq 1  && ${!hash[@]} =~ "-" ]]; then
  s=${!hash[@]}
  IFS='-' read date1 date2 <<< "$s"
  daterange=()
  current=$(date -d "$date1" +"%Y%m%d")
  end=$(date -d "$date2 1 day" +"%Y%m%d")
  while [ "$end" != "$current" ]
  do
    daterange+=($current)
    current=$(date -d "$current 1 day" +"%Y%m%d")
  done
fi

# date+days
# e.g. 20130801+6 
# export runs for 20130801 - 20130807
if [[ ${#hash[@]} -eq 1  && ${!hash[@]} =~ "+" ]]; then
  s=${!hash[@]}
  IFS='+' read date1 numdays <<< "$s"
  daterange=()
  current=$(date -d "$date1" +"%Y%m%d")
  for (( c=0; c<=$numdays; c++ ))
  do
    echo $current
    daterange+=($current)
    current=$(date -d "$current 1 day" +"%Y%m%d")
  done
fi

# split event types in to array
IFS=',' read -a array <<< "$exports"

cd /historical/@@userid@@/@@said@@

export SCRIPT_SAID=@@said@@
export SCRIPT_SANAME=$(cdbget @@said@@ < /cdb/data/said_saname.cdb)

if [ $# -lt 2 ] || [[ ! "$exports" =~ (sub|event|loader) ]]
  then
    echo "usage: ./@@said@@.sh <daterange> <type>"
    echo "daterange = one of three formats:" 
    echo "            date1-date2 (date format yyyymmdd) "
    echo "            date+days (date format yyyymmdd) , e.g. 20130801+6"
    echo "            list of dates, e.g. 20130806,20130807 or 201308{06,07,08},20130705"
    echo "type = one or more of [sub,event,loader] (comma separated)"
    exit
fi

readarray -t sorted < <(for a in "${daterange[@]}"; do echo "$a"; done | sort -n)

for current in "${sorted[@]}"
do
  
find . -name "*done*" -exec rm {} \; 2>/dev/null
find . -name "*lock*" -exec rm {} \;

export SCRIPT_DATE=$current

  for type in "${array[@]}"
    do

now="$(date +'%Y%m%d')"
if [ $current -ge $now ]
  then
    echo "exiting: $current is greater than or equal to today (no export data available yet)"
    exit
fi

export SCRIPT_TYPE=$type

# perl
/usr/bin/perl <<'EOF'
use strict;
use lib '/data/cheetah/lib';
use DBI;
use File::Path qw(remove_tree);
use Date::Parse;
use DateTime;
use Switch;
use Archive::Tar;
use IO::Zlib;
use Cwd qw(abs_path getcwd);
use POSIX;

$| = 1;

my $date = $ENV{SCRIPT_DATE};
my ($yyyy,$mm,$dd) = ($date =~ m|(\d{4})(\d{2})(\d{2})|);
my $type = $ENV{SCRIPT_TYPE};
my $said = $ENV{SCRIPT_SAID};
my $saname = $ENV{SCRIPT_SANAME};

my $header = "$saname ($said) - running $type export for $yyyy-$mm-$dd";
print "=" x length($header),"\n";
print $header,"\n";
print "=" x length($header),"\n";

# path to commands
my $sort = qq{/bin/sort};
my $grep = qq{/bin/grep};
my $zgrep = qq{/usr/bin/zgrep};

# follow symbolic links and create file
$Archive::Tar::FOLLOW_SYMLINK=1;

# database 
use constant CONF_FILE  => '/data/cheetah/appconf/dbi_login.conf';
my(%config, %attributes, $storedHandle, $multiHandles);
%config = do(CONF_FILE);

$ENV{'ORACLE_SID'} = $config{'oracle_sid'};
$ENV{'TWO_TASK'}   = $config{'two_task'};
$ENV{'ORACLE'}      = $config{'oracle'};
$ENV{'ORACLE_HOME'} = $config{'oracle_home'};

my %attr = (
            'RaiseError' => 1,
            'PrintError' => 1,
            'AutoCommit' => 0   # no explicit commit required as we are autocommiting
        );

my $path = getcwd();
mkdir "$path/event_dir";

my %event_subs = ("bounce" 	=> \&_b,
                  "ebm_sent"	=> \&_e,
                  "sent"        => \&_w,
                  "unsubs"      => \&_uM,
                  "loader"      => \&_l,
                  "unloader"    => \&_u
                 );

# get list of AIDs sorted numerically
my $aidlist = `/data/cheetah/bin/tx said_aid $said`;
$aidlist =~ s|\n||g;
my (@aids) = sort { $a <=> $b } split(/,/ => $aidlist);

# subscriber activity exports don't rely on /eve/data
# can therfore be pulled for any date without checking if /eve/data/yyyymmdd directory exists

# read eve/conf/<said> configuration file to get "incl" key
my $config_items = read_config("$path/eve/conf/$said");
my $incl = $config_items->{incl};
my %events = map { $_ => 1 } eval("qw" . $incl);

switch ($type) {

  case "event" {
    my $r = checkdate();

    if ($r == 4) {

      foreach my $event (qw{bounce unsubs ebm_sent sent}) {
        if (exists $events{$event}) {
          # run corresponding sub to recreate _ file
          $event_subs{$event}->();
        }
      }

    }
  }

  case "loader" {
    my $r = checkdate();

    if ($r == 4) {

      foreach my $event (qw{loader unloader}) {
        if (exists $events{$event}) {
          # run corresponding sub to recreate _ file
          $event_subs{$event}->();
        }
      }

    }
  }

}

# rewrite config file with event_dir
open(my $tmp,">$path/eve/conf/$said.tmp");
open(my $config,"<$path/eve/conf/$said");
while(<$config>){
  if (!/event_dir=/){
    print $tmp $_;
  }
}
print $tmp qq{event_dir=$path/event_dir/$date/$said\n};
close $config;
close $tmp;
unlink <"$path/eve/conf/$said">;
rename "$path/eve/conf/$said.tmp","$path/eve/conf/$said";

sub get_sorted_files {
   my $path = shift;
   my $filepattern = shift;
   my $option = shift;
   opendir my($dirh), $path or die "can't opendir $path: $!";
   my @flist = ();
   if ($option eq "n") {
     @flist = sort { $a cmp $b } # sort by name (option: n)
                 map  { "$path/$_" } # need full paths for sort
                 grep { m/$filepattern/i }
                 readdir $dirh;
   }
   else {
     @flist = sort {  -M $b <=> -M $a } # sort by mod time (option: m)
                 map  { "$path/$_" } # need full paths for sort
                 grep { m/$filepattern/i }
                 readdir $dirh;
   }
   closedir $dirh;
   return @flist;
}

sub _b {
  print qq{bounces ($date): attempting to recreate _b${said}\n};

  # == looking for bounce data in /stats/bounce-remote/4 ==
  # == or /stats/archive01/bounce-remote/4/ ==

  my @options = ("/stats/bounce-remote/4/BO$date.gz","/stats/archive01/bounce-remote/4/BO$date.gz");

  foreach my $bouncefile (@options) {

    if (-e "$bouncefile"){
      print qq{bounce data for _b${said} - searching in $bouncefile\n};
      my $affiliates = join("|",@aids);

      my $cmd = qq(LC_ALL=C $zgrep -Eh "$affiliates" $bouncefile > $path/event_dir/$date/$said/_b${said});
      `$cmd`;

      return;
    }

  }

  STATS:

  # we can't find original bounce data in above files  

  # == reproduction of _b file bounce records for a given date ==
  # == requires looking back at bounce data over last 60 days and matching activity date ==

  open(my $b,">$path/event_dir/$date/$said/_b${said}");

  my $dt = DateTime->new(year => $yyyy, 
                         month => int($mm), 
                         day => int($dd), 
                         time_zone => "America/New_York",
                         hour => 0,
                         minute => 1
                         )->add( days => -60 );

  # == 12:00:00 AM - 23:59:59 PM ==
  my $start_epoch = DateTime->new(year => $yyyy,
                         month => int($mm),
                         day => int($dd),
                         time_zone => "America/New_York",
                         hour => 0,
                         minute => 0,
                         second => 0
                         )->epoch;

  my $end_epoch = DateTime->new(year => $yyyy,
                         month => int($mm),
                         day => int($dd),
                         time_zone => "America/New_York",
                         hour => 23,
                         minute => 59,
                         second => 59
                         )->epoch;

  my %bouncedates = ();

    foreach my $aid (@aids) {

    my $dtobj = $dt->clone;

    # path to stats directory for AID
    my $modaid = "/stats/" . $aid % 53 . "/$aid/$aid";

    while (1) {
      my $d = $dtobj->ymd('');
      #print $d,"\n";
      my ($yyyy_,$mm_,$dd_) = ($d =~ m|(\d{4})(\d{2})(\d{2})|);

      my $statsdir = "$modaid/$yyyy_/${mm_}${dd_}";

      if ( -d $statsdir) {

        my @bfiles = get_sorted_files($statsdir,"^b","n");

        foreach my $bfile (@bfiles) {

          next if ($bfile =~ /\.i$/);

          my $filedate = POSIX::strftime( "%Y%m%d", localtime( ( stat $bfile )[9]));  
          next if ($filedate < $date);

          #print $bfile,"\n";

          #open(my $fh,"<" . $bfile); # read b<wostart>_<mid> stats file
          #open(my $fh,"/bin/sort -k6,6 $bfile |");

          my $cmd = qq(awk '\$6 <= $end_epoch \&\& \$6 >= $start_epoch {print \$0}' $bfile >> ) . "$path/event_dir/$date/$said/_b${said}";
          `$cmd`;
          #open(my $fh,"$cmd |");

          #while(<$fh>){
            #chop;
            #my (@record) = split(/\t/);
            #if ($record[-1] <= $end_epoch && $record[-1] >= $start_epoch) {
            #  print $b "$_\n";
            #  $bouncedates{$d} +=1;
            #}
            #last if ($record[-1] > $end_epoch);
            #print 
            #print $b $_;
          #}

          #close $fh;

        }


      }

      last if ($date == $d);
      $dtobj->add( days => 1);

   
    }

  }

  close $b;

  # sort the _b file
  my $cmd = qq($sort $path/event_dir/$date/$said/_b${said} -o $path/event_dir/$date/$said/_b${said} -k 1,1n -k 2,2n -k 3,3n -k 4,4n -k 6,6n);
  `$cmd`;

  return;
  
  # == code below not used ==

  DATABASE:
  # == unusual to find no bounce data from 2007 onwards ==
  # == now let's check the database ==

  # now going to the database instead
  # database does not include bounce records for testers (USER_PROF_ID = 0)
  print "Searching database for bounce data - $yyyy-$mm-$dd\n";
  print "Note: no bounce recoprds available for tester addresses\n";
  my $sql = qq{SELECT AFFILIATE_ID,WOSTART,MAILING_ID,USER_PROF_ID,BOUNCE_TYPE,TO_CHAR(MIN(BOUNCE_TIME),'YYYY-MM-DD HH:MI:SS AM')
               FROM BOUNCE_$said 
               WHERE TO_DATE(BOUNCE_TIME)=TO_DATE('$yyyy-$mm-$dd','YYYY-MM-DD')
               GROUP BY AFFILIATE_ID,WOSTART,MAILING_ID,USER_PROF_ID,BOUNCE_TYPE
               ORDER BY AFFILIATE_ID,WOSTART,USER_PROF_ID,BOUNCE_TYPE
              };

  my $dbh = DBI->connect(@config{'connect', 'username', 'password'}, { %attr });
  open(my $b,">$path/event_dir/$date/$said/_b${said}");
  my $sth = $dbh->prepare($sql);
  $sth->execute;

  my $rowcount = 0;
  while (my (@row)=$sth->fetchrow_array) {
    $rowcount++;
    $row[-1] = str2time($row[-1]); # convert oracle date/time to unix epoch
    print $b join("\t",@row),"\n";
  }
  $sth->finish;
  $dbh->disconnect;

  close $b;  # close _b file handle

  # sort the _b file
  my $cmd = qq($sort $path/event_dir/$date/$said/_b${said} -o $path/event_dir/$date/$said/_b${said} -k 1,1n -k 2,2n -k 3,3n -k 4,4n -k 6,6n);
  `$cmd`;

  if ($rowcount == 0){
    print "bounce data not available for $date\n";
  }

}

sub _e {
  # == looking for ebm data in /stats/ebm/4 ==
  # == or /stats/archive01/ebm/4/ == 

  print qq{ebm_sent ($date): recreating _e$said file\n};

  my @options = ("/stats/ebm/4/EBM$date.gz","/stats/archive01/ebm/4/EBM$date.gz");

  foreach my $ebmfile (@options) {

    if (-e "$ebmfile"){
      print qq{ebm data for _e${said} - searching in $ebmfile\n};
      my $affiliates = join("|",@aids);
      
      my $cmd = qq(LC_ALL=C $zgrep -Eh "$affiliates" $ebmfile > $path/event_dir/$date/$said/_e${said});
      `$cmd`;

      return;
    }

  }

  # we can't find original ebm data in above files  

  # == reproduction of _e file ebm sent records for a given date ==
  # == requires looking back at ebm send data over last 90 days and matching send date ==

  open(my $e,">$path/event_dir/$date/$said/_e${said}");

  my $dt = DateTime->new(year => $yyyy, 
                         month => int($mm), 
                         day => int($dd), 
                         time_zone => "America/New_York",
                         hour => 0,
                         minute => 1
                         )->add( days => -90 );
  $dt->set_day(1); # go to beginning of month

  # == 12:00:00 AM - 23:59:59 PM ==
  my $start_epoch = DateTime->new(year => $yyyy,
                         month => int($mm),
                         day => int($dd),
                         time_zone => "America/New_York",
                         hour => 0,
                         minute => 0,
                         second => 0
                         )->epoch;

  my $end_epoch = DateTime->new(year => $yyyy,
                         month => int($mm),
                         day => int($dd),
                         time_zone => "America/New_York",
                         hour => 23,
                         minute => 59,
                         second => 59
                         )->epoch;

  foreach my $aid (@aids) {

    my $dtobj = $dt->clone;

    # path to stats directory for AID
    my $modaid = "/stats/" . $aid % 53 . "/$aid/$aid";

    while (1) {
      my $d = $dtobj->ymd('');
      my ($yyyy_,$mm_,$dd_) = ($d =~ m|(\d{4})(\d{2})(\d{2})|);

      my $statsdir = "$modaid/$yyyy_/${mm_}${dd_}";

      if ( -d $statsdir) {

        my @efiles = get_sorted_files($statsdir,"^e","n");

        if (scalar @efiles > 0) {

          my @eids = grep(!/\./, @efiles); 

          foreach my $eid (@eids) {
            open(my $fh,"<" . $eid);
            my $contents = do { local $/ = <$fh> }; # slurp in e<wostart>_<mid> stats file
            close $fh;

            if ($contents =~ /$date/){
              my @elist = grep(!/$eid$/ && !/\.i/, @efiles);  
              print "reading $elist[0]\n";
              open(my $tmp, "<" . $elist[0]);
              while(<$tmp>){
                chop;
                my (@record) = split(/\t/);
                print $e "$_\n" if ($record[-1] <= $end_epoch && $record[-1] >= $start_epoch);
              }
              close $tmp;
            } 

          }


        }

      }

      last if ($date == $d);
      $dtobj->add( days => 1);

   
    }

  }


  close $e;
}

sub _w {
  print qq{sent ($date): recreating _w$said file\n};

  my $wofile = "/stats/log/wodist/$yyyy/W$date";

  if (-e $wofile){
    print qq{work orders for _w${said} - searching in $wofile\n};

    my $affiliates = join("|",@aids);

    my $cmd = qq(LC_ALL=C $grep -Eh "$affiliates" $wofile > $path/event_dir/$date/$said/_w${said});
    `$cmd`;

  }

  else {
    open(my $w,">$path/event_dir/$date/$said/_w${said}");
    foreach my $aid (@aids) {
      my $statsdir = "/stats/" . $aid % 53 . "/$aid/$aid/$yyyy/${mm}${dd}";
      next if (! -d $statsdir);  # skip non existent directories
      my @workorders = get_sorted_files($statsdir,":");
      foreach my $workorder (@workorders){
        my(@tmp) = split(/\//,$workorder);
        print $w $tmp[-1],"\n";
      }
    }
    close $w;

    # now sort the file
    `$sort $path/event_dir/$date/$said/_w${said} -o $path/event_dir/$date/$said/_w${said}`;
  }
}

sub _uM {
  print qq{unsubs ($date): recreating _uM$said file\n};
  my $affiliates = join("|",@aids);
  my $regex = qr/$affiliates/;
  
  if (-e "/stats/unsub/$yyyy/uM${yyyy}${mm}${dd}") {
    print qq{unsub data for _uM${said} - searching in /stats/unsub/$yyyy/uM${yyyy}${mm}${dd}\n};
    open(my $uM,">$path/event_dir/$date/$said/_uM${said}");

    open(my $f,"</stats/unsub/$yyyy/uM${yyyy}${mm}${dd}");
    while(<$f>){
      my (@record) = split(/,/);
      $record[-1] =~ s|^"||;
      $record[-1] =~ s|"$||;
      print $uM join("\t",@record) if ($record[6] =~ /$regex/);
    }
    close $f;

    close $uM;
  }
  else {
    print "cannot find original unsub data\n";
  }
  
}

sub _u {
  print qq{unloader ($date): attempting to recreate _u$said file\n};

  # == looking for unloader data in /stats/log/unsubdist/yyyy ==
  my $unloadfile = qq{/stats/log/unsubdist/$yyyy/U$date};

  if (-e "$unloadfile"){
    print qq{unload data for _u${said} - searching in $unloadfile\n};
    open(my $fh,"<$unloadfile");
    open(my $u,">$path/event_dir/$date/$said/_u${said}");
    while(<$fh>){
      if (/$said/) {
        my (@record) = split(/\//);
        print $u $record[-1] ;
      }
    }
    close $fh;
    close $u;

    return;
  }


  # == fall back to looking at said mod53 folder in /stats ==
  my $statsdir = "/stats/" . $said % 53 . "/$said/$said/$yyyy/${mm}${dd}";
  if (-d $statsdir) {
    my @list = get_sorted_files($statsdir,"lu.*");
    open(my $u,">$path/event_dir/$date/$said/_u${said}");
    foreach my $file (@list) {
      my(@tmp) = split(/\//,$file);
      print $u $tmp[-1],"\n";
    }
    close $u;
  }
  else {
    "no unloader data files available for $date\n";
  }

}

sub _l {
  print qq{loader: attempting to recreate _l$said file\n};
  print "Note: actual loader files are typically not available after 30 days (in some cases less)\n";

  # == looking for loader data in /stats/log/loaddist/yyyy ==
  my $loadfile = qq{/stats/log/loaddist/$yyyy/L$date};

  if (-e "$loadfile"){
    print qq{load data for _l${said} - searching in $loadfile\n};
    open(my $fh,"<$loadfile");
    open(my $l,">$path/event_dir/$date/$said/_l${said}");

    while(<$fh>){
      print $l $_ if (/$said/);
    }

    close $fh;
    close $l;

    return;
  }
  

  # == fall back to looking at said mod53 folder in /stats ==
  my $statsdir = "/stats/" . $said % 53 . "/$said/$said/$yyyy/${mm}${dd}";
  if (-d $statsdir) {
    print qq{load data for _l${said} - searching in $statsdir\n};
    my @list = get_sorted_files($statsdir,"ls.*");
    open(my $l,">$path/event_dir/$date/$said/_l${said}");
    if (scalar @list > 0) {
      foreach my $file (@list) {
        my(@tmp) = split(/\//,$file);
        print $l $tmp[-1],"\n";
      }
    }
    else {
      print "loader: no loads took place on $date\n";
    }
    close $l;
  }
  else {
    "loader: no stats data available for $date - cannot find $statsdir\n";
  }
}

sub donefiles {
  my $dir = qq{$path/event_dir/$date};
  my @files = qw{done-split-b done-split-e done-split-l done-split-m done-split-u done-split-w};
  foreach my $file (@files) {
    open(my $tmp,">$dir/$file");
    print $tmp $said,"\n";
    close $tmp;
  }
 
}

sub checkdate {

  remove_tree("$path/event_dir/$date");

  if (-d "/eve/data/$date" || (-l "/eve/data/$date" && -d abs_path("/eve/data/$date")) ) {
    symlink("/eve/data/$date","$path/event_dir/$date");
    return 1;
  }

  if (-e "/eve/data/$date.gz") {
    my $path = getcwd();
    mkdir "$path/event_dir";
    
    print qq{untarring /eve/data/$date.gz to $path/event_dir\n};
    my $tar = Archive::Tar->new;
    $tar->read("/eve/data/$date.gz");
    $tar->setcwd("$path/event_dir");
    my @items = $tar->get_files;
    for my $item (@items) {
      if ($item->name =~ /(done|$said)/){
        my $newname = $item->name;
        $newname =~ s|eve/data/||;
        $tar->extract_file($item->name,qq{$path/event_dir/$newname});
      }
    }

    return 2;
  }

  if (-d "/stats/eve/data/$date") {
    symlink("/stats/eve/data/$date","$path/event_dir/$date");

    return 3;
    
  }


  # no matching date found
  # will need to recreate raw data under event_dir/
  print "/eve/data/$date not available\n";
  mkdir "$path/event_dir/$date";
  donefiles();
  mkdir "$path/event_dir/$date/$said";
  return 4;
  
}

sub read_config{
  my $path = shift;
  my @arr = ();
  my %hash = ();

  open(my $f,"<$path") || die $!;

  while (<$f>) {
    chomp;                  # no newline
    s/#.*//;                # no comments
    s/^\s+//;               # no leading white
    s/\s+$//;               # no trailing white
    next unless length;     # anything left?
    my ($var, $value) = split(/\s*=\s*/, $_, 2);
    $hash{$var} = $value;
  }

  close $f;

  return (\%hash);

}


EOF

/data/cheetah/backend/event_master -D @@queue@@ -y1 -e@@email@@ -v./event_dir/ -d./eve/conf/ -t./eve/tmp/ -c./eve/done/ -s./eve/scripts/ $type $current local 1 local_path ./eve/data/ cdb_path @@cdb@@
 
  done

done



