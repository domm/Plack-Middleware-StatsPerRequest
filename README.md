# NAME

Plack::Middleware::StatsPerRequest - Measure HTTP stats on each request

# VERSION

version 0.042

# SYNOPSIS

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

# DESCRIPTION

`Plack::Middleware::StatsPerRequest` lets you measure your all your
HTTP requests via [Measure::Everything](https://metacpan.org/pod/Measure::Everything).

More docs & tests TODO as this is quick birthday release :-)

## Configuration

TODO

# SEE ALSO

TODO

# THANKS

Thanks to

- [validad.com](https://www.validad.com/) for supporting Open Source.

# AUTHOR

Thomas Klausner <domm@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2018 by Thomas Klausner.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
