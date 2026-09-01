FROM node:20-alpine
WORKDIR /app

# Copy manifest first so npm install is cached separately from source changes —
# rebuilds during the workshop stay fast even after attendees edit server.js.
COPY package.json .
RUN npm install --production

COPY server.js .

EXPOSE 8080
CMD ["node", "server.js"]
