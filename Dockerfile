FROM node:lts-alpine AS deps

WORKDIR /app

RUN apk --no-cache add git curl jq

RUN git clone https://github.com/towfiqi/serpbear.git
RUN curl -s https://api.github.com/repos/towfiqi/serpbear/tags | jq -r '.[0].commit.sha' | xargs -I{} git -C ./serpbear reset --hard {}
RUN mv ./serpbear/* .

RUN npm install


FROM node:lts-alpine AS builder
WORKDIR /app
COPY --from=deps /app ./
RUN rm -rf /app/data
RUN rm -rf /app/__tests__
RUN npm run build


FROM node:lts-alpine AS runner
WORKDIR /app
ENV NODE_ENV production
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs
RUN set -xe && mkdir -p /app/data && chown nextjs:nodejs /app/data
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
# COPY --from=builder --chown=nextjs:nodejs /app/data ./data
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# setup the cron
COPY --from=builder --chown=nextjs:nodejs /app/cron.js ./
COPY --from=builder --chown=nextjs:nodejs /app/email ./email
RUN rm package.json
RUN npm init -y 
RUN npm i cryptr dotenv croner @googleapis/searchconsole
RUN npm i -g concurrently

USER nextjs

EXPOSE 3000

CMD ["concurrently","node server.js", "node cron.js"]
