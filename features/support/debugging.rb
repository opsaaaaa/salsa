After do |scenario|
  visit('/admin/logout')
  Capybara.reset_sessions!
  save_page if scenario.failed?
end
