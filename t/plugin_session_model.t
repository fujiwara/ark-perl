use Test::Base;

{
    package T1;
    use Ark;

    use_plugins qw/
        Session
        Session::State::Cookie
        Session::Store::Model
        /;

    conf 'Plugin::Session::Store::Model' => {
        model => 'Session',
    };

    conf 'Model::Session' => {
        class => 'Cache::MemoryCache',
        args  => {
            namespace          => 'session',
            default_expires_in => 24*60 * 1,
        },
    };

    package T1::Model::Session;
    use Ark 'Model::Adaptor';

    package T1::Controller::Root;
    use Ark 'Controller';

    has '+namespace' => default => '';

    sub test_set :Local {
        my ($self, $c) = @_;
        $c->session->set('test', 'testdata');
    }

    sub test_get :Local {
        my ($self, $c) = @_;
        $c->res->body( $c->session->get('test') );
    }

    sub incr :Local {
        my ($self, $c) = @_;

        my $count = $c->session->get('count') || 0;
        $c->session->set( count => ++$count );

        $c->res->body( $count );
    }
}

plan 'no_plan';

use Ark::Test 'T1',
    components => [qw/Controller::Root Model::Session/],
    reuse_connection => 1;

{
    my $res = request(GET => '/test_set');
    like( $res->header('Set-Cookie'), qr/t1_session=/, 'session id ok');

    is(get('/test_get'), 'testdata', 'session get ok');
}

{
    is(get('/incr'), 1, 'increment first ok');
    is(get('/incr'), 2, 'increment second ok');
    reset_app;

    is(get('/incr'), 1, 're-increment first ok'); # XXX: this is test for Ark::Test: should be sepalate test.
    is(get('/incr'), 2, 're-increment second ok');
}