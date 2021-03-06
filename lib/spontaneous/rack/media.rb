# encoding: UTF-8

require 'rack'

module Spontaneous::Rack
  class XXX < ::Rack::File
    include HTTP

    TEN_YEARS = 10*365*24*3600
    MAX_AGE =  "max-age=#{TEN_YEARS}, public".freeze

    def initialize(file_root)
      super(file_root, 'public')
    end

    def call(env)
      status, headers, body = super
      [status, caching_headers(headers), body]
    end

    # media is never over-written so we can make sure clients
    # never make the same request twice
    def caching_headers(headers)
      headers.merge({
        HTTP_CACHE_CONTROL => MAX_AGE,
        HTTP_EXPIRES => (Time.now + TEN_YEARS).httpdate
      })
    end
  end
end
