package App::SmokeBox::PerlVersion;

#ABSTRACT: SmokeBox helper module to determine perl version

use strict;
use warnings;
use IPC::Cmd qw[can_run];
use POE qw[Quickie];

sub version {
  my $package = shift;
  my %args    = @_;
  $args{ lc $_ } = delete $args{$_} for keys %args;
  $args{perl} = $^X unless $args{perl} and can_run( $args{perl} );
  $args{session} = $poe_kernel->get_active_session()
    unless $args{session};

  unless ( $args{event} or $args{session}->isa('POE::Session::AnonEvent') ) {
     warn "You must provide response 'event' or a postback in 'session'\n";
     return;
  }

  my $self = bless \%args, $package;
  $self->{session_id} = POE::Session->create(
     object_states => [
        $self => [
            qw(_start _stdout _finished)
        ],
     ],
     heap => $self,
  )->ID();
  return $self;
}

sub _start {
  my ($kernel,$self) = @_[KERNEL,OBJECT];
  $self->{pid} = POE::Quickie->run(
    Program     => [ $self->{perl}, '-v' ],
    StdoutEvent => '_stdout',
    ExitEvent   => '_finished',
  );
  return;
}

sub _stdout {
  my ($self,$in,$pid) = @_[OBJECT,ARG0,ARG1];
  # This is perl, v5.6.2 built for i386-netbsd-thread-multi-64int
  return unless my ($vers,$arch) = $in =~ /^This is perl.+v([0-9\.]+).+built for\s+(\S+)$/;
  $self->{version} = $vers;
  $self->{archname} = $arch;
  return;
}

sub _finished {
  my ($kernel,$self,$code,$pid) = @_[KERNEL,OBJECT,ARG0,ARG1];
  my $return = { };
  $return->{exitcode} = $code;
  $return->{$_} = $self->{$_} for qw[version archname context];
  if ( $self->{session}->isa('POE::Session::AnonEvent') ) {
    $self->{session}->( $return );
  }
  else {
    $kernel->post( $self->{session}, $self->{event}, $return );
  }
  return;
}


q[This is true];

=pod

=head1 SYNOPSIS

  use strict;
  use warnings;
  use POE;
  use App::SmokeBox::PerlVersion;
  
  my $perl = shift || $^X;
  
  POE::Session->create(
    package_states => [
      main => [qw(_start _result)],
    ],
  );
  
  $poe_kernel->run();
  exit 0;
  
  sub _start {
    App::SmokeBox::PerlVersion->version(
      perl => $perl,
      event => '_result',
    );
    return;
  }
  
  sub _result {
    my $href = $_[ARG0];
    print "Perl version: ", $href->{version}, "\n";
    print "Built for:    ", $href->{archname}, "\n";
    return;
  }

=head1 DESCRIPTION

App::SmokeBox::PerlVersion is a simple helper module for L<App::SmokeBox::Mini> and
L<minismokebox> that determines and version and architecture of a given C<perl>
executable.

=head1 CONSTRUCTOR

=over

=item C<version>

Takes a number of arguments:

  'perl', the perl executable to query, defaults to $^X;
  'event', the event to trigger in the calling session on finish;
  'session', a POE Session, ID, alias or postback to send results to;
  'context', optional context data you want to provide;

C<event> is a mandatory argument unless C<session> is provided and is a L<POE> postback/callback.

=back

=head1 RESPONSE

An C<event> or C<postback> will be sent when the module has finished with a hashref of data.

For C<event> the hashref will be in C<ARG0>.

For C<postback> the hashref will be the first item in the arrayref of C<ARG1> in the C<postback>.

The hashref will contain the following keys:

  'exitcode', the exit code of the perl executable that was run;
  'version', the perl version string;
  'archname', the perl archname string;
  'context', whatever was passed to version();

=cut
