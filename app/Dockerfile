# syntax=docker/dockerfile:1.7
FROM node:22.22.0-alpine3.23 AS dependencies
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force

FROM alpine:3.23 AS certificates
RUN apk add --no-cache ca-certificates curl \
  && curl --fail --silent --show-error --retry 3 \
    https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem \
    --output /global-bundle.pem

FROM node:22.22.0-alpine3.23 AS runtime
ENV NODE_ENV=production \
    PORT=3000
WORKDIR /app
RUN addgroup -S app -g 10001 && adduser -S app -u 10001 -G app
COPY --from=dependencies --chown=app:app /app/node_modules ./node_modules
COPY --from=certificates --chown=app:app /global-bundle.pem ./certs/global-bundle.pem
COPY --chown=app:app package.json ./
COPY --chown=app:app src ./src
COPY --chown=app:app db ./db
USER app
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3000/health/live').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"
CMD ["node", "src/server.js"]
