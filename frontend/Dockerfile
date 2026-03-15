FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

ARG API_BASE_URL=http://localhost:8000/api/v1

COPY . /app
RUN flutter config --enable-web \
  && flutter create . --platforms=web --project-name sujin_tms_app --no-pub \
  && flutter pub get \
  && flutter build web --release --pwa-strategy=none --dart-define=API_BASE_URL=${API_BASE_URL} \
  && python3 /app/scripts/postprocess_web_build.py

FROM nginx:1.27-alpine

COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
