FROM phusion/passenger-ruby24:0.9.27

RUN apt-get update
RUN apt-get install -y wget python
RUN wget https://bootstrap.pypa.io/get-pip.py
RUN python get-pip.py
RUN pip install --upgrade sqlparse
RUN ruby --version

ENV INSTALL_PATH /home/app
WORKDIR $INSTALL_PATH
COPY . ./

RUN grep -iv "\(pg\|sequel-impala\)" Gemfile > Gemfile.temp
RUN echo 'gem "pg"' >> Gemfile.temp
RUN echo 'gem "sequel-impala", github: "outcomesinsights/sequel-impala", branch: "master"' >> Gemfile.temp
RUN mv Gemfile.temp Gemfile

RUN gem install bundler
RUN bundle install --jobs=4 --retry=3
