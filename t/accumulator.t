# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket 'no_plan';
use Cwd qw(cwd);

my $pwd = cwd();
our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;/usr/local/openresty/lualib/?.lua";
};

run_tests();

__DATA__

=== TEST 1: reply to single request after timeout
--- http_config eval: $::HttpConfig
--- config
lua_code_cache on;

location /t {
    default_type text/html;
    content_by_lua_block {
        if not package.loaded.accumulator_func then
            local accumulator = require "resty.batch.accumulator"
            local f = accumulator.new(3, 0.2, function(tasks)
                return tasks
            end)
            package.loaded.accumulator_func = f
        end
        local input = ngx.req.get_uri_args().input
        ngx.say(package.loaded.accumulator_func(input))
    }
}
--- request
GET /t?input=foo
--- response_body
foo
--- error_code: 200

=== TEST 2: don't hang if task=nil
--- http_config eval: $::HttpConfig
--- config
lua_code_cache on;
location /t {
    default_type text/html;
    content_by_lua_block {
        local accumulator = require "resty.batch.accumulator"
        local f = accumulator.new(3, 0.2, function(tasks)
            return tasks
        end)
        f()
    }
}
--- request
GET /t
--- error_code: 500
