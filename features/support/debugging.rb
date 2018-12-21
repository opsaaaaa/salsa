After do |scenario|
  Capybara.reset_sessions!
  save_page if scenario.failed?
end
