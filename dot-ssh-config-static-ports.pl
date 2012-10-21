#!/usr/bin/perl -w
#
# Generate SSH config files with tunnels support
# This version uses static port mappings in output config files
# and may play more nicely with some programming libraries that
# make SSH connections (eg. fabric).
#
# Alexander Else. aelse@github

use Data::Dumper;

my $host_tree = {};
my @parent    = ($host_tree);
my $indent    = 0;
my $line      = 0;
my %global_port_register;

sub add_host(@)
{
  my ($host, $addr, $extra) = @_;

  my $attrs = {
    Host         => $host,
    HostKeyAlias => $host,
    HostName     => $addr,
    TCPKeepAlive => 'yes',
    User         => $ENV{'USER'},
  };

  foreach (split(/\s+/, $extra))
  {
    my ($key, $val) = split(/=/, $_);
    next unless (defined($val));

    if ($key eq 'forward')
    {
      my @fields = split(/:/, $val);
      $attrs->{forwards} ||= {};
      if (scalar @fields == 3)
      {
        $attrs->{forwards}->{$fields[0]} = "$fields[1]:$fields[2]";
        if ($global_port_register{$fields[0]})
        {
          die "line $line: port $fields[0] already allocated";
        }
        $global_port_register{$fields[0]}++;
      }
      else
      {

        # unique key that int() will return 0 for
        $attrs->{forwards}->{"x$line"} = "$fields[0]:$fields[1]";
      }
    }
    else
    {
      $attrs->{$key} = $val;
    }
  }

  $parent[0]->{$host} = {attrs => $attrs};
}

my $tunport = 20000;

while (<>)
{
  chomp;
  $line++;

  next if (/^\s*#/);    # skip comments
  s/\s*#.*//;

  if (/startport\s*=\s*(\d+)/)
  {
    $tunport = $1;
  }
  elsif (/(\S+)\s+(\S+)\s*(\S.*)?/)
  {
    my ($host, $addr, $extra) = ($1, $2, $3);
    add_host($1, $2, $3);

    if (/\{$/)
    {
      unshift(@parent, $parent[0]->{$host});
      $indent++;
    }
  }
  if (/\}$/)
  {
    shift(@parent);
    $indent--;
    die "line $line: neg indent?" if ($indent < 0);
  }
}

sub dump_config($)
{
  my ($hash_ref) = @_;

  my $attrs    = $hash_ref->{attrs};
  my $forwards = $attrs->{forwards};

  my $hostname = $attrs->{Host};
  print "Host $hostname\n";

  map { delete $hash_ref->{$_} } qw/attrs/;
  map { delete $attrs->{$_} } qw/forwards Host/;

  map { print "  $_ $attrs->{$_}\n" } (sort keys %{$attrs});

  if (defined($forwards))
  {
    foreach my $port (keys %{$forwards})
    {
      my $lport = int($port);
      if (!$lport)
      {
        while ($global_port_register{$tunport})
        {
          $tunport++;
        }
        $lport ||= $tunport;
        $tunport++;
      }
      print "  LocalForward $lport $forwards->{$port}\n";
    }
  }

  foreach my $host (sort keys %{$hash_ref})
  {
    my $child_attrs = $hash_ref->{$host}->{attrs};
    $child_attrs->{Port} ||= 22;

    print "  # $child_attrs->{Host}\n";
    print "  LocalForward $tunport "
      . $child_attrs->{HostName} . ":"
      . $child_attrs->{Port} . "\n";

    $child_attrs->{HostName} = 'localhost';
    $child_attrs->{Port}     = $tunport;
    $tunport++;
  }

  print "\n";

  map { dump_config($_) } (values %{$hash_ref});
}

foreach my $key (keys %{$host_tree})
{
  dump_config($host_tree->{$key});
}
