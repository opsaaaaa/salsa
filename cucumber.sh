bundle exec rails db:environment:set RAILS_ENV=test
xvfb-run -a bundle exec cucumber $1 RAILS_ENV=test
EXIT_CODE=$?
rm -rf /tmp/.X*-lock
exit $EXIT_CODE
