# Stage 1: Compile SCSS using Ruby + Compass
FROM ruby:3.1-slim-bookworm AS scss-builder

RUN gem install compass --no-document

WORKDIR /build

# Copy only SCSS source needed for compilation
COPY ui/app/styles/ /build/app/styles/

# Compass config
RUN echo "sass_dir = 'app/styles'" > config.rb && \
    echo "css_dir = 'app/styles'" >> config.rb && \
    echo "images_dir = 'app/images'" >> config.rb && \
    echo "fonts_dir = 'app/styles/fonts'" >> config.rb && \
    echo "relative_assets = true" >> config.rb

# Compile all SCSS to CSS
RUN compass compile || true

# Stage 2: Final image - overlay ONLY modified view templates on upstream
FROM bahmni/bahmni-web:latest

# Copy ONLY the view templates (NOT index.html which has fingerprinted references)
COPY ui/app/home/views/ /usr/local/apache2/htdocs/bahmni/home/views/
COPY ui/app/registration/views/ /usr/local/apache2/htdocs/bahmni/registration/views/
COPY ui/app/common/ui-helper/ /usr/local/apache2/htdocs/bahmni/common/ui-helper/

# Copy i18n files
COPY ui/app/i18n/ /usr/local/apache2/htdocs/bahmni/i18n/

# Copy compiled CSS from builder
COPY --from=scss-builder /build/app/styles/*.css /usr/local/apache2/htdocs/bahmni/styles/

# APPEND our compiled CSS to existing fingerprinted CSS files (preserve base styles, add overrides)
# The upstream minified CSS contains ALL concatenated styles; we append our theme on top.
RUN STYLES=/usr/local/apache2/htdocs/bahmni/styles && \
    ROOT=/usr/local/apache2/htdocs/bahmni && \
    # 1) Append to /styles/name.hash.css
    for css in $STYLES/*.css; do \
      base=$(basename "$css" .css); \
      name=$(echo "$base" | sed 's/\.[a-f0-9]\{8\}$//'); \
      if [ "$name" != "$base" ] && [ -f "$STYLES/${name}.css" ]; then \
        cat "$STYLES/${name}.css" >> "$css"; \
        echo "Appended to $css"; \
      fi; \
    done && \
    # 2) Append to per-module minified CSS (e.g. /home/home.min.hash.css)
    for modcss in $ROOT/home/home.min.*.css \
                  $ROOT/registration/registration.min.*.css \
                  $ROOT/clinical/clinical.min.*.css \
                  $ROOT/admin/admin.min.*.css \
                  $ROOT/adt/adt.min.*.css \
                  $ROOT/reports/reports.min.*.css; do \
      [ -f "$modcss" ] || continue; \
      modname=$(basename "$modcss" | sed 's/\.min\.[a-f0-9]\{8\}\.css$//'); \
      if [ -f "$STYLES/${modname}.css" ]; then \
        cat "$STYLES/${modname}.css" >> "$modcss"; \
        echo "Appended to $modcss"; \
      fi; \
    done

LABEL maintainer="dhairya0981"
LABEL description="Custom Bahmni Web with modernized UI - indigo theme"
