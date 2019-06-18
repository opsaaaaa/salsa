FROM ruby:2.5.0

# set the app directory var
ENV APP_HOME /home/apps/salsa
WORKDIR $APP_HOME

RUN apt-get update  && apt-get install -y build-essential libpq-dev nodejs libqt5webkit5-dev qt5-default cmake make xvfb
RUN gem install bundler

COPY salsa/Gemfile* ./
RUN bundle install
ADD . .
