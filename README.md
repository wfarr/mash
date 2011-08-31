# Mash

Mash is automation for setting up a basic chef-server install.
I created it because setting up chef-server can be a pain in the ass if you're
say using an Ubuntu LTS release and don't want to use chef-server packages that
are forever and a day old.

## Prerequisites

Right now, Mash only supports Ubuntu.

The user configured in config/mash.yml *must* have password-less sudo privileges.

## Installing

Setting up Mash on your server is pretty simple!

* Clone it

```
git clone git://github.com/wfarr/mash.git
```

* Install the dependencies

```
gem install bundler
bundle install
```

* Update the config files

```
cp config/mash.yml.example config/mash.yml
vim config/mash.yml
```

* Go!

```
cap cowboy bootstrap
```

* Confirm?

```
knife client list
# success!
```
