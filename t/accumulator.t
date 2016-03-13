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
        local accumulator = require "resty.batch.accumulator"
        local f = accumulator.new(3, 0.2, function(tasks)
            return tasks
        end)
        local input = ngx.req.get_uri_args().input
        ngx.say(f(input))
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

=== TEST 3: doesn't response too early
--- http_config eval: $::HttpConfig
--- config
lua_code_cache on;
listen 22318;
location /t {
    content_by_lua_block {
        local accumulator = require "resty.batch.accumulator"
        local f = accumulator.new(3, 0.2, function(tasks)
            return tasks
        end)
        local input = ngx.req.get_uri_args().input
        ngx.say(f(input))
    }
}

location /t2 {
    content_by_lua_block {
        local sock = ngx.socket.tcp()
        sock:settimeout(100)
        assert(sock:connect("127.0.0.1", 22318))
        assert(sock:send("GET /t?input=foo HTTP/1.1\r\n" ..
            "Host: 127.0.0.1\r\n\r\n"))
        local ok, err = sock:receive(10)
        if not ok then
            ngx.log(ngx.ERR, "failed to receive: ", err)
            return ngx.exit(500)
        end
    }
}
--- timeout: 3
--- request
GET /t2
--- response_body_like: 500 Internal Server Error
--- error_code: 500
--- error_log
failed to receive: timeout
