FROM alpine:3

RUN mkdir -p /home/conceptql/lib/conceptql
COPY dockers/sqlite/Makefile.patch .
COPY Gemfile Gemfile.lock conceptql.gemspec /home/conceptql/
COPY lib/conceptql/version.rb /home/conceptql/lib/conceptql/
RUN apk add --no-cache curl gcc build-base abuild zstd ruby-dev ruby-bundler git libpq postgresql-dev perl \
  && curl "https://www.sqlite.org/2020/sqlite-autoconf-3310100.tar.gz" | tar zxvf -  \
  && cd sqlite-autoconf-3310100 \
  && ./configure \
  && patch -p0 < ../Makefile.patch \
  && make install \
  && cd .. \
  && git clone https://github.com/darold/pgFormatter.git \
  && cd pgFormatter \
  && perl Makefile.PL \
  && make install
WORKDIR /home/conceptql
RUN bundle install
