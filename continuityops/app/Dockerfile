FROM node:20-alpine

WORKDIR /app

COPY package.json index.js ./

ENV NODE_ENV=production \
    APP_VERSION=0.1.0-s1 \
    APP_SOURCE=continuityops-lab \
    HTTP_PORT=8080

RUN addgroup -g 10001 -S app && adduser -u 10001 -S -G app app \
    && chown -R app:app /app

USER 10001:10001

EXPOSE 8080

CMD ["node", "index.js"]
