package Plack::Middleware::StatsPerRequest;

# ABSTRACT: Measure HTTP stats on each request

our $VERSION = '0.042';

use strict;
use warnings;
use 5.010;
use Time::HiRes qw();

use parent 'Plack::Middleware';
use Plack::Util::Accessor qw( app_name metric_name path_cleanups add_headers long_request );
use Plack::Request;
use Log::Any qw($log);
use Measure::Everything qw($stats);
use HTTP::Headers::Fast;

sub prepare_app {
    my $self = shift;

    $self->app_name('unknown') unless $self->app_name;
    $self->metric_name('http_request') unless $self->metric_name;
    $self->path_cleanups([\&replace_idish]) unless $self->path_cleanups;
    $self->long_request(5) unless defined $self->long_request;
}

sub call {
    my $self = shift;
    my $env  = shift;

    my $t0 = [Time::HiRes::gettimeofday];

    my $res = $self->app->($env);

    return Plack::Util::response_cb(
        $res,
        sub {
            my $res = shift;
            my $req;

            my $elapsed = Time::HiRes::tv_interval($t0);
            $elapsed = sprintf( '%5f', $elapsed ) if $elapsed < .0001;

            my $path = $env->{PATH_INFO};
            foreach my $callback (@{$self->path_cleanups}) {
                $path = $callback->($path);
            }

            my %tags = (
                status => $res->[0],
                method => $env->{REQUEST_METHOD},
                app    => $self->app_name,
                path   => $path,
            );
            if (my $headers_to_add = $self->add_headers) {
                foreach my $header (@$headers_to_add) {
                    $req = Plack::Request->new( $env );
                    $tags{'header_'.lc($header)} = $req->header($header) // 'not_set';
                }
            }

            eval {
                $stats->write(
                    $self->metric_name,
                    { request_time => $elapsed, hit => 1 },
                    \%tags
                );
                if ( $self->long_request &&  $elapsed > $self->long_request ) {
                    $req ||= Plack::Request->new($env);
                    $log->warnf(
                        "Long request, took %f: %s %s",
                        $elapsed,
                        $req->method,
                        $req->request_uri
                    );
                }
            };
            if ($@) {
                $log->errorf( "Could not write stats: %s", $@ );
            }
        }
    );
}

=method replace_idish

  my $clean = Plack::Middleware::StatsPerRequest::replace_idish( $dirty );

Takes a URI path and replaces things that look like ids with fixed
strings, so you can calc proper stats on the generic paths.

This is the default L<path_cleanups> action, so unless you specify
your own, or explicitly set L<path_cleanups> to an empty array, the
following transformations will be done on the path:

=over

=item * A path fragment looking like a SHA1 checksum is replaced by
C<:sha1>

=item * A path fragment looking like a UUID is replaced by C<:uuid>

=item * Any part of the path consisting of 6 or more digits is
replaced by C<:int>

=item * A path fragment consisting solely of digits is also replaced
by C<:int>

=item * A path fragment looking like hex is replaced by C<:hex>

=item * A path fragment longer than 55 characters is replaced by
C<:long>

=item * A chain of path fragments looking like hex is replaced by
C<:hexpath>

=item * A path fragment looking like an email message id (as generated
by one of our tools) is replaced by C<:msgid>

=item * A path fragment looking like C<300x200> is replaced by
C<:imgdim>

=back

For details, please inspect the source code and
F<t/20_replace_idish.t>.

These transformations proved useful in the two years we used
C<Plack::Middleware::StatsPerRequest> in house. If you have any
additions or change requests, just tell us!

=cut

sub replace_idish {
    my $path = shift;
    $path = lc($path . '/');

    $path =~ s{/[a-f0-9\-.]+\@[a-z0-9\-.]+/}{/:msgid/}g;
    $path =~ s{/[a-f0-9]+\/[a-f0-9\/]+/}{/:hexpath/}g;

    $path =~ s([a-f0-9]{40})(:sha1)g;
    $path =~ s([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})(:uuid)g;
    $path =~ s(\d{6,})(:int)g;
    $path =~ s{\d+x\d+}{:imgdim}g;

    $path =~ s{/\d+/}{/:int/}g;
    $path =~ s(/[^/]{55,}/)(/:long/)g;
    $path =~ s(/[a-f0-9\-]{8,}/)(/:hex/)g;

    return substr($path, 0, -1);
}

42;

__END__

=head1 SYNOPSIS

  use Plack::Builder;
  use Measure::Everything::Adapter;
  Measure::Everything::Adapter->set('InfluxDB::File', {
      file => '/tmp/yourapp.stats',
  });


  builder {
      enable "Plack::Middleware::StatsPerRequest",
          app_name => 'YourApp',
      ;
      $app;
  };

  # curl http://localhost:3000/some/path
  # cat /tmp/yourapp.stats
    http_request,app=YourApp,method=GET,path=/some/path,status=400 hit=1i,request_time=0.02476 1519658691411352000


=head1 DESCRIPTION

C<Plack::Middleware::StatsPerRequest> lets you measure your all your
HTTP requests via L<Measure::Everything>.

More docs & tests TODO as this is quick birthday release :-)

=head2 Configuration

TODO

=head1 SEE ALSO

TODO

=head1 THANKS

Thanks to

=over

=item *

L<validad.com|https://www.validad.com/> for supporting Open Source.

=back


