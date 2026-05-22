# Stage 1: Build the Flutter web application safely inside an isolated environment
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy dependency files first to cache the layer
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy the rest of the application
COPY . .

# Build the web application (safe and isolated build process)
RUN flutter build web --release

# Stage 2: Serve the application with an unprivileged Nginx server
FROM nginx:alpine

# Copy the build artifacts from the previous stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
