# rspec_mock_api_server
Simple mock API server for rspec tests not run via a controller test

Inspired from [this mock_access_token_server](https://github.com/cerner/cerner-oauth1a/blob/931fa2d780c988fcf2ced769ebce9fe9d1792f2a/spec/mock_access_token_server.rb), only general purpose.

## Usage

First, copy [the mock api server](./mock_api_server.rb) into your rspec directory.
(Side note: I may release this as a gem in future, but I don't think it's necessary right now)

Next, in your spec file, let's setup the mock server 😀:

```ruby
# include the mock_api_server for this test
require 'mock_api_server'

describe My::ApiClass::Here do
  # need to define your mock server implementation and start it here
  before(:all) do
    # define the routes that you'll mount for this server
    paths = [
      {
        path: '/some-api-call-here',
        options: {
          # let's set up route that depends on the request's query params!
          response: lambda do |request|
            foo = request.query['foo']
            
            # build some body that depends on the query param...
            body =
              if foo.present?
                'I pity the foo!'
              else
                'foo who?'
              end
            
            # return the response!
            {
              status: 200,
              headers: {
                'Content-Type' => 'text/plain'
              },
              body: body
            }
          end
        }
    ]
    
    # create your mock server with the defined routes from above...
    @mock_server = MockApiServer.new(paths: paths)
    
    # now, start the server! 🚀
    @mock_server.start
  end
  
  # be sure to clean up your resources: shutdown your mock server!
  after(:all) do
    @mock_server.shutdown
  end
end
```

Let's say your `My::ApiClass::Here` has a method called `get_foo`,

```ruby
module My
  module ApiClass
    class Here
      def intialize(url: 'http://my.api-base-url.com')
        @url = url
      end

      def get_foo(foo)
        # let's use faraday for example
        connection = Faraday.new(url: @url)
        connection.get(
          '/some-api-call-here' # same as the route we mounted in the mock api server 👀
          { foo: foo }
        )
      end
    end
  end
end
```

So in your spec file, let's add an example test that will hit this route!

```ruby
describe My::ApiClass::Here do
  # ... other stuff from before

  describe '#get_foo'
    let(:my_apiclass_here) { described_class.new(url: 'localhost') }

    context "when the foo exists (ain't falsey)" do
      # make our foo truthy so we hit /some-api-call-here?foo=true and return
      # 'I pity the foo!'
      let(:foo) { true }
      
      it 'returns "I pity the foo!"' do
        expect(my_apiclass_here.get_foo(foo)).to eq 'I pity the foo!'
      end
    end

    context 'when the foo does not exist (is falsey)' do
      # make our foo falsey so we hit /some-api-call-here?foo=false and return
      # 'foo who?'
      let(:foo) { false }

      it 'returns "foo who?"' do
        expect(my_apiclass_here.get_foo(foo)).to eq 'foo who?'
      end
    end
  end
end
```
