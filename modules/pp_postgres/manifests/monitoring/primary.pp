class pp_postgres::monitoring::primary {
  include('pp_postgres::monitoring::base')

  postgresql::server::role { 'monitoring':
    login         => true,
    password_hash => postgresql_password('monitoring', 'monitoring'),
  }
  postgresql::server::database_grant { 'GRANT monitoring - CONNECT - stagecraft':
    privilege => 'CONNECT',
    db        => 'stagecraft',
    role      => 'monitoring',
  }
  # Create procedure to check replication status if it does not exist already
  postgresql_psql{'collectd-postgres-replication-status-function':
    command => template('pp_postgres/collectd-query-replication-status.sql.erb'),
    unless  => 'SELECT 1 FROM pg_catalog.pg_proc p WHERE p.proname = \'streaming_slave_check\' AND pg_catalog.pg_function_is_visible(p.oid)',
  }
  collectd::plugin::postgresql::query{'replication_lag':
    statement => 'SELECT client_hostname, byte_lag FROM streaming_slave_check();',
    results   => [{
      type           => 'gauge',
      instanceprefix => 'replication_lag',
      instancesfrom  => 'client_hostname',
      valuesfrom     => 'byte_lag',
    }],
  }
  collectd::plugin::postgresql::database{'stagecraft':
    user     => 'monitoring',
    password => 'monitoring',
    host     => 'localhost',
    query    => ['query_plans', 'queries', 'table_states', 'disk_io'],
  }
  collectd::plugin::postgresql::database{'postgres':
    user     => 'monitoring',
    password => 'monitoring',
    host     => 'localhost',
    query    => ['replication_lag'],
  }

  # Primary should have 5 processes for normal running; main, writer, wal writer, autovacuum launcher, stats collector
  #   and an additional process for replication; wal sender
  sensu::check { 'postgres_is_down':
    command  => '/etc/sensu/community-plugins/plugins/processes/check-procs.rb -p postgres -C 5 -W 5',
    interval => 60,
    handlers => ['default'],
  }
}
