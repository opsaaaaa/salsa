module TaskHelper
  
  def ask say
    say say
    STDIN.gets.strip
  end

  def say say
    STDOUT.puts say
  end

  def respond_to_input question, &response
    response.call ask question
  end

  def find_org **args
    # TODO: Organization.find_org_by_path
    Organization.find_by args
  end

  def yes? str
    str.downcase == 'yes' || str.downcase == 'y'
  end

  def respond_to_yes msg, &response
    respond_to_input( msg ) do |awnser|
      response.call if yes? awnser
    end
  end

end