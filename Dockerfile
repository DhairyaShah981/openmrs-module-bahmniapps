# Stage 1: Build the application (compile SCSS, minify, etc.)
FROM node:14-buster AS builder

# Install Ruby and Compass for SCSS compilation
RUN apt-get update && apt-get install -y ruby-full && \
    gem install compass --no-document && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install yarn
RUN npm install -g yarn@1.22.19

WORKDIR /build

# Copy the UI source
COPY ui/ /build/

# Install dependencies
RUN yarn install --frozen-lockfile || yarn install

# Compile SCSS to CSS
RUN compass compile \
    --sass-dir app/styles \
    --css-dir app/styles \
    --images-dir app/images \
    --fonts-dir app/styles/fonts \
    --import-path app/components \
    --relative-assets

# Stage 2: Final image based on upstream bahmni-web
FROM bahmni/bahmni-web:latest

# Copy all modified app files (templates, JS, controllers, etc.)
COPY ui/app/ /usr/local/apache2/htdocs/bahmni/

# Overwrite compiled CSS from builder
COPY --from=builder /build/app/styles/*.css /usr/local/apache2/htdocs/bahmni/styles/

LABEL maintainer="dhairya0981"
LABEL description="Custom Bahmni Web with modernized UI - indigo theme"
