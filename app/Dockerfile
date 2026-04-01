FROM node:20-alpine

WORKDIR /usr/src/app

# Copy package.json first — Docker caches this layer
# and only re-runs npm install when package.json changes
COPY package.json .
RUN npm install --production

# Copy app source
COPY server.js .
COPY schema.sql .
COPY public/ ./public/

EXPOSE 3000

CMD ["node", "server.js"]
