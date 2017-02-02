FROM node:6.9-slim
EXPOSE 8000
MAINTAINER Jean-Christophe Hoelt <hoelt@fovea.cc>
RUN useradd app -d /home/app

COPY package.json /home/app/code/package.json
RUN cd /home/app/code && npm install

COPY .eslintrc .eslintignore coffeelint.json Makefile index.js config.js newrelic.js run_tests.sh /home/app/code/
COPY tests /home/app/code/tests
COPY src /home/app/code/src

RUN chown -R app /home/app

WORKDIR /home/app/code
USER app
CMD node_modules/.bin/forever index.js

ENV API_SECRET=1234
