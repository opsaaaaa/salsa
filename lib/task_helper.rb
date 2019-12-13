
def self.ask say
  say say
  STDIN.gets.strip
end

def self.say say
  STDOUT.puts say
end

def respond_to question, &response
  response.call ask question
end

def find_org **args
  # TODO: Organization.find_org_by_path
  Organization.find_by args
end
