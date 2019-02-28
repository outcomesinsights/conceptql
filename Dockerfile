FROM ruby:2.4.5-stretch

WORKDIR /app

ENV PATH="/root/.local/bin:${PATH}"

RUN apt-get update && apt-get install -y --no-install-recommends \
  libpq-dev python-pip python-setuptools git \
  && pip install --user \
  pyOpenSSL cryptography idna certifi "urllib3[secure]" sqlparse

COPY .travis.gemfile ./
RUN bundle install --gemfile .travis.gemfile

CMD ["bash"]
