#!/usr/bin/perl -w
#
# Generate SSH config files with tunnels support
# This version makes use of dynamic (socks) forwards.
# If you find that you have trouble with any tools that use
# your ssh config files (eg. programming libraries such
# as fabric) then try the static ports version of this program.
#
# Alexander Else. aelse@github

use Data::Dumper;

my $host_tree = {};
my @parent    = ($host_tree);
my $indent    = 0;
my $line      = 0;
my %global_port_register;

my $tunport     = 20000;
my $socksport   = 1081;
my $socks_stack = ();

sub add_host(@)
{
  my ($host, $addr, $extra, $socks_listen) = @_;

  my $attrs = {
    Host         => $host,
    HostKeyAlias => $host,
    HostName     => $addr,
    TCPKeepAlive => 'yes',
    User         => $ENV{'USER'},
  };

  if ($socks_listen)
  {
    $attrs->{'DynamicForward'} = $socks_listen;
  }

  if ($#socks_stack != -1)
  {
    $attrs->{'ProxyCommand'} =
      "/bin/nc -x localhost:" . $socks_stack[-1] . " %h %p";
  }

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

    if (/\{$/)
    {
      add_host($host, $addr, $extra, $socksport);
      push(@socks_stack, $socksport);
      $socksport++;

      unshift(@parent, $parent[0]->{$host});
      $indent++;
    }
    else
    {
      add_host($host, $addr, $extra, 0);
    }
  }
  if (/\}$/)
  {
    shift(@parent);
    $indent--;
    die "line $line: neg indent?" if ($indent < 0);
    pop(@socks_stack);
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

  print "\n";

  map { dump_config($_) } (values %{$hash_ref});
}

foreach my $key (keys %{$host_tree})
{
  dump_config($host_tree->{$key});
}
