FROM ruby

WORKDIR /usr/local/src

ADD . .

RUN bundle install