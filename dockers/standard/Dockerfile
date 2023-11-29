FROM ruby:3.2-slim-bullseye

ENV PATH="/root/.local/bin:${PATH}"

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  libpq-dev python3-pip python3-setuptools git krb5-user krb5-config build-essential \
  && pip3 install wheel \
  && pip3 install --user \
  wheel pyOpenSSL cryptography idna certifi "urllib3[secure]" sqlparse

RUN mkdir -p /home/conceptql/lib/conceptql
COPY Gemfile Gemfile.lock conceptql.gemspec /home/conceptql/
COPY lib/conceptql/version.rb /home/conceptql/lib/conceptql/
WORKDIR /home/conceptql
RUN apt-get install -y --no-install-recommends sqlite3 libsqlite3-dev
RUN ls && bundle config github.https true && bundle install -j 5

COPY . ./

CMD ["bash"]