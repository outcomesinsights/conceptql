# bookworm: bullseye (Debian 11) LTS ended 2026-08-31 and its security repo now 404s.
FROM ruby:3.4-slim-bookworm

ENV PATH="/root/.local/bin:${PATH}"

# Debian's package versions change with each point release, so exact pins would break the
# build. The base image tag fixes the Debian release instead.
# hadolint ignore=DL3008
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  libpq-dev git krb5-user krb5-config build-essential pkg-config libyaml-dev \
  sqlformat \
  && rm -rf /var/lib/apt/lists/*

# Configure Git to handle hardlinks properly
RUN git config --global core.autocrlf input && \
  git config --global core.filemode false && \
  git config --global --add safe.directory /home/conceptql

RUN mkdir -p /home/conceptql/lib/conceptql
COPY Gemfile Gemfile.lock conceptql.gemspec /home/conceptql/
COPY lib/conceptql/version.rb /home/conceptql/lib/conceptql/
WORKDIR /home/conceptql

# Same reason as above.
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends sqlite3 libsqlite3-dev ca-certificates fonts-liberation libayatana-appindicator3-1 libasound2 libatk-bridge2.0-0 libatk1.0-0 libc6 libcairo2 libcups2 libdbus-1-3 libdrm2 libexpat1 libfontconfig1 libgbm1 libgcc-s1 libglib2.0-0 libgtk-3-0 libnspr4 libnss3 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxkbcommon0 libxrandr2 libxrender1 libxss1 libxtst6 lsb-release wget xdg-utils \
  && rm -rf /var/lib/apt/lists/*

# Configure Bundler to use HTTPS for GitHub and handle Git repositories properly
RUN bundle config github.https true && \
  bundle config --global git.allow_insecure true && \
  bundle config --global build.nokogiri --use-system-libraries && \
  bundle install -j 5

COPY . ./

CMD ["bash"]
