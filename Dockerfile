FROM ruby:2.4.5-stretch

WORKDIR /app

ENV PATH="/root/.local/bin:${PATH}"

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  libpq-dev python-pip python-setuptools git krb5-user krb5-config \
  && pip install --user \
  pyOpenSSL cryptography idna certifi "urllib3[secure]" sqlparse

COPY .travis.gemfile ./
RUN bundle install --gemfile .travis.gemfile

CMD ["bash"]
