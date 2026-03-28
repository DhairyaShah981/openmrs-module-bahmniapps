# Stage 1: Compile SCSS using Ruby + Compass
FROM ruby:3.1-slim-bookworm AS scss-builder

RUN gem install compass --no-document

WORKDIR /build

# Copy only SCSS source needed for compilation
COPY ui/app/styles/ /build/app/styles/

# Compass needs the import path for the grid mixins
# Create a minimal compass config
RUN echo "sass_dir = 'app/styles'" > config.rb && \
    echo "css_dir = 'app/styles'" >> config.rb && \
    echo "images_dir = 'app/images'" >> config.rb && \
    echo "fonts_dir = 'app/styles/fonts'" >> config.rb && \
    echo "relative_assets = true" >> config.rb

# Compile all SCSS to CSS
RUN compass compile || true

# Stage 2: Final image overlaying modified source on upstream
FROM bahmni/bahmni-web:latest

# Copy ALL modified app files (templates, JS, controllers, directives, etc.)
COPY ui/app/ /usr/local/apache2/htdocs/bahmni/

# Overwrite with compiled CSS from builder (if compass succeeded)
COPY --from=scss-builder /build/app/styles/ /usr/local/apache2/htdocs/bahmni/styles/

LABEL maintainer="dhairya0981"
LABEL description="Custom Bahmni Web with modernized UI - indigo theme"
