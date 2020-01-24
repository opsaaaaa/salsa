bundle exec rails db:environment:set RAILS_ENV=test
RAILS_ENV=test
xvfb-run -a bundle exec rspec $1
EXIT_CODE=$?
rm -rf /tmp/.X*-lock
exit $EXIT_CODE
