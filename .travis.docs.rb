require 'net/http'
require 'optparse'
require 'uri'
require 'json'


# Configure script launch options.
options = {}
OptionParser.new do |parser|
  parser.banner = 'Usage: .travis.docs.rb [options]'

  parser.on('-d', '--docs [FLAG]', 'Enable docs generation.') do |v|
    options[:docs] = %w[1 true].include? v
  end

  parser.on('-t', '--token TOKEN', 'Travis REST API access token.') do |v|
    options[:token] = v
  end
end.parse!

# Check whether script able and should trigger docs build if possible.
is_able_to_create_docs = options[:docs] == true && (options.key? :token)

# Gather information about repository and last commit.
changes_in_commit = `git diff --name-only HEAD~1 HEAD`
has_changes = `git diff --name-only HEAD~1 HEAD | grep '^snippets/' -c`.to_i > 0
should_skip_docs = `git log -1 --pretty=%B | grep -F '[skip docs]' -c`.to_i > 0
is_master = `git symbolic-ref --short HEAD | grep '^master' -c`.to_i > 0
branch_name = `git symbolic-ref --short HEAD`

puts "Branch name: #{branch_name}. Is master? #{is_master}"
puts "Has changes? #{has_changes}. Diff: #{changes_in_commit}"
puts "Should skip docs? #{should_skip_docs}"
puts "Able to create docs? #{is_able_to_create_docs}. Docs flag: #{options[:docs]}"

# Skip documents generation in case if one of following requests not met:
#   - Script has been launched with '--token TOKEN'
#   - Script has been launched with '--docs 1'
#   - Script called from master branch
#   - There is no '[skip docs]' in last commit message
#   - There is changes in folders which tracked for docs update.
if !is_able_to_create_docs || !is_master || should_skip_docs || !has_changes
  puts 'Skip docs generation'
  exit 0
end

puts 'Push docs build job'

# Compose request to create new build for 'chat-resource-center' repository.
uri = URI.parse('https://api.travis-ci.org/repo/pubnub%2Fchat-resource-center/requests')
request_data = { request: { branch: 'master' } }
headers = {
  'Content-Type': 'application/json',
  'Travis-API-Version': '3',
  'Authorization': "token #{options[:token]}"
}

http = Net::HTTP.new(uri.host)
request = Net::HTTP::Post.new(uri.request_uri, headers)
request.body = request_data.to_json

# Make call to Travis REST API to push new build for 'chat-resource-center'.
http.request(request)
