package Ark::Test;
use Mouse;

use HTTP::Request;
use HTTP::Engine;

sub import {
    my ($class, $app_class, @rest) = @_;
    my $caller = caller;

    my %option = @rest;

    Mouse::load_class($app_class) unless Mouse::is_class_loaded($app_class);

    my $persist_app = undef;

    {
        no strict 'refs';
        *{ $caller . '::request'} = sub {
            my $app;
            unless ($persist_app) {
                $app = $app_class->new;

                my @components = map { "${app_class}::${_}" }
                    @{ $option{components} || [] };
                $app->load_component($_) for @components;

                if ($option{minimal_setup}) {
                    $app->setup_home;
                    $app->path_to('action.cache')->remove;

                    my $child = fork;
                    if ($child == 0) {
                        $app->setup_minimal;
                        exit;
                    }
                    elsif (!defined($child)) {
                        die $!;
                    }

                    waitpid $child, 0;

                    $app->setup_minimal;
                }
                else {
                    $app->setup;
                }
            }

            if ($option{reuse_connection}) {
                if ($persist_app) {
                    $app = $persist_app;
                }
                else {
                    $persist_app = $app;
                }
            }

            my $req = ref($_[0]) eq 'HTTP::Request' ? $_[0] : HTTP::Request->new(@_);

            my $res = HTTP::Engine->new(
                interface => {
                    module          => 'Test',
                    request_handler => $app->handler,
                },
            )->run($req, env => \%ENV);

            $app->path_to('action.cache')->remove if $option{minimal_setup};

            $res;
        };

        *{ $caller . '::get' } = sub {
            &{$caller . '::request'}(GET => @_)->content;
        };

        *{ $caller . '::reset_app' } = sub {
            undef $persist_app;
        };
    }
}

1;

