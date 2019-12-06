# frozen_string_literal: true

require 'webrick'

# General purpose mock API server inspired by:
# https://github.com/cerner/cerner-oauth1a/blob/931fa2d780c988fcf2ced769ebce9fe9d1792f2a/spec/mock_access_token_server.rb
class MockApiServer
  class Servlet < WEBrick::HTTPServlet::AbstractServlet
    def initialize(server, options = {})
      super(server)
      @options = options
    end

    def do_GET(request, response) # rubocop:disable Naming/MethodName
      do_POST(request, response)
    end

    def do_POST(request, response) # rubocop:disable Naming/MethodName
      # get the response as a hash from the spec, fallback to an empty hash
      # call the lambda with the request if given one, else assume the spec
      # returns a hash
      response_hash =
        if @options[:response].respond_to? :call
          @options[:response].call(request)
        else
          @options[:response] || {}
        end

      response.status = response_hash[:status] if response_hash[:status]
      response_hash[:headers]&.each { |key, value| response[key] = value }
      response.body = response_hash[:body]
    end
  end

  def initialize(paths: [], port: 0)
    @http_server = WEBrick::HTTPServer.new(Port: port)
    paths.each do |path:, options:|
      @http_server.mount(path, Servlet, options)
    end
    @pid = nil
  end

  def base_uri
    "http://localhost:#{@http_server.config[:Port]}"
  end

  def startup
    raise StandardError, 'server has already been started' if @pid

    @pid =
      fork do
        trap('TERM') do
          @http_server.shutdown
          @pid = nil
        end
        trap('INT') do
          @http_server.shutdown
          @pid = nil
        end
        @http_server.start
      end
  end

  def shutdown
    return unless @pid

    Process.kill('TERM', @pid)
    Process.wait(@pid)
    @pid = nil
  end
end
