# ---- Build Stage ----
	FROM node:22-alpine AS builder
	
	RUN npm install -g pnpm
	
	WORKDIR /app
	
	COPY package.json pnpm-lock.yaml ./
	RUN pnpm install --frozen-lockfile
	
	COPY . .
	RUN pnpm run build
	
	# ---- Production Stage ----
	FROM node:22-alpine AS production
	
	RUN npm install -g pnpm
	
	WORKDIR /app
	
	COPY package.json pnpm-lock.yaml ./
	RUN pnpm install --frozen-lockfile --prod
	
	COPY --from=builder /app/dist ./dist
	
	EXPOSE 3000
	
	CMD ["node", "dist/main"]
	