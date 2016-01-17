require 'sinatra'
require "sinatra/cookies"
require 'ims/lti'
require 'ims/lti/extensions'
require 'json'

# must include the oauth proxy object
require 'oauth/request_proxy/rack_request'

enable :sessions, :static
set :protection, :except => :frame_options

get '/' do
  erb :index
end

get '/1' do
  cookies[:third_party_c_t] = 'dummyValue'
  redirect to('/first')
end

get '/first' do
  content_type 'text/javascript'
  erb :first
end

get '/2' do
  cookie_received = cookies[:third_party_c_t]
  @cookie_str = cookie_received
  if cookie_received.to_s.strip.length == 0
    # It's nil, empty, or just whitespace
    @cookie_value = 'false'
  else
    @cookie_value = 'true'
  end
  cookies[:third_party_c_t] = ''

  content_type 'text/javascript'
  erb :second
end

# the consumer keys/secrets
$oauth_creds = {"test" => "secret", "testing" => "supersecret"}

def show_error(message)
  @message = message
end

def authorize!
  if key = params['oauth_consumer_key']
    if secret = $oauth_creds[key]
      @tp = IMS::LTI::ToolProvider.new(key, secret, params)
    else
      @tp = IMS::LTI::ToolProvider.new(nil, nil, params)
      @tp.lti_msg = "Your consumer didn't use a recognized key."
      @tp.lti_errorlog = "You did it wrong!"
      show_error "Consumer key wasn't recognized"
      return false
    end
  else
    show_error "No consumer key"
    return false
  end

  if !@tp.valid_request?(request)
    show_error "The OAuth signature was invalid"
    return false
  end

  if Time.now.utc.to_i - @tp.request_oauth_timestamp.to_i > 60*60
    show_error "Your request is too old."
    return false
  end

  # this isn't actually checking anything like it should, just want people
  # implementing real tools to be aware they need to check the nonce
  if was_nonce_used_in_last_x_minutes?(@tp.request_oauth_nonce, 60)
    show_error "Why are you reusing the nonce?"
    return false
  end

  @username = @tp.username("Dude")

  return true
end

# The url for launching the tool
# It will verify the OAuth signature
post '/lti_tool' do
  return erb :error unless authorize!

  if ['pe', 'av', 'ka', 'module'].include? params["problem_type"]
    @JSAV_html = html params["short_name"]
  end
  erb :static_content
end

def html(view)
  if params["problem_type"] == 'module'
    File.read(File.join('public/OpenDSA/Books/', params["problem_url"], '/lti_html/', "#{view.to_s}.html"))
  else
    File.read(File.join('public/OpenDSA/', params["problem_url"], '/html/', "#{view.to_s}.html"))
  end
end

post '/signature_test' do
  erb :proxy_setup
end

post '/proxy_launch' do
  uri = URI.parse(params['launch_url'])

  if uri.port == uri.default_port
    host = uri.host
  else
    host = "#{uri.host}:#{uri.port}"
  end

  consumer = OAuth::Consumer.new(params['lti']['oauth_consumer_key'], params['oauth_consumer_secret'], {
      :site => "#{uri.scheme}://#{host}",
      :signature_method => "HMAC-SHA1"
  })

  path = uri.path
  path = '/' if path.empty?

  @lti_params = params['lti'].clone
  if uri.query != nil
    CGI.parse(uri.query).each do |query_key, query_values|
      unless @lti_params[query_key]
        @lti_params[query_key] = query_values.first
      end
    end
  end

  path = uri.path
  path = '/' if path.empty?

  proxied_request = consumer.send(:create_http_request, :post, path, @lti_params)
  signature = OAuth::Signature.build(proxied_request, :uri => params['launch_url'], :consumer_secret => params['oauth_consumer_secret'])

  @signature_base_string = signature.signature_base_string
  @secret = signature.send(:secret)
  @oauth_signature = signature.signature

  erb :proxy_launch
end

# post the assessment results
post '/assessment', :provides => :json do
  content_type :json

  request_params = JSON.parse(request.body.read.to_s)
  launch_params = request_params['launch_params']
  if launch_params
    key = launch_params['oauth_consumer_key']
  else
    show_error "The tool never launched"
    return erb :error
  end

  @tp = IMS::LTI::ToolProvider.new(key, $oauth_creds[key], launch_params)

  if !@tp.outcome_service?
    show_error "This tool wasn't lunched as an outcome service"
    return erb :error
  end

  # post the given score to the TC
  score = (request_params['score'] != '' ? request_params['score'] : nil)
  res = @tp.post_replace_result!(score)

  if res.success?
    # @score = request_params['score']
    # @tp.lti_msg = "Message shown when arriving back at Tool Consumer."
    { :message => 'success' }.to_json
    # erb :assessment_finished
  else
    { :message => 'failure' }.to_json
    # @tp.lti_errormsg = "The Tool Consumer failed to add the score."
    # show_error "Your score was not recorded: #{res.description}"
    # return erb :error
  end
end

get '/tool_config.xml' do

  host = request.scheme + "://" + request.host_with_port
  url = (params['signature_proxy_test'] ? host + "/signature_test" : host + "/lti_tool")
  tc = IMS::LTI::ToolConfig.new(:title => "Example Sinatra Tool Provider", :launch_url => url)
  tc.extend IMS::LTI::Extensions::Canvas::ToolConfig
  tc.description = "This example LTI Tool Provider supports LIS Outcome pass-back."
  tc.canvas_privacy_public!

  headers 'Content-Type' => 'text/xml'
  tc.to_xml(:indent => 2)
end

def was_nonce_used_in_last_x_minutes?(nonce, minutes=60)
  # some kind of caching solution or something to keep a short-term memory of used nonces
  false
end
