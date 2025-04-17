FROM ruby:3.2-slim-bullseye

ENV PATH="/root/.local/bin:${PATH}"

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  libpq-dev python3-pip python3-setuptools git krb5-user krb5-config build-essential \
  && pip3 install wheel \
  && pip3 install --user \
  wheel pyOpenSSL cryptography idna certifi "urllib3[secure]" sqlparse

# Configure Git to handle hardlinks properly
RUN git config --global core.autocrlf input && \
  git config --global core.filemode false && \
  git config --global --add safe.directory /home/conceptql

RUN mkdir -p /home/conceptql/lib/conceptql
COPY Gemfile Gemfile.lock conceptql.gemspec /home/conceptql/
COPY lib/conceptql/version.rb /home/conceptql/lib/conceptql/
WORKDIR /home/conceptql

RUN apt-get install -y --no-install-recommends sqlite3 libsqlite3-dev ca-certificates fonts-liberation libappindicator3-1 libasound2 libatk-bridge2.0-0 libatk1.0-0 libc6 libcairo2 libcups2 libdbus-1-3 libdrm2 libexpat1 libfontconfig1 libgbm1 libgcc1 libglib2.0-0 libgtk-3-0 libnspr4 libnss3 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxkbcommon0 libxrandr2 libxrender1 libxss1 libxtst6 lsb-release wget xdg-utils

# Configure Bundler to use HTTPS for GitHub and handle Git repositories properly
RUN bundle config github.https true && \
  bundle config --global git.allow_insecure true && \
  bundle config --global build.nokogiri --use-system-libraries && \
  bundle install -j 5

COPY . ./

CMD ["bash"]