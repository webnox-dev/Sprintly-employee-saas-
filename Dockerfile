# Stage 1: Build the Flutter web app
FROM ghcr.io/cirruslabs/flutter:stable AS build-env

# Break Docker cache when code changes (pass at build: --build-arg BUILD_TIME=$(date +%s))
ARG BUILD_TIME
RUN echo "Build time: $BUILD_TIME"

# Set working directory
WORKDIR /app

# Copy the pubspec and fetch dependencies
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy the rest of the application code (this layer changes with every code change)
COPY . .

# Clean build artifacts and get dependencies
RUN flutter clean
RUN flutter pub get

# Build the web application
RUN flutter config --no-analytics
RUN flutter config --enable-web
RUN flutter build web --release

# Stage 2: Serve the app with Nginx
FROM nginx:alpine

# Copy the build output to the Nginx html directory
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
