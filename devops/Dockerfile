# Build application
FROM node:18-alpine as builder
WORKDIR /usr/src/app
COPY . .
RUN npm install --ignore-scripts && \
    npm run build

# Build production image
FROM node:18-alpine
ENV NODE_ENV=production
WORKDIR /usr/src/app 
COPY --from=builder /usr/src/app/dist ./dist
COPY --from=builder /usr/src/app/package.json ./
RUN npm install --production

EXPOSE 3000
CMD ["node", "dist/main.js"]