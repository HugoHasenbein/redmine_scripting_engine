# base docker image
FROM ruby:2.7

# install base programs; adapt to your needs
RUN apt-get -qq -y update && \
    apt-get -qq -y install apt-utils && \
    apt-get -qq -y install jq libjson-perl libio-all-perl tcc ghostscript && \
    echo "deb-src http://deb.debian.org/debian buster main" >> /etc/apt/sources.list && \
    apt-get -qq -y update && \
    apt-get -qq -y build-dep imagemagick && \
    apt-get -qq -y install imagemagick && \
    apt-get -qq -y install sysvbanner
    
# set user and group
RUN useradd -m -d /home/sandbox sandbox

# set user and group
USER sandbox
WORKDIR /home/sandbox

# install bundler with current user to fetch gems
RUN gem install bundler

# create mount point where to mount files to execute
RUN mkdir /home/sandbox/src

# add Gemfile and bunle config file for rails 
ADD --chown=sandbox Gemfile /home/sandbox/Gemfile
ADD --chown=sandbox bundle_config /home/sandbox/.bundle/config
ADD --chown=sandbox run.rb /home/sandbox/run.rb

# eventually install gems for user sandbox
RUN bundle install



