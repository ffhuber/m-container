docker-moodle
=============

A Dockerfile that installs the latest Moodle, Apache, PHP, MySQL and SSH

## Installation

```
git clone git@github.com:ffhuber/m-container.git
cd m-container
docker build -t moodle .
```

## Usage

To spawn a new instance of Moodle:

```
docker run --name moodlec -e VIRTUAL_HOST=moodle.domain.com -d -t -p 80:80 -p 22 moodle
```

You can visit the following URL in a browser to get started:

```
http://moodle.domain.com/moodle
```
