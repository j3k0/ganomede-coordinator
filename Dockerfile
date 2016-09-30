FROM node:0.10.45-slim
EXPOSE 8000
MAINTAINER Jean-Christophe Hoelt <hoelt@fovea.cc>
RUN useradd app -d /home/app
WORKDIR /home/app/code
COPY package.json /home/app/code/package.json
RUN chown -R app /home/app

USER app
RUN npm install

COPY .eslintrc .eslintignore coffeelint.json Makefile index.js config.js newrelic.js run_tests.sh /home/app/code/
COPY tests /home/app/code/tests
COPY src /home/app/code/src

USER root
RUN chown -R app /home/app

ENV API_SECRET=1234

WORKDIR /home/app/code
USER app
CMD node_modules/.bin/forever index.js
