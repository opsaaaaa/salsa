rails db:environment:set RAILS_ENV=test
xvfb-run -a cucumber RAILS_ENV=test $1
EXIT_CODE=$?
rm -rf /tmp/.X*-lock
exit $EXIT_CODE
